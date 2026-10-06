import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/service/book_player/book_player_server.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:shelf/shelf.dart' show Request, Response;

void main() {
  late Directory temp;
  late String previousDocumentPath;

  setUp(() async {
    previousDocumentPath = documentPath;
    temp = await Directory.systemTemp.createTemp('paperfold-server-');
    documentPath = temp.path;
    await getFileDir().create();
    await getBgimgDir().create();
  });

  tearDown(() async {
    Server().clearTempFile();
    documentPath = previousDocumentPath;
    await temp.delete(recursive: true);
  });

  Future<Response> request(String path) => Server().handleRequest(
        Request('GET', Uri.parse('http://127.0.0.1$path')),
      );

  test('reader serves library books but refuses other local files', () async {
    final book =
        await File('${getFileDir().path}/Book 100%.epub').writeAsString('book');
    final private =
        await File('${temp.path}/private.txt').writeAsString('private');

    final response = await request('/book/${Uri.encodeComponent(book.path)}');
    expect(response.statusCode, 200);
    expect(await response.readAsString(), 'book');
    expect(
        (await request('/book/${Uri.encodeComponent(private.path)}'))
            .statusCode,
        404);
  });

  test('background traversal and missing images return not found', () async {
    await File('${temp.path}/private.txt').writeAsString('private');
    expect(
        (await request('/bgimg/local/${Uri.encodeComponent('../private.txt')}'))
            .statusCode,
        404);
    expect((await request('/bgimg/local/missing.png')).statusCode, 404);
  });

  test('temporary import routes expire and handle a removed file', () async {
    final file = await File('${temp.path}/import.epub').writeAsString('book');
    final name = Server().setTempFile(file);
    final response = await request('/$name');
    expect(await response.readAsString(), 'book');
    await file.delete();
    expect((await request('/$name')).statusCode, 404);
    Server().clearTempFile();
  });
}
