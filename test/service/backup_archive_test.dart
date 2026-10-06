import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/page/settings_page/sync.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('paperfold_backup_');
  });

  tearDown(() async => temporary.delete(recursive: true));

  test('export includes one database snapshot and round-trips book files',
      () async {
    final documents =
        await Directory(path.join(temporary.path, 'documents')).create();
    final books = await Directory(path.join(documents.path, 'file')).create();
    await File(path.join(books.path, 'book.epub'))
        .writeAsString('book contents');
    final snapshot = await File(path.join(temporary.path, 'snapshot.db'))
        .writeAsString('consistent snapshot');
    final preferences =
        await File(path.join(temporary.path, 'anx_shared_prefs.json'))
            .writeAsString('{}');

    final zipPath = await createZipFile({
      'documentPath': documents.path,
      'temporaryPath': temporary.path,
      'prefsBackupFilePath': preferences.path,
      'databaseSnapshotPath': snapshot.path,
    });
    final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
    expect(
        archive.files.where((file) => file.name == 'databases/app_database.db'),
        hasLength(1));
    expect(archive.files.any((file) => file.name.endsWith('-wal')), isFalse);

    final output = path.join(temporary.path, 'output');
    await extractZipFile({'zipFilePath': zipPath, 'destinationPath': output});
    expect(
        await File(path.join(output, 'databases', 'app_database.db'))
            .readAsString(),
        'consistent snapshot');
    expect(await File(path.join(output, 'file', 'book.epub')).readAsString(),
        'book contents');
  });

  test('unsafe archive paths are rejected before writing outside extraction',
      () async {
    for (final name in [
      '../escaped.txt',
      '..\\escaped.txt',
      '/escaped.txt',
      'C:/escaped.txt'
    ]) {
      final archive = Archive()..addFile(ArchiveFile(name, 1, [1]));
      final zip = await File(path.join(temporary.path, 'unsafe.zip'))
          .writeAsBytes(ZipEncoder().encode(archive)!);
      await expectLater(
        extractZipFile({
          'zipFilePath': zip.path,
          'destinationPath': path.join(temporary.path, 'output'),
        }),
        throwsFormatException,
      );
    }
    expect(
        await File(path.join(temporary.path, 'escaped.txt')).exists(), isFalse);
  });
}
