import 'dart:io';

import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/platform_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:paperfold/utils/get_path/storage_migration.dart'
    show performStorageMigration;

/// Callback for migration progress updates
typedef MigrationProgressCallback = void Function(
    String currentItem, int progress, int total);

/// Result of migration check
class MigrationCheckResult {
  final bool needsMigration;
  final String? oldPath;
  final String? newPath;

  MigrationCheckResult({
    required this.needsMigration,
    this.oldPath,
    this.newPath,
  });
}

/// Checks if macOS data migration is needed.
/// Migration is needed when:
/// 1. Platform is macOS
/// 2. Old path (Documents) has data
/// 3. New path (Application Support) is empty or doesn't exist
Future<MigrationCheckResult> checkMigrationNeeded() async {
  if (!AnxPlatform.isMacOS) {
    return MigrationCheckResult(needsMigration: false);
  }

  try {
    final oldPath = (await getApplicationDocumentsDirectory()).path;
    final newPath = (await getApplicationSupportDirectory()).path;

    // Check if old path has any of our data directories or log file
    final dataFolders = ['file', 'cover', 'font', 'bgimg', 'databases'];
    bool oldHasData = false;

    for (final folder in dataFolders) {
      final oldDir = Directory('$oldPath${Platform.pathSeparator}$folder');
      if (oldDir.existsSync() && oldDir.listSync().isNotEmpty) {
        oldHasData = true;
        break;
      }
    }

    // Also check for log file
    final oldLogFile = File('$oldPath${Platform.pathSeparator}paperfold.log');
    if (oldLogFile.existsSync()) {
      oldHasData = true;
    }

    if (!oldHasData) {
      return MigrationCheckResult(needsMigration: false);
    }

    // Check if new path already has data
    bool newHasData = false;
    for (final folder in dataFolders) {
      final newDir = Directory('$newPath${Platform.pathSeparator}$folder');
      if (newDir.existsSync() && newDir.listSync().isNotEmpty) {
        newHasData = true;
        break;
      }
    }

    // If new path already has data, skip migration
    if (newHasData) {
      AnxLog.info('Migration: New path already has data, skipping migration');
      return MigrationCheckResult(needsMigration: false);
    }

    return MigrationCheckResult(
      needsMigration: true,
      oldPath: oldPath,
      newPath: newPath,
    );
  } catch (e) {
    AnxLog.severe('Migration check failed: $e');
    return MigrationCheckResult(needsMigration: false);
  }
}

/// Performs the data migration from Documents to Application Support.
/// Returns true if migration was successful.
Future<bool> performMigration({
  required String oldPath,
  required String newPath,
  MigrationProgressCallback? onProgress,
}) async {
  return performStorageMigration(
    sourcePath: oldPath,
    destinationPath: newPath,
    onProgress: onProgress,
  );
}
