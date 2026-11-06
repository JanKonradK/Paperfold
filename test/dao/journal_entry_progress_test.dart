import 'dart:io';

import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  test(
    'progress, daily count and entry are atomic and retry is idempotent',
    () async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().initPrefs();
      final previousPath = documentPath;
      final temp = await Directory.systemTemp.createTemp('journal-progress-');
      documentPath = temp.path;
      await Directory('${temp.path}/file').create();
      await Directory('${temp.path}/cover').create();
      addTearDown(() async {
        documentPath = previousPath;
        await temp.delete(recursive: true);
      });
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await DBHelper().onUpgradeDatabase(db, 0, currentDbVersion);
      final book = Book.physical()
        ..totalPages = 100
        ..currentPage = 10;
      book.id = await BookDao(database: db).insertBook(book);
      final dao = JournalDao(database: db);
      final entry = JournalPage(
        id: -12345,
        bookId: book.id,
        pageIndex: 0,
        sourcePage: 25,
        entryKind: 'progress',
      );
      await dao.saveEntry(entry, physicalPage: 25);
      await dao.saveEntry(entry, physicalPage: 25);
      expect((await db.query('tb_daily_read')).single['pages_read'], 15);
      expect((await db.query('tb_journal')).length, 1);
      expect((await db.query('tb_books')).single['current_page'], 25);
      await db.execute(
        "CREATE TRIGGER fail_entry BEFORE INSERT ON tb_journal BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await expectLater(
        dao.saveEntry(
          JournalPage(bookId: book.id, pageIndex: 0, body: 'next'),
          physicalPage: 40,
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await db.query('tb_books')).single['current_page'], 25);
      expect((await db.query('tb_daily_read')).single['pages_read'], 15);
      await expectLater(
        dao.saveEntry(
          JournalPage(bookId: book.id, pageIndex: 0, body: 'invalid'),
          physicalPage: 101,
        ),
        throwsArgumentError,
      );
    },
  );
}
