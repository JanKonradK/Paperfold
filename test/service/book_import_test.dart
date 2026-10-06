import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/service/convert_to_epub/txt/convert_from_txt.dart';
import 'package:paperfold/service/md5_service.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/import_book.dart';

class _Books extends BookDao {
  Book? saved;
  bool fail = false;

  @override
  Future<Book?> getBookByMd5(String md5) async => null;

  @override
  Future<int> insertBook(Book book) async {
    if (fail) throw StateError('Database write failed');
    saved = book;
    return book.id == -1 ? 1 : book.id;
  }
}

void main() {
  late Directory temp;
  late String previousDocumentPath;

  setUp(() async {
    previousDocumentPath = documentPath;
    temp = await Directory.systemTemp.createTemp('paperfold-import-');
    documentPath = '${temp.path}/library';
    await getFileDir().create(recursive: true);
    await getCoverDir().create(recursive: true);
  });

  tearDown(() async {
    documentPath = previousDocumentPath;
    await temp.delete(recursive: true);
  });

  test('import copies the book and retains its source and description',
      () async {
    final source =
        await File('${temp.path}/Original.EPUB').writeAsString('book');
    final dao = _Books();
    await saveBook(source, 'Unknown', 'Author', 'Description', null, '',
        dao: dao);

    expect(await source.readAsString(), 'book');
    expect(await File(dao.saved!.fileFullPath).readAsString(), 'book');
    expect(dao.saved!.title, 'Original');
    expect(dao.saved!.filePath, endsWith('.epub'));
    expect(dao.saved!.description, 'Description');
    expect(dao.saved!.coverPath, isEmpty);
  });

  test('failed database writes leave the source intact', () async {
    final source =
        await File('${temp.path}/Original.epub').writeAsString('book');
    await expectLater(
      saveBook(source, 'Title', 'Author', '', null, '',
          dao: _Books()..fail = true),
      throwsStateError,
    );
    expect(await source.readAsString(), 'book');
  });

  test('refreshing a cover retains the original row, file and reading data',
      () async {
    final original = Book.mock()
      ..filePath = 'file/original.epub'
      ..coverPath = 'cover/existing.jpg'
      ..description = 'Edited description'
      ..groupId = 9
      ..md5 = 'original-md5';
    final source = await File(original.fileFullPath).writeAsString('book');
    final dao = _Books();
    await saveBook(source, 'New title', 'New author', '', null, '',
        provideBook: original, dao: dao);

    expect(dao.saved!.toMap()..remove('update_time'),
        original.toMap()..remove('update_time'));
    expect(dao.saved!.id, original.id);
    expect(await source.readAsString(), 'book');
    expect(await getFileDir().list().length, 1);
  });

  test('invalid covers never produce a nonexistent cover path', () async {
    expect(await saveImageToLocal(null, 'cover/book'), isEmpty);
    expect(await saveImageToLocal('broken', 'cover/book'), isEmpty);
    expect(await saveImageToLocal('data:text/plain;base64,QQ==', 'cover/book'),
        isEmpty);
    final name =
        await saveImageToLocal('data:image/png;base64,AQID', 'cover/book');
    expect(name, 'cover/book.png');
    expect(await File(getBasePath(name)).readAsBytes(), [1, 2, 3]);
  });

  test(
      'valid UTF-8 accents, emoji and short text do not trigger legacy decoding',
      () async {
    final source = File('${temp.path}/text.txt');
    for (final text in ['', 'éàèçù ñ ü ö 漢字 📖', 'a\r\nb\r\nc\r\n']) {
      await source.writeAsBytes(utf8.encode(text));
      expect(readFileWithEncoding(source), text);
    }
    await source.writeAsBytes([0xff, 0xfe, 0x41, 0, 0xe9, 0]);
    expect(readFileWithEncoding(source), 'Aé');
  });

  test('streamed file hashes retain the standard MD5 result', () async {
    final source = await File('${temp.path}/hash.txt').writeAsString('abc');
    expect(await MD5Service.calculateFileMd5(source.path),
        '900150983cd24fb0d6963f7d28e17f72');
  });
}
