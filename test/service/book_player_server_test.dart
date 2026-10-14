import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/service/book_player/book_player_server.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:shelf/shelf.dart' show Request, Response;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    final book = await File('${getFileDir().path}/Book 100%.epub')
        .writeAsString('book');
    final private = await File('${temp.path}/private.txt')
        .writeAsString('private');

    final response = await request('/book/${Uri.encodeComponent(book.path)}');
    expect(response.statusCode, 200);
    expect(await response.readAsString(), 'book');
    expect(
      (await request('/book/${Uri.encodeComponent(private.path)}')).statusCode,
      404,
    );
  });

  test('background traversal and missing images return not found', () async {
    await File('${temp.path}/private.txt').writeAsString('private');
    expect(
      (await request('/bgimg/local/${Uri.encodeComponent('../private.txt')}'))
          .statusCode,
      404,
    );
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

  test(
    'PDF modules and binary assets keep their bytes and MIME types',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final bytes = Uint8List.fromList([0, 97, 115, 109, 255, 128]);
      final buffer = Uint8List.fromList([42, 43, ...bytes, 44]);
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final asset = utf8.decode(message!.buffer.asUint8List());
        return asset.startsWith('assets/foliate-js/src/vendor/pdfjs/')
            ? ByteData.sublistView(buffer, 2, 2 + bytes.length)
            : null;
      });
      addTearDown(
        () => messenger.setMockMessageHandler('flutter/assets', null),
      );
      for (final entry in {
        'pdf.mjs': 'application/javascript',
        'pdf.worker.mjs': 'application/javascript',
        'pdf_viewer.css': 'text/css',
        'wasm/openjpeg.wasm': 'application/wasm',
        'cmaps/Adobe-Japan1-UCS2.bcmap': 'application/octet-stream',
        'iccs/CGATS001Compat-v2-micro.icc': 'application/octet-stream',
        'standard_fonts/LiberationSans-Regular.ttf': 'font/ttf',
        'images/annotation-note.svg': 'image/svg+xml',
      }.entries) {
        final response = await request(
          '/foliate-js/src/vendor/pdfjs/${entry.key}',
        );
        expect(response.statusCode, 200);
        expect(response.headers['content-type'], entry.value);
        expect(await response.read().expand((part) => part).toList(), bytes);
      }
      expect((await request('/foliate-js/missing.mjs')).statusCode, 404);
      expect(
        (await request('/foliate-js/%252e%252e/private.txt')).statusCode,
        404,
      );
      expect(
        (await request('/foliate-js/src%255c..%255cprivate.txt')).statusCode,
        404,
      );
    },
  );
}
