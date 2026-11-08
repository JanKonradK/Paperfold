import 'dart:convert';
import 'dart:io';

import 'package:paperfold/dao/database.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/utils/save_file_to_download.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/get_path/databases_path.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/widgets/settings/settings_title.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:path/path.dart' as path;
import 'package:paperfold/widgets/settings/settings_section.dart';
import 'package:sqflite/sqflite.dart';
import 'package:paperfold/widgets/settings/settings_tile.dart';

const String _prefsBackupFileName = 'anx_shared_prefs.json';

class BackupSetting extends StatefulWidget {
  const BackupSetting({super.key});

  @override
  State<BackupSetting> createState() => _BackupSettingState();
}

class _BackupSettingState extends State<BackupSetting> {
  @override
  Widget build(BuildContext context) {
    return settingsSections(
      sections: [
        SettingsSection(
          title: Text(L10n.of(context).exportAndImport),
          tiles: [
            SettingsTile.navigation(
              title: Text(L10n.of(context).exportAndImportExport),
              leading: const Icon(Icons.cloud_upload),
              onPressed: (context) {
                exportData(context);
              },
            ),
            SettingsTile.navigation(
              title: Text(L10n.of(context).exportAndImportImport),
              leading: const Icon(Icons.cloud_download),
              onPressed: (context) {
                importData();
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showDataDialog(String title) {
    Future.microtask(() {
      SmartDialog.show(
        clickMaskDismiss: false,
        backType: SmartBackType.block,
        builder: (BuildContext context) => SimpleDialog(
          title: Center(child: Text(title)),
          children: const [Center(child: CircularProgressIndicator())],
        ),
      );
    });
  }

  Future<void> exportData(BuildContext context) async {
    AnxLog.info('exportData: start');
    if (!mounted) return;

    _showDataDialog(L10n.of(context).exporting);

    File? prefsBackupFile;
    File? snapshot;
    File? archive;
    try {
      prefsBackupFile = await _createPrefsBackupFile();
      snapshot = File(await DBHelper.prepareUploadSnapshot());
      final zipPath = await compute(createZipFile, {
        'documentPath': await getAnxDocumentsPath(),
        'temporaryPath': (await getAnxTempDir()).path,
        'prefsBackupFilePath': prefsBackupFile.path,
        'databaseSnapshotPath': snapshot.path,
      });
      archive = File(zipPath);
      await SmartDialog.dismiss();
      final fileName =
          'Paperfold-Backup-${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}-v3.zip';

      String? filePath = await saveFileToDownload(
        sourceFilePath: archive.path,
        fileName: fileName,
        mimeType: 'application/zip',
      );

      if (filePath != null) {
        AnxLog.info('exportData: Saved to: $filePath');
        AnxToast.show(L10n.of(navigatorKey.currentContext!).exportTo(filePath));
      } else {
        AnxLog.info('exportData: Cancelled');
        AnxToast.show(L10n.of(navigatorKey.currentContext!).commonCanceled);
      }
    } catch (e) {
      AnxLog.severe('exportData: $e');
      AnxToast.show('Export failed: $e');
    } finally {
      await SmartDialog.dismiss();
      for (final file in [prefsBackupFile, snapshot, archive]) {
        if (file != null && await file.exists()) await file.delete();
      }
    }
  }

  Future<void> importData() async {
    AnxLog.info('importData: start');
    if (!mounted) return;

    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null) {
      return;
    }

    String? filePath = result.path;
    if (filePath == null) {
      AnxLog.info('importData: cannot get file path');
      AnxToast.show(
        L10n.of(navigatorKey.currentContext!).importCannotGetFilePath,
      );
      return;
    }

    File zipFile = File(filePath);
    if (!await zipFile.exists()) {
      AnxLog.info('importData: zip file not found');
      AnxToast.show(
        L10n.of(navigatorKey.currentContext!).importCannotGetFilePath,
      );
      return;
    }
    _showDataDialog(L10n.of(navigatorKey.currentContext!).importing);

    Directory? extractDir;
    try {
      extractDir = await (await getAnxTempDir()).createTemp(
        'paperfold_import_',
      );

      await compute(extractZipFile, {
        'zipFilePath': zipFile.path,
        'destinationPath': extractDir.path,
      });

      final extractedPath = extractDir.path;
      await restoreBackupFiles(extractedPath);
      await _restorePrefsFromBackup(extractedPath);

      AnxLog.info('importData: import success');
      AnxToast.show(
        L10n.of(navigatorKey.currentContext!).importSuccessRestartApp,
      );
    } catch (e) {
      AnxLog.info('importData: error while unzipping or copying files: $e');
      AnxToast.show(
        L10n.of(navigatorKey.currentContext!).importFailed(e.toString()),
      );
    } finally {
      await SmartDialog.dismiss();
      if (extractDir != null && await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
    }
  }
}

Future<void> restoreBackupFiles(String extractPath) async {
  await validateBackupDatabase(
    path.join(extractPath, 'databases', 'app_database.db'),
  );

  final documentsPath = await getAnxDocumentsPath();
  final targets = {
    for (final name in ['file', 'cover', 'font', 'bgimg', 'journal_photos'])
      name: Directory(path.join(documentsPath, name)),
    'databases': await getAnxDataBasesDir(),
  };
  final staged = <({Directory target, Directory work})>[];
  final replaced = <Directory>{};
  var keepRecoveryFiles = false;
  try {
    // Complete all copies before changing live files. Each staging directory
    // shares a filesystem with its destination, including Android's database.
    for (final entry in targets.entries) {
      final source = Directory(path.join(extractPath, entry.key));
      if (!await source.exists()) continue;
      await entry.value.parent.create(recursive: true);
      final work = await entry.value.parent.createTemp('.paperfold_restore_');
      staged.add((target: entry.value, work: work));
      final incoming = Directory(path.join(work.path, 'incoming'));
      await incoming.create();
      await for (final entity in source.list(
        recursive: true,
        followLinks: false,
      )) {
        final destination = path.join(
          incoming.path,
          path.relative(entity.path, from: source.path),
        );
        if (entity is File) {
          await File(destination).parent.create(recursive: true);
          await entity.copy(destination);
        } else if (entity is Directory) {
          await Directory(destination).create(recursive: true);
        } else {
          throw FormatException('Backup contains a link: ${entity.path}');
        }
      }
    }

    await DBHelper.withDatabaseClosed((reopen) async {
      try {
        for (final item in staged) {
          if (await item.target.exists()) {
            await item.target.rename(path.join(item.work.path, 'previous'));
          }
          await Directory(path.join(item.work.path, 'incoming'))
              .rename(item.target.path);
          replaced.add(item.target);
        }
        await reopen();
      } catch (error) {
        try {
          await DBHelper.close();
          for (final item in staged.reversed) {
            if (replaced.contains(item.target)) {
              await item.target.delete(recursive: true);
            }
            final previous = Directory(path.join(item.work.path, 'previous'));
            if (await previous.exists()) {
              await previous.rename(item.target.path);
            }
          }
          await reopen();
        } catch (recoveryError) {
          keepRecoveryFiles = true;
          throw StateError(
            'Restore failed: $error. Recovery failed: $recoveryError. '
            'Original files remain in ${staged.map((item) => item.work.path).join(', ')}',
          );
        }
        rethrow;
      }
    });
  } finally {
    if (!keepRecoveryFiles) {
      for (final item in staged) {
        try {
          await item.work.delete(recursive: true);
        } catch (e) {
          AnxLog.warning('Cannot remove restore staging files: $e');
        }
      }
    }
  }
}

Future<String> createZipFile(Map<String, dynamic> params) async {
  final String prefsBackupFilePath = params['prefsBackupFilePath'];
  final File prefsBackupFile = File(prefsBackupFilePath);
  final date =
      '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
  final zipPath = '${params['temporaryPath']}/Paperfold-Backup-$date.zip';
  final String docPath = params['documentPath'];
  final directoryList = [
    getFileDir(path: docPath),
    getCoverDir(path: docPath),
    getFontDir(path: docPath),
    getBgimgDir(path: docPath),
    Directory(path.join(docPath, 'journal_photos')),
    prefsBackupFile,
  ];

  AnxLog.info('exportData: directoryList: $directoryList');

  final encoder = ZipFileEncoder();
  encoder.create(zipPath);

  var complete = false;
  try {
    await encoder.addFile(
      File(params['databaseSnapshotPath']),
      'databases/app_database.db',
    );
    for (final dir in directoryList) {
      if (dir is Directory && await dir.exists()) {
        await encoder.addDirectory(dir);
      } else if (dir is File) {
        await encoder.addFile(dir);
      }
    }
    complete = true;
  } finally {
    encoder.close();
    if (!complete) await File(zipPath).delete();
  }
  return zipPath;
}

Future<void> extractZipFile(Map<String, String> params) async {
  final zipFilePath = params['zipFilePath']!;
  final destinationPath = params['destinationPath']!;

  final input = InputFileStream(zipFilePath);
  try {
    final decoder = ZipDecoder();
    final archive = decoder.decodeStream(input);
    try {
      // archive 4 no longer implements decodeStream(verify: true).
      // Keep the checksum validation before restoring any backup content.
      for (final header in decoder.directory.fileHeaders) {
        if (header.file?.verifyCrc32() != true) {
          throw const FormatException('Invalid checksum in backup archive.');
        }
      }
      for (final entry in archive) {
        final name = entry.name.replaceAll('\\', '/');
        final outputPath = path.join(destinationPath, name);
        if (entry.isSymbolicLink ||
            path.posix.isAbsolute(name) ||
            path.windows.isAbsolute(name) ||
            !path.isWithin(destinationPath, outputPath)) {
          throw FormatException('Unsafe backup path: ${entry.name}');
        }
        if (entry.isFile) {
          final output = OutputFileStream(outputPath);
          try {
            entry.writeContent(output);
          } finally {
            output.closeSync();
          }
        } else {
          await Directory(outputPath).create(recursive: true);
        }
      }
    } finally {
      archive.clearSync();
    }
  } finally {
    await input.close();
  }
}

Future<File> _createPrefsBackupFile() async {
  final Directory tempDir = await getAnxTempDir();
  final File backupFile = File('${tempDir.path}/$_prefsBackupFileName');
  final Map<String, dynamic> prefsMap = await Prefs().buildPrefsBackupMap();
  await backupFile.writeAsString(jsonEncode(prefsMap));
  return backupFile;
}

Future<bool> _restorePrefsFromBackup(String extractPath) async {
  final File backupFile = File('$extractPath/$_prefsBackupFileName');
  if (!await backupFile.exists()) {
    return false;
  }
  try {
    final dynamic decoded = jsonDecode(await backupFile.readAsString());
    if (decoded is Map<String, dynamic>) {
      await Prefs().applyPrefsBackupMap(decoded);
      return true;
    }
    AnxLog.info('importData: prefs backup has unexpected format');
  } catch (e) {
    AnxLog.info('importData: failed to restore prefs backup: $e');
  }
  return false;
}

/// Throws a [FormatException] unless [dbPath] is a Paperfold library this
/// version can open. A backup file comes from outside the app.
Future<void> validateBackupDatabase(String dbPath) async {
  final dbFile = File(dbPath);
  if (!dbFile.existsSync() || dbFile.lengthSync() < 1024) {
    throw const FormatException('The backup has no library database');
  }
  final db = await openDatabase(dbPath, singleInstance: false);
  try {
    final integrity = await db.rawQuery('PRAGMA integrity_check');
    if (integrity.isEmpty || integrity.first.values.first != 'ok') {
      throw const FormatException('The backup database is damaged');
    }
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' "
      "AND name IN ('tb_books', 'tb_themes', 'tb_styles')",
    );
    if (tables.length < 3) {
      throw const FormatException('The backup database is missing tables');
    }
    final version = await db.getVersion();
    if (version > currentDbVersion) {
      throw FormatException(
        'The backup is from a newer Paperfold (database $version)',
      );
    }
    // Let SQLite checkpoint any bundled WAL before the database is copied.
    await db.rawQuery('PRAGMA journal_mode = DELETE');
  } finally {
    await db.close();
  }
}
