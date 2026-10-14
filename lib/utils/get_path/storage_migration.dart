import 'dart:io';

import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Callback for migration progress updates
typedef MigrationProgressCallback = void Function(
    String currentItem, int progress, int total);

const _dataFolders = ['file', 'cover', 'font', 'bgimg', 'databases'];

Future<bool> isStorageDestinationEmpty(String root) async {
  for (final name in _dataFolders) {
    final target = p.join(root, name);
    final type = await FileSystemEntity.type(target, followLinks: false);
    if (type == FileSystemEntityType.notFound) continue;
    if (type != FileSystemEntityType.directory ||
        !await Directory(target).list().isEmpty) {
      return false;
    }
  }
  return true;
}

/// Copies storage before the database and reader server start.
/// Keeps the source as a recovery copy until the new location is in use.
Future<bool> performStorageMigration({
  required String sourcePath,
  required String destinationPath,
  MigrationProgressCallback? onProgress,
}) async {
  // Items to migrate: 5 folders + 1 log file = 6 items
  final createdFiles = <File>[];
  final createdDirectories = <Directory>[];
  const int totalItems = 6; // 5 folders + 1 log file

  try {
    final sourceRoot = await Directory(sourcePath).resolveSymbolicLinks();
    final destination = Directory(destinationPath);
    await destination.create(recursive: true);
    final destinationRoot = await destination.resolveSymbolicLinks();
    if (p.equals(sourceRoot, destinationRoot) ||
        p.isWithin(sourceRoot, destinationRoot) ||
        p.isWithin(destinationRoot, sourceRoot)) {
      throw ArgumentError('Storage locations must not overlap');
    }
    // Validate every target before copying anything. Never replace an existing
    // library, including when a user resets to the default storage location.
    if (!await isStorageDestinationEmpty(destinationRoot)) {
      throw FileSystemException(
          'Storage destination is not empty', destinationRoot);
    }
    for (int i = 0; i < _dataFolders.length; i++) {
      final folder = _dataFolders[i];
      onProgress?.call(folder, i + 1, totalItems);

      final sourceDir = Directory(p.join(sourceRoot, folder));
      final destDir = Directory(p.join(destinationRoot, folder));

      if (await FileSystemEntity.isLink(sourceDir.path)) {
        throw FileSystemException(
            'Cannot migrate a symbolic link', sourceDir.path);
      }

      if (!sourceDir.existsSync()) {
        continue;
      }

      // Create destination directory if it doesn't exist
      if (!destDir.existsSync()) {
        await destDir.create(recursive: true);
        createdDirectories.add(destDir);
      }

      // Copy all contents
      await _copyDirectory(
          sourceDir, destDir, createdFiles, createdDirectories);

      AnxLog.info('StorageMigration: Copied $folder successfully');
    }

    // Also copy the log file if it exists
    onProgress?.call('paperfold.log', 6, totalItems);
    final sourceLogFile = File(p.join(sourceRoot, 'paperfold.log'));
    if (sourceLogFile.existsSync()) {
      if (await FileSystemEntity.isLink(sourceLogFile.path)) {
        throw FileSystemException(
            'Cannot migrate a symbolic link', sourceLogFile.path);
      }
      final destLogFile = File(p.join(destinationRoot, 'paperfold.log'));
      if (await FileSystemEntity.type(destLogFile.path, followLinks: false) ==
          FileSystemEntityType.notFound) {
        createdFiles.add(destLogFile);
        await sourceLogFile.copy(destLogFile.path);
        AnxLog.info('StorageMigration: Copied log file successfully');
      }
    }

    AnxLog.info('StorageMigration: Completed successfully');
    return true;
  } catch (e) {
    AnxLog.severe('StorageMigration failed: $e');
    // Remove only what this attempt created. The next launch can retry without
    // mistaking a partial database or cover directory for a complete library.
    for (final file in createdFiles.reversed) {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException catch (error) {
        AnxLog.warning('StorageMigration cleanup failed: $error');
      }
    }
    for (final directory in createdDirectories.reversed) {
      try {
        if (await directory.exists()) await directory.delete();
      } on FileSystemException catch (error) {
        AnxLog.warning('StorageMigration cleanup failed: $error');
      }
    }
    return false;
  }
}

/// Checks if a directory is empty (contains no files or subdirectories)
Future<bool> isDirectoryEmpty(String path) async {
  final dir = Directory(path);
  if (!dir.existsSync()) {
    return true;
  }
  final contents = await dir.list().toList();
  return contents.isEmpty;
}

/// Gets the default storage path for Windows/macOS
Future<String> getDefaultStoragePath() async {
  return (await getApplicationSupportDirectory()).path;
}

/// Recursively copies a directory
Future<void> _copyDirectory(Directory source, Directory destination,
    List<File> createdFiles, List<Directory> createdDirectories) async {
  await for (final entity in source.list(followLinks: false)) {
    final newPath = p.join(destination.path, p.basename(entity.path));

    if (entity is File) {
      createdFiles.add(File(newPath));
      await entity.copy(newPath);
    } else if (entity is Directory) {
      final newDir = Directory(newPath);
      await newDir.create(recursive: true);
      createdDirectories.add(newDir);
      await _copyDirectory(entity, newDir, createdFiles, createdDirectories);
    } else {
      throw FileSystemException('Cannot migrate a symbolic link', entity.path);
    }
  }
}

/// Applies a requested move while no service can still write to the old path.
Future<bool> applyPendingStorageMigration() async {
  final prefs = Prefs();
  final destination = prefs.pendingStoragePath;
  if (destination == null) return true;
  final source = await getAnxDocumentsPath();
  if (p.equals(p.normalize(source), p.normalize(destination))) {
    await prefs.setPendingStoragePath(null);
    return true;
  }
  if (!await performStorageMigration(
      sourcePath: source, destinationPath: destination)) {
    return false;
  }
  if (!await prefs.prefs.setString('customStoragePath', destination)) {
    return false;
  }
  await prefs.setPendingStoragePath(null);
  // Keep a recovery copy without leaving a live library at the old location.
  // This also lets Reset select the default folder after a successful move.
  try {
    final recovery = await Directory(source).createTemp('.paperfold_previous_');
    for (final name in [..._dataFolders, 'paperfold.log']) {
      final original = p.join(source, name);
      final type = await FileSystemEntity.type(original, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        await Directory(original).rename(p.join(recovery.path, name));
      } else if (type == FileSystemEntityType.file) {
        await File(original).rename(p.join(recovery.path, name));
      }
    }
  } on FileSystemException catch (error) {
    AnxLog.warning(
        'StorageMigration: Original recovery files remain at $source: $error');
  }
  return true;
}
