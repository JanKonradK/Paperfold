import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/dao/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paperfold/config/shared_preference_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  test('v12 preserves v11 writing and can be replayed', () async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute(
      'CREATE TABLE tb_journal (id INTEGER PRIMARY KEY, book_id INTEGER, page_index INTEGER, body TEXT, source_cfi TEXT, source_excerpt TEXT, source_chapter TEXT, create_time TEXT, update_time TEXT)',
    );
    await db.insert('tb_journal', {
      'body': 'Keep this thought',
      'source_cfi': 'epubcfi(/6/12)',
    });
    final before = (await db.query('tb_journal')).single;
    await DBHelper().onUpgradeDatabase(db, 11, 12);
    final after = (await db.query('tb_journal')).single;
    for (final field in before.keys) {
      expect(after[field], before[field]);
    }
    expect(after['entry_kind'], 'note');
    for (final name in [
      'source_locator',
      'source_progress',
      'source_page',
      'source_label',
      'photo_path',
    ]) {
      expect(after.containsKey(name), true);
      expect(after[name], null);
    }
    await DBHelper().onUpgradeDatabase(db, 11, 12);
    expect((await db.query('tb_journal')).single, after);
    expect(currentDbVersion, 12);
  });
}
