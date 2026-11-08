import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/page/settings_page/backup.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
// Test the platform plugin without writing to the user's application folders.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;

  @override
  Future<String> getApplicationCachePath() async => '$path/cache';
  @override
  Future<String> getApplicationDocumentsPath() async => path;
  @override
  Future<String> getApplicationSupportPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('database replacement', () {
    late Directory temporary;
    late PathProviderPlatform originalPaths;
    late String originalDocumentPath;

    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      SharedPreferences.setMockInitialValues({});
      await Prefs().initPrefs();
      temporary = await Directory.systemTemp.createTemp('paperfold_sync_');
      // Android keeps databases in their own folder; give each test one.
      await databaseFactory.setDatabasesPath('${temporary.path}/databases');
      originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(temporary.path);
      originalDocumentPath = documentPath;
      documentPath = temporary.path;
      await DBHelper.close();
      final local = await DBHelper().database;
      await local.execute('CREATE TABLE preservation_test (value TEXT)');
      await local.insert('preservation_test', {'value': 'keep local data'});
    });

    tearDown(() async {
      await DBHelper.close();
      PathProviderPlatform.instance = originalPaths;
      documentPath = originalDocumentPath;
      await temporary.delete(recursive: true);
    });

    test('DAO reads wait for a replacement and its pending startup open',
        () async {
      await DBHelper.close();
      final finishStartup = Completer<void>();
      final opening = DBHelper().initDB(after: finishStartup.future);
      final replacing = Completer<void>();
      final finishReplacement = Completer<void>();
      final replacement = DBHelper.withDatabaseClosed((reopen) async {
        replacing.complete();
        await finishReplacement.future;
        final database = await reopen();
        await database.update('preservation_test', {'value': 'new database'});
      });
      var readCompleted = false;
      final read = BookDao()
          .rawQueryList('SELECT value FROM preservation_test',
              mapper: (row) => row['value'])
          .then((rows) {
        readCompleted = true;
        return rows;
      });

      await Future<void>.delayed(Duration.zero);
      expect(replacing.isCompleted, isFalse);
      expect(readCompleted, isFalse);
      finishStartup.complete();
      await opening;
      await replacing.future;
      await Future<void>.delayed(Duration.zero);
      expect(readCompleted, isFalse);

      finishReplacement.complete();
      await replacement;
      expect(await read, ['new database']);
    });

    test('a backup without a usable library is refused', () async {
      final empty = File('${temporary.path}/empty.db')..writeAsStringSync('x');
      await expectLater(
        validateBackupDatabase(empty.path),
        throwsFormatException,
      );
      final newer = '${temporary.path}/newer.db';
      final db = await databaseFactory.openDatabase(newer);
      await DBHelper().onUpgradeDatabase(db, 0, currentDbVersion);
      await db.setVersion(currentDbVersion + 1);
      await db.close();
      await expectLater(validateBackupDatabase(newer), throwsFormatException);
    });

    test('failed backup restore preserves both the database and book files',
        () async {
      final books = await Directory('${temporary.path}/file').create();
      await File('${books.path}/original.epub').writeAsString('original book');
      final extracted = await Directory('${temporary.path}/extracted').create();
      await Directory('${extracted.path}/file').create();
      await File('${extracted.path}/file/replacement.epub')
          .writeAsString('replacement book');
      await Directory('${extracted.path}/databases').create();
      final remote = await databaseFactory
          .openDatabase('${extracted.path}/databases/app_database.db');
      await remote.execute(createBookSQL);
      await remote.execute(createThemeSQL);
      await remote.execute(createStyleSQL);
      await remote.setVersion(8);
      await remote.close();

      await expectLater(restoreBackupFiles(extracted.path), throwsA(anything));

      expect(await File('${books.path}/original.epub').readAsString(),
          'original book');
      expect(await File('${books.path}/replacement.epub').exists(), isFalse);
      expect(await (await DBHelper().database).query('preservation_test'), [
        {'value': 'keep local data'},
      ]);
    });
  }, skip: !Platform.isWindows && !Platform.isMacOS);
}
