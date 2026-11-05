import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  late Directory temp;
  late String previousDocumentPath;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    previousDocumentPath = documentPath;
    temp = await Directory.systemTemp.createTemp('paperfold-v11-');
    documentPath = temp.path;
    await Directory('${temp.path}/file').create();
    await Directory('${temp.path}/cover').create();
  });

  tearDown(() async {
    documentPath = previousDocumentPath;
    await temp.delete(recursive: true);
  });

  test('v10 books keep every field and gain empty page columns', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await DBHelper().onUpgradeDatabase(db, 0, 10);
    expect(
      (await db.rawQuery('PRAGMA table_info(tb_books)'))
          .map((column) => column['name']),
      isNot(contains('total_pages')),
    );
    await db.insert('tb_books', {
      'title': 'An e-book',
      'file_path': 'file/book.epub',
      'cover_path': 'cover/book.png',
      'reading_percentage': 0.4,
      'is_deleted': 0,
      'status': bookStatusReading,
      'create_time': '2026-10-01T10:00:00.000',
      'update_time': '2026-10-02T10:00:00.000',
    });
    final before = (await db.query('tb_books')).single;

    await DBHelper().onUpgradeDatabase(db, 10, 11);
    final after = (await db.query('tb_books')).single;
    for (final field in before.keys) {
      expect(after[field], before[field], reason: field);
    }
    expect(after['total_pages'], isNull);
    expect(after['current_page'], 0);
    expect(Book.fromDb(after).isPhysical, isFalse);

    // Replaying an interrupted upgrade must not add the columns twice.
    await DBHelper().onUpgradeDatabase(db, 10, 11);
    expect((await db.query('tb_books')).single, after);
    expect(currentDbVersion, 11);
  });

  test('a paper book saves its pages and stays out of file work', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await DBHelper().onUpgradeDatabase(db, 0, currentDbVersion);
    final dao = BookDao(database: db);

    final paper = Book.physical()
      ..title = 'A printed book'
      ..totalPages = 320
      ..currentPage = 40;
    paper.id = await dao.insertBook(paper);
    final ebook = Book.physical()
      ..title = 'An e-book'
      ..filePath = 'file/book.epub';
    await dao.insertBook(ebook);

    final stored = await dao.selectBookById(paper.id);
    expect(stored.isPhysical, isTrue);
    expect(stored.totalPages, 320);
    expect(stored.currentPage, 40);
    expect(await dao.getCurrentBooks(), ['file/book.epub']);
    expect(
      (await dao.getBooksWithoutMd5()).map((book) => book.title),
      ['An e-book'],
    );
  });
}
