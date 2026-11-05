import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/service/sync/webdav_client.dart';

void main() {
  late HttpServer server;
  late WebdavClient client;
  late Directory temporary;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    temporary = await Directory.systemTemp.createTemp('paperfold_webdav_');
    client = WebdavClient(
      url: 'http://127.0.0.1:${server.port}',
      username: 'reader',
      password: 'secret',
    );
  });

  tearDown(() async {
    await server.close(force: true);
    await temporary.delete(recursive: true);
  });

  test('a failed overwrite keeps the existing remote backup', () async {
    var backupExists = true;
    final methods = <String>[];
    server.listen((request) async {
      methods.add(request.method);
      await request.drain<void>();
      if (request.method == 'OPTIONS') {
        request.response.statusCode = 200;
      } else if (request.method == 'MKCOL') {
        request.response.statusCode = 201;
      } else if (request.method == 'DELETE') {
        backupExists = false;
        request.response.statusCode = 204;
      } else {
        request.response.statusCode = 503;
      }
      await request.response.close();
    });
    final local = await File('${temporary.path}/database.db')
        .writeAsString('new database');

    await expectLater(
      client.uploadFile(local.path, 'anx/database9.db'),
      throwsA(isA<DioException>()),
    );

    expect(methods, contains('PUT'));
    expect(methods, isNot(contains('DELETE')));
    expect(backupExists, isTrue);
  });

  test('only a missing remote file is reported as absent', () async {
    var status = 404;
    server.listen((request) async {
      await request.drain<void>();
      request.response.statusCode = status;
      await request.response.close();
    });

    expect(await client.readProps('anx/database9.db'), isNull);
    for (final failure in [401, 403, 500]) {
      status = failure;
      await expectLater(
        client.readProps('anx/database9.db'),
        throwsA(isA<DioException>()),
      );
    }
  });
}
