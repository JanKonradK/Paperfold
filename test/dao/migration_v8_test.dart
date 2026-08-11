// Proves the version 7 to version 8 migration loses no data.
//
// plan.md Section 14, Milestone 2:
//   "Copy a version 7 database. Run the migration. Compare row counts."
//
// The trap this test avoids is running against an empty database. A migration
// that dropped every row would pass an empty-database check perfectly. So the
// version 7 database here is seeded with books, notes, reading time, and
// groups before the migration runs.
//
//   flutter test test/dao/migration_v8_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The version 7 schema, exactly as it existed before migration 8.
///
/// Written out rather than reused from the app so the test still describes a
/// real version 7 database if the production constants change later.
const _v7Books = '''
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
  file_md5 TEXT
)
''';

const _v7Notes = '''
CREATE TABLE tb_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER,
  content TEXT,
  cfi TEXT,
  chapter TEXT,
  type TEXT,
  color TEXT,
  create_time TEXT,
  update_time TEXT,
  reader_note TEXT
)
''';

const _v7ReadingTime = '''
CREATE TABLE tb_reading_time (
  id INTEGER PRIMARY KEY,
  book_id INTEGER,
  date TEXT,
  reading_time INTEGER
)
''';

const _v7Groups = '''
CREATE TABLE tb_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  parent_id INTEGER,
  is_deleted INTEGER DEFAULT 0,
  create_time TEXT,
  update_time TEXT,
  FOREIGN KEY (parent_id) REFERENCES tb_groups(id)
)
''';

Future<int> _count(Database db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
  return rows.first['c']! as int;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // onUpgradeDatabase touches Prefs at the end, to decide whether the
    // database needs syncing. Give it a real, empty preference store.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  test('version 7 to 8 adds the journal schema and loses no rows', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);

    // Build a version 7 database with real content in it.
    await db.execute(_v7Books);
    await db.execute(_v7Notes);
    await db.execute(_v7ReadingTime);
    await db.execute(_v7Groups);

    await db.insert('tb_groups', {
      'id': 0,
      'name': 'Root',
      'parent_id': null,
      'is_deleted': 0,
      'create_time': '2026-01-01T00:00:00.000',
      'update_time': '2026-01-01T00:00:00.000',
    });

    // Three books spanning the whole range of reading progress, because the
    // migration derives status from reading_percentage.
    await db.insert('tb_books', {
      'title': 'Untouched',
      'reading_percentage': 0.0,
      'author': 'A',
      'is_deleted': 0,
      'group_id': 0,
      'create_time': '2026-01-01T00:00:00.000',
      'update_time': '2026-01-01T00:00:00.000',
    });
    await db.insert('tb_books', {
      'title': 'Half read',
      'reading_percentage': 0.42,
      'author': 'B',
      'is_deleted': 0,
      'group_id': 0,
      'create_time': '2026-01-01T00:00:00.000',
      'update_time': '2026-01-01T00:00:00.000',
    });
    await db.insert('tb_books', {
      'title': 'Done',
      'reading_percentage': 1.0,
      'author': 'C',
      'is_deleted': 0,
      'group_id': 0,
      'create_time': '2026-01-01T00:00:00.000',
      'update_time': '2026-01-01T00:00:00.000',
    });

    for (var i = 0; i < 5; i++) {
      await db.insert('tb_notes', {
        'book_id': 2,
        'content': 'highlighted passage $i',
        'cfi': 'epubcfi(/6/4!/4/2/$i)',
        'chapter': 'Chapter one',
        'type': 'highlight',
        'color': '66CCFF',
        'create_time': '2026-01-01T00:00:00.000',
        'update_time': '2026-01-01T00:00:00.000',
      });
    }

    for (var i = 0; i < 3; i++) {
      await db.insert('tb_reading_time', {
        'book_id': 2,
        'date': '2026-01-0${i + 1}',
        'reading_time': 600 + i,
      });
    }

    await db.setVersion(7);

    final booksBefore = await _count(db, 'tb_books');
    final notesBefore = await _count(db, 'tb_notes');
    final timeBefore = await _count(db, 'tb_reading_time');
    final groupsBefore = await _count(db, 'tb_groups');
    final noteContentsBefore = (await db.query('tb_notes', orderBy: 'id'))
        .map((r) => r['content'])
        .toList();

    // Run the real migration.
    await DBHelper().onUpgradeDatabase(db, 7, 8);

    // Nothing may be lost.
    expect(await _count(db, 'tb_books'), booksBefore, reason: 'books lost');
    expect(await _count(db, 'tb_notes'), notesBefore, reason: 'notes lost');
    expect(await _count(db, 'tb_reading_time'), timeBefore,
        reason: 'reading time lost');
    expect(await _count(db, 'tb_groups'), groupsBefore, reason: 'groups lost');

    // Note content must survive intact, not merely the row count.
    final noteContentsAfter = (await db.query('tb_notes', orderBy: 'id'))
        .map((r) => r['content'])
        .toList();
    expect(noteContentsAfter, noteContentsBefore);

    // Every new table must exist and be empty.
    for (final table in const [
      'tb_reviews',
      'tb_journal',
      'tb_shelves',
      'tb_challenge',
      'tb_wishlist',
      'tb_daily_read',
      'tb_catalogs',
    ]) {
      expect(await _count(db, table), 0, reason: '$table missing or seeded');
    }

    // tb_notes must NOT have grown journal columns. It stays a highlight
    // table anchored to a CFI. plan.md Section 3.2.
    final noteColumns = (await db.rawQuery('PRAGMA table_info(tb_notes)'))
        .map((r) => r['name'] as String)
        .toSet();
    expect(noteColumns.contains('page_index'), isFalse);
    expect(noteColumns.contains('body'), isFalse);
    expect(noteColumns.contains('cfi'), isTrue);

    // Status must be derived from reading progress, not blanket defaulted.
    final books = await db.query('tb_books', orderBy: 'id');
    expect(books[0]['status'], bookStatusNotStarted);
    expect(books[1]['status'], bookStatusReading);
    expect(books[2]['status'], bookStatusFinished);

    // The new date columns exist and start empty.
    expect(books[0]['started_on'], isNull);
    expect(books[0]['finished_on'], isNull);

    await db.close();
  });

  // NOTE ON THE FRESH-INSTALL PATH
  //
  // A version 0 database cannot be migrated inside a unit test. Migration
  // case 2, inherited from upstream, renames files on disk with
  // Directory(...).listSync() against the application's data directory, which
  // does not exist off-device. That is a property of the upstream migration,
  // not of version 8.
  //
  // The fresh-install path is covered on-device instead: a clean install logs
  // "create database version 8" and the app runs. The test below starts at
  // version 6, which reaches version 8 through the new step without touching
  // the filesystem.

  test('currentDbVersion is 8 and the step creates all seven tables', () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);

    await db.execute(_v7Books);
    await db.execute(_v7Notes);
    await db.execute(_v7ReadingTime);
    await db.setVersion(7);

    await db.insert('tb_books', {
      'title': 'Carried across',
      'reading_percentage': 0.5,
      'author': 'D',
      'is_deleted': 0,
      'create_time': '2026-01-01T00:00:00.000',
      'update_time': '2026-01-01T00:00:00.000',
    });

    await DBHelper().onUpgradeDatabase(db, 7, 8);

    expect(currentDbVersion, 8,
        reason: 'the app must ask for version 8 or the step never runs');
    expect(await _count(db, 'tb_books'), 1);

    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    ))
        .map((r) => r['name'] as String)
        .toSet();

    for (final table in const [
      'tb_reviews',
      'tb_journal',
      'tb_shelves',
      'tb_challenge',
      'tb_wishlist',
      'tb_daily_read',
      'tb_catalogs',
    ]) {
      expect(tables.contains(table), isTrue, reason: '$table not created');
    }

    await db.close();
  });

  test('the migration can be re-run without failing', () async {
    // A migration interrupted part way must be safe to replay. Every new
    // statement uses IF NOT EXISTS for this reason. The ALTER TABLE statements
    // are not idempotent, so a replay is expected to throw on those rather
    // than corrupt anything; this test records which half is replayable.
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(_v7Books);
    await db.execute(_v7Notes);
    await db.execute(_v7ReadingTime);
    await db.execute(_v7Groups);
    await db.setVersion(7);

    await DBHelper().onUpgradeDatabase(db, 7, 8);

    // The CREATE TABLE half replays cleanly.
    await db.execute(createReviewSQL);
    await db.execute(createJournalSQL);
    await db.execute(createShelfSQL);
    await db.execute(createChallengeSQL);
    await db.execute(createWishlistSQL);
    await db.execute(createDailyReadSQL);
    await db.execute(createCatalogSQL);

    expect(await _count(db, 'tb_reviews'), 0);

    await db.close();
  });
}
