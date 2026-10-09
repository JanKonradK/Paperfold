import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });

  test('v9 journal text and order survive the passage migration', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    // This is the shipped v9 table, not the current schema constant.
    await db.execute('''CREATE TABLE tb_journal (
      id INTEGER PRIMARY KEY AUTOINCREMENT, book_id INTEGER,
      page_index INTEGER, body TEXT, create_time TEXT, update_time TEXT
    )''');
    await db.execute(createReviewSQL);
    await db.insert('tb_journal', {
      'book_id': 7,
      'page_index': 3,
      'body': 'My original writing — unchanged.',
      'update_time': '2026-09-17T12:00:00.000',
    });
    await db.insert('tb_reviews', {'book_id': 7, 'thoughts': 'Keep my review'});
    final before = (await db.query('tb_journal')).single;

    await DBHelper().onUpgradeDatabase(db, 9, 10);
    final after = (await db.query('tb_journal')).single;
    for (final field in before.keys) {
      expect(after[field], before[field], reason: field);
    }
    expect(after['source_cfi'], isNull);
    expect(after['source_excerpt'], isNull);
    expect(after['source_chapter'], isNull);
    expect((await JournalDao(database: db).findReview(7))!.thoughts,
        'Keep my review');

    // Replaying an interrupted upgrade must neither drop text nor add columns twice.
    await DBHelper().onUpgradeDatabase(db, 9, 10);
    expect((await db.query('tb_journal')).single, after);
  });

  test('current journal schema accepts passage snapshots', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute(createJournalSQL);
    await db.insert('tb_journal', {
      'book_id': 7,
      'page_index': 0,
      'body': '',
      'source_cfi': 'epubcfi(/6/4!/4/2:0)',
      'source_excerpt': 'A passage worth keeping.',
      'source_chapter': 'Chapter one',
    });
    final row = (await db.query('tb_journal')).single;
    expect(row['source_excerpt'], 'A passage worth keeping.');
    expect(currentDbVersion, 10);
  });
}
