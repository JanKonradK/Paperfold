import 'dart:async';
import 'dart:io';
import 'package:paperfold/utils/get_path/get_cache_dir.dart';
import 'package:paperfold/utils/platform_utils.dart';

import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/get_path/databases_path.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Current app database version
const int currentDbVersion = 8;

const createBookSQL = '''
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
  update_time TEXT
)
''';

const createThemeSQL = '''
CREATE TABLE tb_themes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  background_color TEXT,
  text_color TEXT,
  background_image_path TEXT
)
''';

const createStyleSQL = '''
CREATE TABLE tb_styles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  font_size REAL,
  font_family TEXT,
  line_height REAL,
  letter_spacing REAL,
  word_spacing REAL,
  paragraph_spacing REAL,
  side_margin REAL,
  top_margin REAL,
  bottom_margin REAL
)
''';

const primaryTheme1 = '''
INSERT INTO tb_themes (background_color, text_color, background_image_path) VALUES ('fffbfbf3', 'ff343434', '')
''';
const primaryTheme2 = '''
INSERT INTO tb_themes (background_color, text_color, background_image_path) VALUES ('ff040404', 'fffeffeb', '')
''';

const createNoteSQL = '''
CREATE TABLE tb_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER,
  content TEXT,
  cfi TEXT,
  chapter TEXT,
  type TEXT,
  color TEXT,
  create_time TEXT,
  update_time TEXT
)
''';

const createReadingTimeSQL = '''
CREATE TABLE tb_reading_time (
  id INTEGER PRIMARY KEY,
  book_id INTEGER,
  date TEXT,
  reading_time INTEGER
)
''';

const createGroupSQL = '''
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

// ---------------------------------------------------------------------------
// Migration version 8 — the journal schema. plan.md Section 3.2.
//
// tb_notes is anchored to an EPUB CFI. It is a highlight table, tied to a
// location inside a book. Reviews and journal pages are book-level, so they
// get their own tables. Do not overload tb_notes.
// ---------------------------------------------------------------------------

/// The review sheet. All six ratings are 0 to 5.
///
/// rating_spice is drawn with a chili mark rather than stars, but that is a
/// view choice. The stored value is the number.
const createReviewSQL = '''
CREATE TABLE IF NOT EXISTS tb_reviews (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER,
  genre TEXT,
  format TEXT,
  rating_overall INTEGER,
  rating_plot INTEGER,
  rating_ending INTEGER,
  rating_world INTEGER,
  rating_characters INTEGER,
  rating_spice INTEGER,
  favorite_character TEXT,
  favorite_quote TEXT,
  thoughts TEXT,
  create_time TEXT,
  update_time TEXT,
  FOREIGN KEY (book_id) REFERENCES tb_books(id)
)
''';

/// Free journal space. One row per dot page, ordered by page_index.
const createJournalSQL = '''
CREATE TABLE IF NOT EXISTS tb_journal (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER,
  page_index INTEGER,
  body TEXT,
  create_time TEXT,
  update_time TEXT,
  FOREIGN KEY (book_id) REFERENCES tb_books(id)
)
''';

const createShelfSQL = '''
CREATE TABLE IF NOT EXISTS tb_shelves (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  sort_order INTEGER,
  create_time TEXT,
  update_time TEXT
)
''';

/// The reading challenge, one row per year.
const createChallengeSQL = '''
CREATE TABLE IF NOT EXISTS tb_challenge (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  year INTEGER UNIQUE,
  target_count INTEGER,
  create_time TEXT,
  update_time TEXT
)
''';

/// Books the reader wants to buy.
///
/// This is NOT the to-be-read list. To be read is intent to read, and lives on
/// tb_books.status. This is a shopping list. plan.md Section 8 keeps them apart
/// on purpose.
const createWishlistSQL = '''
CREATE TABLE IF NOT EXISTS tb_wishlist (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  author TEXT,
  bought INTEGER DEFAULT 0,
  sort_order INTEGER,
  create_time TEXT,
  update_time TEXT
)
''';

/// Pages read per day, for the circular month tracker.
///
/// tb_reading_time already stores MINUTES per day. This stores PAGES. They are
/// different measures and both are needed. plan.md Section 3.2.
const createDailyReadSQL = '''
CREATE TABLE IF NOT EXISTS tb_daily_read (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  date TEXT UNIQUE,
  pages_read INTEGER,
  create_time TEXT,
  update_time TEXT
)
''';

/// OPDS catalogs. Used in Milestone 7.
///
/// NEVER store a password in this table. Only the authentication type and the
/// user name belong here. Credentials go in the platform keystore through
/// flutter_secure_storage. plan.md Section 9.2 calls this the one place where a
/// shortcut creates a real security problem, because these are the user's own
/// server passwords.
const createCatalogSQL = '''
CREATE TABLE IF NOT EXISTS tb_catalogs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  url TEXT,
  auth_type TEXT,
  username TEXT,
  sort_order INTEGER,
  create_time TEXT,
  update_time TEXT
)
''';

/// Reading status values stored in tb_books.status.
///
/// Kept as text so the column reads plainly in a database browser and survives
/// reordering of any Dart enum.
const bookStatusNotStarted = 'not_started';
const bookStatusReading = 'reading';
const bookStatusFinished = 'finished';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;
  static Future<Database>? _databaseFuture;
  static bool updatedDB = false;

  factory DBHelper() {
    return _instance;
  }

  DBHelper._internal();

  Future<Database> get database => initDB();

  /// Starts database initialization or joins the initialization in progress.
  ///
  /// All startup callers share one future. This lets the first Flutter frame
  /// render while database-backed providers wait without opening a second
  /// connection or reading a null database. [after] lets startup finish the
  /// storage paths before the database opens.
  Future<Database> initDB({Future<void>? after}) {
    final database = _database;
    if (database != null) {
      return Future.value(database);
    }
    return _databaseFuture ??= _openAndCacheDatabase(after: after);
  }

  Future<Database> _openAndCacheDatabase({Future<void>? after}) async {
    try {
      await after;
      final database = await _openDatabase();
      _database = database;
      return database;
    } catch (_) {
      _databaseFuture = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    int dbVersion = currentDbVersion;
    switch (AnxPlatform.type) {
      case AnxPlatformEnum.macos:
      case AnxPlatformEnum.android:
      case AnxPlatformEnum.ohos:
        final databasePath = await getAnxDataBasesPath();
        final path = join(databasePath, 'app_database.db');
        return await openDatabase(
          path,
          version: dbVersion,
          onCreate: (db, version) async {
            onUpgradeDatabase(db, 0, version);
          },
          onUpgrade: onUpgradeDatabase,
        );
      case AnxPlatformEnum.ios:
      case AnxPlatformEnum.windows:
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;

        final databasePath = await getAnxDataBasesPath();
        AnxLog.info('Database: database path: $databasePath');
        final path = join(databasePath, 'app_database.db');

        return await databaseFactory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: dbVersion,
            onCreate: (db, version) async {
              onUpgradeDatabase(db, 0, version);
            },
            onUpgrade: onUpgradeDatabase,
          ),
        );
    }
  }

  static Future<void> close() async {
    Database? database = _database;
    final databaseFuture = _databaseFuture;
    if (database == null && databaseFuture != null) {
      try {
        database = await databaseFuture;
      } catch (_) {
        // There is no open database to close when initialization failed.
      }
    }
    await database?.close();
    _database = null;
    _databaseFuture = null;
  }

  /// Checkpoint WAL to merge data into main database file
  /// Returns true if checkpoint was successful or not needed
  static Future<bool> checkpointWal() async {
    try {
      final db = await DBHelper().database;
      // Use rawQuery instead of execute for PRAGMA wal_checkpoint
      // because it returns a result row which can cause issues with execute()
      await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
      AnxLog.info('Database: WAL checkpoint completed');
      return true;
    } catch (e) {
      AnxLog.warning('Database: WAL checkpoint failed: $e');
      return false;
    }
  }

  /// Get the path to the WAL file for a database
  static String getWalPath(String dbPath) => '$dbPath-wal';

  /// Get the path to the SHM file for a database
  static String getShmPath(String dbPath) => '$dbPath-shm';

  /// Check if WAL files exist for a database and have content
  static bool hasWalFiles(String dbPath) {
    final walFile = File(getWalPath(dbPath));
    return walFile.existsSync() && walFile.lengthSync() > 0;
  }

  /// Delete WAL auxiliary files
  static Future<void> cleanupWalFiles(String dbPath) async {
    try {
      final walFile = File(getWalPath(dbPath));
      final shmFile = File(getShmPath(dbPath));
      if (walFile.existsSync()) await walFile.delete();
      if (shmFile.existsSync()) await shmFile.delete();
      AnxLog.info('Database: WAL files cleaned up');
    } catch (e) {
      AnxLog.warning('Database: Failed to cleanup WAL files: $e');
    }
  }

  /// Create a snapshot of the database for upload using VACUUM INTO
  /// This avoids closing the database or locking it for long periods
  static Future<String> prepareUploadSnapshot() async {
    try {
      final db = await DBHelper().database;
      final cacheDir = await getAnxCacheDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final snapshotPath = join(cacheDir.path, 'snapshot_aaaa_$timestamp.db');

      // Ensure any existing file is removed
      final snapshotFile = File(snapshotPath);
      if (snapshotFile.existsSync()) {
        await snapshotFile.delete();
      }

      // VACUUM INTO creates a transactionally consistent copy
      // It works even if the DB is in WAL mode and open
      try {
        // Use string interpolation instead of binding for VACUUM INTO
        // as some SQLite wrappers/versions don't support bindings in VACUUM statements
        final escapedPath = snapshotPath.replaceAll("'", "''");
        await db.execute("VACUUM INTO '$escapedPath'");
      } catch (e) {
        AnxLog.warning('Database: VACUUM INTO failed ($e)');

        // Fallback strategy for platforms with older SQLite versions
        // (SQLite 3.27.0+ required for VACUUM INTO support)
        AnxLog.info('Database: Using fallback strategy (Checkpoint+Copy)');

        // 1. Force Checkpoint to ensure all WAL data is written to main DB file
        await db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');

        // 2. Copy file manually
        final databasePath = await getAnxDataBasesPath();
        final dbPath = join(databasePath, 'app_database.db');
        await File(dbPath).copy(snapshotPath);
      }

      AnxLog.info('Database: Created snapshot at $snapshotPath');

      // Ensure the snapshot has a clean header (Legacy mode)
      // This guarantees the uploaded file is compatible with all platforms
      await fixDatabaseHeader(snapshotPath);

      return snapshotPath;
    } catch (e) {
      AnxLog.severe('Database: Failed to create snapshot: $e');
      rethrow;
    }
  }

  /// Directly patch the database file header to switch from WAL mode to Legacy mode
  /// WAL mode sets the file format byte (offset 18) and version byte (offset 19) to 2
  /// We need to reset them to 1 (Legacy) to allow opening without -wal file
  static Future<void> fixDatabaseHeader(String dbPath) async {
    try {
      final file = File(dbPath);
      if (!file.existsSync()) return;

      // 1. Check header first to avoid expensive read/write if not needed
      bool needsPatch = false;
      final raf = await file.open(mode: FileMode.read);
      try {
        if (await raf.length() > 20) {
          await raf.setPosition(18);
          final writeVersion = await raf.readByte();
          final readVersion = await raf.readByte();

          if (writeVersion == 2 || readVersion == 2) {
            needsPatch = true;
            AnxLog.info(
                'Database: Detected WAL mode in header (v$writeVersion/v$readVersion), patching to Legacy mode');
          }
        }
      } finally {
        await raf.close();
      }

      // 2. Patch if needed logic (Read-Modify-Write)
      if (needsPatch) {
        final bytes = await file.readAsBytes();
        if (bytes.length > 20) {
          bytes[18] = 1; // Write version: 1 (Legacy)
          bytes[19] = 1; // Read version: 1 (Legacy)

          await file.writeAsBytes(bytes, flush: true);
          AnxLog.info('Database: patched header 18, 19 to 1 successfully');
        }
      }
    } catch (e) {
      AnxLog.warning('Database: Failed to patch database header: $e');
    }
  }

  /// Get the latest modification time including WAL file
  /// This ensures we detect changes even if they're only in the WAL
  static DateTime getLatestModTime(String dbPath) {
    final dbFile = File(dbPath);
    final walFile = File(getWalPath(dbPath));

    DateTime dbTime = dbFile.existsSync()
        ? dbFile.lastModifiedSync()
        : DateTime.fromMillisecondsSinceEpoch(0);

    if (walFile.existsSync()) {
      DateTime walTime = walFile.lastModifiedSync();
      if (walTime.isAfter(dbTime)) {
        return walTime;
      }
    }

    return dbTime;
  }

  Future<void> onUpgradeDatabase(
      Database db, int oldVersion, int newVersion) async {
    AnxLog.info('Database: upgrade database from $oldVersion to $newVersion');
    switch (oldVersion) {
      case 0:
        AnxLog.info('Database: create database version $newVersion');
        await db.execute(createBookSQL);
        await db.execute(createNoteSQL);
        await db.execute(createThemeSQL);
        await db.execute(createStyleSQL);
        await db.execute(createReadingTimeSQL);
        await db.execute(primaryTheme1);
        await db.execute(primaryTheme2);
        continue case1;
      case1:
      case 1:
        // add a column (rating) to tb_books
        await db.execute('ALTER TABLE tb_books ADD COLUMN rating REAL');
        // Remove '/data/user/0/com.anxcye.anx_reader/app_flutter/' from
        // file_path and cover_path.
        //
        // This package name is a historical fact about databases written by
        // old Anx Reader builds. It is deliberately NOT renamed to Paperfold.
        // Renaming it would make this statement match nothing, and the paths
        // it exists to repair would stay broken.
        await db.execute(
            "UPDATE tb_books SET file_path = REPLACE(file_path, '/data/user/0/com.anxcye.anx_reader/app_flutter/', '')");
        await db.execute(
            "UPDATE tb_books SET cover_path = REPLACE(cover_path, '/data/user/0/com.anxcye.anx_reader/app_flutter/', '')");
        continue case2;
      case2:
      case 2:
        // replave ' ' with '_' in db and cut file name to 25
        await db.execute(
            "UPDATE tb_books SET file_path = REPLACE(file_path, ' ', '_')");
        await db.execute(
            "UPDATE tb_books SET cover_path = REPLACE(cover_path, ' ', '_')");
        await db.execute(
            "UPDATE tb_books SET file_path = SUBSTR(file_path, 0, 25)");
        await db.execute(
            "UPDATE tb_books SET cover_path = SUBSTR(cover_path, 0, 25)");
        await db
            .execute("UPDATE tb_books SET file_path = file_path || '.epub'");
        await db
            .execute("UPDATE tb_books SET cover_path = cover_path || '.png'");

        final basePath = getBasePath('');
        final fileDir = Directory('$basePath/file');
        final coverDir = Directory('$basePath/cover');
        fileDir.listSync().forEach((element) {
          if (element is File) {
            final path = element.path;
            String pathAfterReplace = path.replaceAll(' ', '_');
            int endIndex =
                (pathAfterReplace.length < 72) ? pathAfterReplace.length : 72;
            final newPath = '${pathAfterReplace.substring(0, endIndex)}.epub';
            element.rename(newPath);
          }
        });
        coverDir.listSync().forEach((element) {
          if (element is File) {
            final path = element.path;
            String pathAfterReplace = path.replaceAll(' ', '_');
            int endIndex =
                (pathAfterReplace.length < 72) ? pathAfterReplace.length : 72;
            final newPath = '${pathAfterReplace.substring(0, endIndex)}.png';
            element.rename(newPath);
          }
        });
        continue case3;
      case3:
      case 3:
        // remove former book style
        Prefs().removeBookStyle();
        bookDao.selectBooks().then((books) {
          for (var book in books) {
            if (!File(book.coverFullPath).existsSync()) {
              resetBookCover(book);
            }
          }
        });
        continue case4;
      case4:
      case 4:
        // add a column (group_id) to tb_books, and set all group_id to 0 default
        await db.execute("ALTER TABLE tb_books ADD COLUMN group_id INTEGER");
        await db.execute("UPDATE tb_books SET group_id = 0");
        continue case5;
      case5:
      case 5:
        // add a column (reader_note) to tb_notes, null default
        await db.execute("ALTER TABLE tb_notes ADD COLUMN reader_note TEXT");
        continue case6;
      case6:
      case 6:
        // create groups table and migrate existing data
        await db.execute(createGroupSQL);
        // add a column (file_md5) to tb_books
        await db.execute("ALTER TABLE tb_books ADD COLUMN file_md5 TEXT");

        // Insert root group
        await db.execute(
            "INSERT INTO tb_groups (id, name, parent_id, create_time, update_time) VALUES (0, 'Root', NULL, datetime('now'), datetime('now'))");

        // Get all unique group_ids from books
        final List<Map<String, dynamic>> uniqueGroups = await db.rawQuery('''
          SELECT DISTINCT group_id 
          FROM tb_books 
          WHERE group_id IS NOT NULL AND group_id != 0
        ''');

        // Create groups for existing group_ids
        for (var i = 0; i < uniqueGroups.length; i++) {
          final groupId = uniqueGroups[i]['group_id'];
          await db.execute('''
            INSERT INTO tb_groups (id, name, parent_id, create_time, update_time)
            VALUES (?, '...', 0, datetime('now'), datetime('now'))
          ''', [groupId]);
        }
        continue case7;
      case7:
      case 7:
        // The journal schema. plan.md Section 3.2.
        //
        // These tables are additive. Nothing existing is dropped, renamed, or
        // rewritten, so no reader data can be lost by this step.
        await db.execute(createReviewSQL);
        await db.execute(createJournalSQL);
        await db.execute(createShelfSQL);
        await db.execute(createChallengeSQL);
        await db.execute(createWishlistSQL);
        await db.execute(createDailyReadSQL);
        await db.execute(createCatalogSQL);

        // tb_books had no reading status. Without one the to-be-read list
        // cannot work. plan.md Section 3.2.
        await db.execute(
            "ALTER TABLE tb_books ADD COLUMN status TEXT DEFAULT '$bookStatusNotStarted'");
        await db.execute('ALTER TABLE tb_books ADD COLUMN started_on TEXT');
        await db.execute('ALTER TABLE tb_books ADD COLUMN finished_on TEXT');

        // Existing books already carry reading_percentage, so derive the
        // status from it rather than marking a half-read library as unread.
        await db.execute(
            "UPDATE tb_books SET status = '$bookStatusNotStarted' WHERE status IS NULL");
        await db.execute(
            "UPDATE tb_books SET status = '$bookStatusReading' WHERE reading_percentage > 0 AND reading_percentage < 1");
        await db.execute(
            "UPDATE tb_books SET status = '$bookStatusFinished' WHERE reading_percentage >= 1");
    }

    if (oldVersion != 0 && Prefs().webdavStatus) {
      updatedDB = true;
    }
  }
}
