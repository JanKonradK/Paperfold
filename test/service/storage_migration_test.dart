import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/utils/get_path/storage_migration.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory source;
  late Directory destination;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('paperfold-migration-');
    source = await Directory(p.join(root.path, 'source')).create();
    destination = await Directory(p.join(root.path, 'destination')).create();
    await Directory(p.join(source.path, 'file')).create();
    await File(p.join(source.path, 'file', 'book.epub')).writeAsString('book');
    SharedPreferences.setMockInitialValues({'customStoragePath': source.path});
    await Prefs().initPrefs();
  });

  tearDown(() async => root.delete(recursive: true));

  Future<bool> migrate({MigrationProgressCallback? onProgress}) =>
      performStorageMigration(
          sourcePath: source.path,
          destinationPath: destination.path,
          onProgress: onProgress);

  test('copies the library and keeps the original available for recovery',
      () async {
    expect(await migrate(), isTrue);
    expect(
        await File(p.join(destination.path, 'file', 'book.epub'))
            .readAsString(),
        'book');
    expect(await File(p.join(source.path, 'file', 'book.epub')).readAsString(),
        'book');
  });

  test('rejects identical and nested storage locations without deleting data',
      () async {
    for (final target in [
      source.path,
      p.join(source.path, 'file', 'nested'),
      root.path
    ]) {
      expect(
          await performStorageMigration(
              sourcePath: source.path, destinationPath: target),
          isFalse);
    }
    expect(await File(p.join(source.path, 'file', 'book.epub')).readAsString(),
        'book');
  });

  test('rejects an existing destination library before copying files',
      () async {
    final databaseDir =
        await Directory(p.join(destination.path, 'databases')).create();
    final database = await File(p.join(databaseDir.path, 'app.db'))
        .writeAsString('existing');
    expect(await migrate(), isFalse);
    expect(await database.readAsString(), 'existing');
    expect(await Directory(p.join(destination.path, 'file')).exists(), isFalse);
  });

  test('cleans partial copies on failure and allows a retry', () async {
    expect(
        await migrate(onProgress: (_, progress, __) {
          if (progress == 2) {
            throw const FileSystemException('disk unavailable');
          }
        }),
        isFalse);
    expect(await destination.list().isEmpty, isTrue);
    expect(await File(p.join(source.path, 'file', 'book.epub')).readAsString(),
        'book');
    expect(await migrate(), isTrue);
  });

  test('a scheduled move does not change active storage until startup',
      () async {
    await Prefs().setPendingStoragePath(destination.path);
    expect(Prefs().customStoragePath, source.path);
    expect(await applyPendingStorageMigration(), isTrue);
    expect(Prefs().customStoragePath, destination.path);
    expect(Prefs().pendingStoragePath, isNull);
    expect(await isStorageDestinationEmpty(source.path), isTrue);
    final recovery = (await source.list().toList()).single as Directory;
    expect(
        await File(p.join(recovery.path, 'file', 'book.epub')).readAsString(),
        'book');
    await Prefs().setPendingStoragePath(source.path);
    expect(await applyPendingStorageMigration(), isTrue);
    expect(Prefs().customStoragePath, source.path);
    expect(await File(p.join(source.path, 'file', 'book.epub')).readAsString(),
        'book');
  }, skip: !Platform.isWindows);

  test(
      'failed startup migration retains active storage and the pending request',
      () async {
    await Directory(p.join(destination.path, 'file')).create();
    await File(p.join(destination.path, 'file', 'existing.epub'))
        .writeAsString('existing');
    await Prefs().setPendingStoragePath(destination.path);
    expect(await applyPendingStorageMigration(), isFalse);
    expect(Prefs().customStoragePath, source.path);
    expect(Prefs().pendingStoragePath, destination.path);
  }, skip: !Platform.isWindows);

  test('an existing destination log does not prevent library migration',
      () async {
    await File(p.join(destination.path, 'paperfold.log'))
        .writeAsString('existing');
    await File(p.join(source.path, 'paperfold.log')).writeAsString('old');
    expect(await migrate(), isTrue);
    expect(await File(p.join(destination.path, 'paperfold.log')).readAsString(),
        'existing');
  });

  test('preference backups cannot move another device to this device paths',
      () async {
    await Prefs().setPendingStoragePath(destination.path);
    final backup = await Prefs().buildPrefsBackupMap();
    expect(backup, isNot(contains('customStoragePath')));
    expect(backup, isNot(contains('pendingStoragePath')));
    await Prefs().applyPrefsBackupMap({
      'customStoragePath': {'type': 'string', 'value': 'other-device'},
      'pendingStoragePath': {'type': 'string', 'value': 'other-device'},
      'invalidList': {
        'type': 'stringList',
        'value': ['valid', 42]
      },
    });
    expect(Prefs().customStoragePath, source.path);
    expect(Prefs().pendingStoragePath, destination.path);
    expect(Prefs().prefs.containsKey('invalidList'), isFalse);
  });
}
