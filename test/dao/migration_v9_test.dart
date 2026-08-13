// Proves the version 8 to version 9 shelf-membership migration and DAO.
//
// The version 8 database is seeded before migration so row preservation,
// duplicate rejection, and sort order are checked against real data.
//
//   flutter test test/dao/migration_v9_test.dart

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/dao/shelf.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The version 8 book table, written out so later schema changes cannot make
/// this fixture stop representing a real version 8 database.
const _v8Books = '''
CREATE TABLE tb_books (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  cover_path TEXT,
  file_path TEXT,
  last_read_position TEXT,
  reading_percentage REAL,
  author TEXT,
  is_deleted INTEGER,
  description TEXT,
  create_time TEXT,
  update_time TEXT,
  rating REAL,
  group_id INTEGER,
  file_md5 TEXT,
  status TEXT DEFAULT 'not_started',
  started_on TEXT,
  finished_on TEXT
)
''';

const _v8Shelves = '''
CREATE TABLE tb_shelves (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  sort_order INTEGER,
  create_time TEXT,
  update_time TEXT
)
''';

Future<int> _count(Database db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
  return rows.first['c']! as int;
}

Future<void> _createVersion8Database(Database db) async {
  await db.execute(_v8Books);
  await db.execute(_v8Shelves);
  await db.setVersion(8);
}

Future<int> _insertBook(
  Database db,
  String title, {
  BookStatus status = BookStatus.notStarted,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return db.insert(
    'tb_books',
    Book(
      id: -1,
      title: title,
      coverPath: '',
      filePath: 'file/$title.epub',
      lastReadPosition: '',
      readingPercentage: 0,
      author: 'Author',
      isDeleted: false,
      rating: 0,
      status: status,
      createTime: now,
      updateTime: now,
    ).toMap(),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  test('version 8 to 9 creates membership, seeds favourites, and keeps rows',
      () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await _createVersion8Database(db);

    final bookId = await _insertBook(db, 'Existing book');
    await db.insert('tb_shelves', {
      'id': 7,
      'name': 'Existing shelf',
      'sort_order': 3,
      'create_time': '2026-01-01T00:00:00.000',
      'update_time': '2026-01-01T00:00:00.000',
    });

    await DBHelper().onUpgradeDatabase(db, 8, 9);

    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    ))
        .map((row) => row['name'] as String)
        .toSet();
    expect(tables, contains('tb_shelf_books'));

    expect(await _count(db, 'tb_books'), 1);
    expect(
      await db.query('tb_books', where: 'id = ?', whereArgs: [bookId]),
      hasLength(1),
    );
    expect(
      await db.query('tb_shelves', where: 'id = ?', whereArgs: [7]),
      hasLength(1),
    );

    final favourites = await db.query(
      'tb_shelves',
      where: 'id = ?',
      whereArgs: [builtInFavouritesShelfId],
    );
    expect(favourites, hasLength(1));
    expect(favourites.single['name'], 'All time favourites');

    // A replay must neither fail nor create a second built-in shelf.
    await DBHelper().onUpgradeDatabase(db, 8, 9);
    expect(
      await db.query(
        'tb_shelves',
        where: 'id = ?',
        whereArgs: [builtInFavouritesShelfId],
      ),
      hasLength(1),
    );
    expect(await _count(db, 'tb_books'), 1);
    expect(await _count(db, 'tb_shelves'), 2);

    await db.close();
  });

  test('shelf DAO rejects duplicates and preserves explicit and new order',
      () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await _createVersion8Database(db);
    await DBHelper().onUpgradeDatabase(db, 8, 9);
    final dao = ShelfDao(database: db);

    final firstId = await _insertBook(db, 'First');
    final secondId = await _insertBook(db, 'Second');
    final thirdId = await _insertBook(db, 'Third');

    await dao.addBookToShelf(
      shelfId: builtInFavouritesShelfId,
      bookId: firstId,
      sortOrder: 20,
    );
    await dao.addBookToShelf(
      shelfId: builtInFavouritesShelfId,
      bookId: secondId,
      sortOrder: 10,
    );
    await dao.addBookToShelf(
      shelfId: builtInFavouritesShelfId,
      bookId: thirdId,
    );

    expect(
      (await dao.listBooks(builtInFavouritesShelfId)).map((book) => book.id),
      [secondId, firstId, thirdId],
    );

    await expectLater(
      dao.addBookToShelf(
        shelfId: builtInFavouritesShelfId,
        bookId: firstId,
      ),
      throwsA(isA<DatabaseException>()),
    );

    await dao.reorderBooks(
      builtInFavouritesShelfId,
      [thirdId, secondId, firstId],
    );
    expect(
      (await dao.listBooks(builtInFavouritesShelfId)).map((book) => book.id),
      [thirdId, secondId, firstId],
    );

    await dao.removeBookFromShelf(
      shelfId: builtInFavouritesShelfId,
      bookId: secondId,
    );
    expect(
      (await dao.listBooks(builtInFavouritesShelfId)).map((book) => book.id),
      [thirdId, firstId],
    );

    await db.close();
  });

  test('deleting a book explicitly removes its shelf memberships', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await _createVersion8Database(db);
    await DBHelper().onUpgradeDatabase(db, 8, 9);

    final bookId = await _insertBook(db, 'Delete me');
    final shelfDao = ShelfDao(database: db);
    await shelfDao.addBookToShelf(
      shelfId: builtInFavouritesShelfId,
      bookId: bookId,
    );

    final pragma = await db.rawQuery('PRAGMA foreign_keys');
    expect(pragma.single.values.single, 0);

    await BookDao(database: db).deleteBook(bookId);

    expect(
      await db.query(
        ShelfDao.membershipTable,
        where: 'book_id = ?',
        whereArgs: [bookId],
      ),
      isEmpty,
    );
    expect(
      (await db.query('tb_books', where: 'id = ?', whereArgs: [bookId]))
          .single['is_deleted'],
      1,
    );

    await db.close();
  });

  test('deleting a shelf explicitly removes its memberships', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await _createVersion8Database(db);
    await DBHelper().onUpgradeDatabase(db, 8, 9);

    final bookId = await _insertBook(db, 'Shelved');
    final shelfId = await db.insert('tb_shelves', {
      'name': 'Temporary',
      'sort_order': 1,
      'create_time': '2026-01-01T00:00:00.000',
      'update_time': '2026-01-01T00:00:00.000',
    });
    final dao = ShelfDao(database: db);
    await dao.addBookToShelf(shelfId: shelfId, bookId: bookId);

    await dao.deleteShelf(shelfId);

    expect(
      await db.query(
        ShelfDao.membershipTable,
        where: 'shelf_id = ?',
        whereArgs: [shelfId],
      ),
      isEmpty,
    );
    expect(
      await db.query('tb_shelves', where: 'id = ?', whereArgs: [shelfId]),
      isEmpty,
    );

    await db.close();
  });

  test('Book maps every status and nullable reading dates', () {
    final started = DateTime.utc(2026, 2, 3, 4, 5, 6);
    final finished = DateTime.utc(2026, 3, 4, 5, 6, 7);
    final cases = [
      (BookStatus.notStarted, null, null),
      (BookStatus.reading, started, null),
      (BookStatus.finished, started, finished),
    ];

    for (final testCase in cases) {
      final source = Book(
        id: 42,
        title: 'Round trip',
        coverPath: 'cover/book.png',
        filePath: 'file/book.epub',
        lastReadPosition: 'epubcfi(/6/2)',
        readingPercentage: 0.5,
        author: 'Author',
        isDeleted: false,
        rating: 4,
        status: testCase.$1,
        startedOn: testCase.$2,
        finishedOn: testCase.$3,
        createTime: DateTime.utc(2026, 1, 1),
        updateTime: DateTime.utc(2026, 1, 2),
      );

      final restored = Book.fromDb({'id': source.id, ...source.toMap()});
      final restoredAgain =
          Book.fromDb({'id': restored.id, ...restored.toMap()});

      expect(restoredAgain.status, testCase.$1);
      expect(restoredAgain.startedOn, testCase.$2);
      expect(restoredAgain.finishedOn, testCase.$3);
      expect(restoredAgain.toMap()['status'], testCase.$1.databaseValue);
    }
  });

  test('unknown book status falls back to not started', () {
    expect(
      BookStatus.fromDatabase('paused_on_another_device'),
      BookStatus.notStarted,
    );
  });

  test('the complete version 0 to version 9 path succeeds', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    final originalDocumentPath = documentPath;
    final temporaryDocumentPath =
        await Directory.systemTemp.createTemp('paperfold_migration_');

    try {
      documentPath = temporaryDocumentPath.path;
      await Directory('${temporaryDocumentPath.path}/file').create();
      await Directory('${temporaryDocumentPath.path}/cover').create();

      await DBHelper().onUpgradeDatabase(db, 0, 9);

      expect(currentDbVersion, 9);
      final tables = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
          .map((row) => row['name'] as String)
          .toSet();
      for (final table in const [
        'tb_books',
        'tb_notes',
        'tb_themes',
        'tb_styles',
        'tb_reading_time',
        'tb_groups',
        'tb_reviews',
        'tb_journal',
        'tb_shelves',
        'tb_shelf_books',
        'tb_challenge',
        'tb_wishlist',
        'tb_daily_read',
        'tb_catalogs',
      ]) {
        expect(tables, contains(table), reason: '$table was not created');
      }
      expect(
        await db.query(
          'tb_shelves',
          where: 'id = ?',
          whereArgs: [builtInFavouritesShelfId],
        ),
        hasLength(1),
      );
    } finally {
      documentPath = originalDocumentPath;
      await db.close();
      await temporaryDocumentPath.delete(recursive: true);
    }
  });
}
