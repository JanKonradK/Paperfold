// Catalog storage, credentials, and the fetch.
//
// The load-bearing test here is the one that reads every column of every
// catalog row and looks for the password. plan.md Section 9.2 calls the
// credential store the one place in the project where a shortcut creates a
// real security problem: the database is copied by the export path and by
// WebDAV sync, and these are the reader's own server passwords.
//
//   flutter test test/service/opds_client_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/dao/catalog.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/models/opds_catalog.dart';
import 'package:paperfold/service/opds/opds_client.dart';
import 'package:paperfold/service/opds/opds_credentials.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _feed = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Private shelf</title>
  <entry>
    <title>A Wizard of Earthsea</title>
    <link rel="http://opds-spec.org/acquisition" href="/download/1.epub"
          type="application/epub+zip"/>
  </entry>
</feed>
''';

/// A dio adapter that answers from a script instead of from a network.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _body(
  String text, {
  int status = 200,
  String contentType = 'application/atom+xml;profile=opds-catalog',
}) {
  return ResponseBody.fromString(
    text,
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[contentType],
    },
  );
}

OpdsCatalog _catalog({
  OpdsAuthType authType = OpdsAuthType.none,
  String? username,
}) {
  return OpdsCatalog(
    id: 7,
    name: 'Home server',
    url: Uri.parse('https://books.example/opds/root.xml'),
    authType: authType,
    username: username,
  );
}

Dio _dio(_ScriptedAdapter adapter) => Dio()..httpClientAdapter = adapter;

void main() {
  group('catalog storage', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late Database db;
    late CatalogDao dao;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await db.execute(createCatalogSQL);
      dao = CatalogDao(database: db);
    });

    tearDown(() async => db.close());

    test('a catalog round-trips', () async {
      final int id = await dao.addCatalog(
        name: 'Home server',
        url: Uri.parse('https://books.example/opds'),
        authType: OpdsAuthType.basic,
        username: 'reader',
      );

      final OpdsCatalog stored = (await dao.findById(id))!;
      expect(stored.name, 'Home server');
      expect(stored.url, Uri.parse('https://books.example/opds'));
      expect(stored.authType, OpdsAuthType.basic);
      expect(stored.username, 'reader');
      expect(stored.needsPassword, isTrue);
    });

    test('no column of any catalog row can hold a password', () async {
      const String secret = 'correct-horse-battery-staple';
      final int id = await dao.addCatalog(
        name: 'Home server',
        url: Uri.parse('https://books.example/opds'),
        authType: OpdsAuthType.basic,
        username: 'reader',
      );
      // Store the password the way the application does.
      final OpdsCredentials credentials = InMemoryOpdsCredentials();
      await credentials.write(id, secret);

      final List<Map<String, Object?>> rows = await db.query(CatalogDao.table);
      for (final Map<String, Object?> row in rows) {
        for (final Object? value in row.values) {
          expect(
            value?.toString(),
            isNot(contains(secret)),
            reason: 'the database is exported and synced; it holds no secrets',
          );
        }
      }
      // And the password is still readable from where it does belong.
      expect(await credentials.read(id), secret);
    });

    test('the two free catalogs seed once, and stay deleted', () async {
      expect(await dao.seedDefaultsIfEmpty(), isTrue);
      expect(
        (await dao.listCatalogs()).map((OpdsCatalog each) => each.name),
        <String>['Standard Ebooks', 'Project Gutenberg'],
      );

      // A reader who removes them must not get them back on the next start.
      expect(await dao.seedDefaultsIfEmpty(), isFalse);
      for (final OpdsCatalog each in await dao.listCatalogs()) {
        await dao.deleteCatalog(each.id);
      }
      expect(await dao.listCatalogs(), isEmpty);
    });

    test('an unknown auth type reads as none rather than failing', () async {
      await db.insert(CatalogDao.table, <String, Object?>{
        'name': 'Odd server',
        'url': 'https://books.example/opds',
        'auth_type': 'oauth-something',
        'create_time': DateTime.now().toIso8601String(),
      });

      expect((await dao.listCatalogs()).single.authType, OpdsAuthType.none);
    });
  });

  group('credentials', () {
    test('an empty password clears the entry rather than storing nothing',
        () async {
      final OpdsCredentials credentials = InMemoryOpdsCredentials();
      await credentials.write(7, 'secret');
      await credentials.write(7, '');

      expect(await credentials.read(7), isNull);
    });

    test('keys are namespaced', () {
      expect(
        KeystoreOpdsCredentials.keyFor(7),
        'opds_catalog_password_7',
      );
    });
  });

  group('fetching a feed', () {
    test('catalog credentials never follow links to another origin', () async {
      final credentials = InMemoryOpdsCredentials();
      await credentials.write(7, 'secret');
      final adapter = _ScriptedAdapter((_) => _body(_feed));
      final client = OpdsClient(dio: _dio(adapter), credentials: credentials);
      final catalog =
          _catalog(authType: OpdsAuthType.basic, username: 'reader');
      for (final target in [
        'https://other.example/feed',
        'https://cdn.books.example/feed',
        'http://books.example/feed',
        'https://books.example:8443/feed',
      ]) {
        await client.fetchFeed(catalog, url: Uri.parse(target));
      }
      expect(
          adapter.requests.every(
              (request) => !request.headers.containsKey('Authorization')),
          isTrue);
    });

    test('redirects retain same-origin auth and strip it before a new origin',
        () async {
      final credentials = InMemoryOpdsCredentials();
      await credentials.write(7, 'secret');
      final adapter = _ScriptedAdapter((request) {
        final location = switch (request.uri.path) {
          '/opds/root.xml' => '/redirect',
          '/redirect' => 'https://cdn.books.example/final/feed',
          _ => null,
        };
        return location == null
            ? _body(_feed)
            : ResponseBody.fromString('', 302, headers: {
                'location': [location]
              });
      });
      final feed =
          await OpdsClient(dio: _dio(adapter), credentials: credentials)
              .fetchFeed(
                  _catalog(authType: OpdsAuthType.basic, username: 'reader'));
      expect(adapter.requests, hasLength(3));
      expect(adapter.requests[0].headers, contains('Authorization'));
      expect(adapter.requests[1].headers, contains('Authorization'));
      expect(adapter.requests[2].headers, isNot(contains('Authorization')));
      expect(feed.publications.single.acquisitionLinks.single.href.host,
          'cdn.books.example');
    });

    test('download redirects never forward the catalog password', () async {
      final directory = await Directory.systemTemp.createTemp('opds-auth-');
      addTearDown(() => directory.delete(recursive: true));
      final credentials = InMemoryOpdsCredentials();
      await credentials.write(7, 'secret');
      final adapter =
          _ScriptedAdapter((request) => request.uri.host == 'books.example'
              ? ResponseBody.fromString('', 302, headers: {
                  'location': ['https://cdn.books.example/book.epub'],
                })
              : _body('book', contentType: 'application/epub+zip'));
      final file = File('${directory.path}/book.epub');
      await OpdsClient(dio: _dio(adapter), credentials: credentials).download(
        _catalog(authType: OpdsAuthType.basic, username: 'reader'),
        Uri.parse('https://books.example/book.epub'),
        file.path,
      );
      expect(await file.readAsString(), 'book');
      expect(adapter.requests.last.headers, isNot(contains('Authorization')));
    });

    test('malformed JSON field types are classified as invalid feeds',
        () async {
      final client = OpdsClient(
        dio: _dio(_ScriptedAdapter((_) => _body(
              '{"metadata":{"title":"Catalog"},"publications":"invalid"}',
              contentType: 'application/opds+json',
            ))),
      );
      await expectLater(
          client.fetchFeed(_catalog()),
          throwsA(
            isA<OpdsException>()
                .having((e) => e.failure, 'failure', OpdsFailure.notAFeed),
          ));
    });

    test('a feed comes back parsed', () async {
      final _ScriptedAdapter adapter =
          _ScriptedAdapter((RequestOptions options) => _body(_feed));
      final OpdsClient client = OpdsClient(
        dio: _dio(adapter),
        credentials: InMemoryOpdsCredentials(),
      );

      final feed = await client.fetchFeed(_catalog());

      expect(feed.title, 'Private shelf');
      expect(feed.publications.single.title, 'A Wizard of Earthsea');
      // The relative link resolved against the address it came from.
      expect(
        feed.publications.single.acquisitionLinks.single.href,
        Uri.parse('https://books.example/download/1.epub'),
      );
    });

    test('a client asks for a catalog, not for a web page', () async {
      final _ScriptedAdapter adapter =
          _ScriptedAdapter((RequestOptions options) => _body(_feed));
      await OpdsClient(
        dio: _dio(adapter),
        credentials: InMemoryOpdsCredentials(),
      ).fetchFeed(_catalog());

      expect(
        adapter.requests.single.headers['Accept'],
        contains('opds-catalog'),
      );
    });

    test('a stored password becomes a Basic header', () async {
      final OpdsCredentials credentials = InMemoryOpdsCredentials();
      await credentials.write(7, 'hunter2');
      final _ScriptedAdapter adapter =
          _ScriptedAdapter((RequestOptions options) => _body(_feed));

      await OpdsClient(dio: _dio(adapter), credentials: credentials).fetchFeed(
        _catalog(authType: OpdsAuthType.basic, username: 'reader'),
      );

      expect(
        adapter.requests.single.headers['Authorization'],
        'Basic ${base64Encode(utf8.encode('reader:hunter2'))}',
      );
    });

    test('no password means no header at all', () async {
      final _ScriptedAdapter adapter =
          _ScriptedAdapter((RequestOptions options) => _body(_feed));

      await OpdsClient(
        dio: _dio(adapter),
        credentials: InMemoryOpdsCredentials(),
      ).fetchFeed(_catalog(authType: OpdsAuthType.basic, username: 'reader'));

      // Sending an empty password would turn "not set up yet" into a server
      // error. Let the server answer 401 and let the screen ask.
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('a catalog with no authentication sends no header', () async {
      final OpdsCredentials credentials = InMemoryOpdsCredentials();
      await credentials.write(7, 'left-over');
      final _ScriptedAdapter adapter =
          _ScriptedAdapter((RequestOptions options) => _body(_feed));

      await OpdsClient(dio: _dio(adapter), credentials: credentials)
          .fetchFeed(_catalog());

      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('each failure is told apart', () async {
      Future<OpdsFailure> failureFor(int status) async {
        final OpdsClient client = OpdsClient(
          dio: _dio(
            _ScriptedAdapter(
              (RequestOptions options) => _body('', status: status),
            ),
          ),
          credentials: InMemoryOpdsCredentials(),
        );
        try {
          await client.fetchFeed(_catalog());
        } on OpdsException catch (error) {
          return error.failure;
        }
        fail('status $status must fail');
      }

      expect(await failureFor(401), OpdsFailure.unauthorized);
      expect(await failureFor(403), OpdsFailure.unauthorized);
      expect(await failureFor(404), OpdsFailure.notFound);
      expect(await failureFor(500), OpdsFailure.server);
    });

    test('a web page where a feed should be is not a server error', () async {
      final OpdsClient client = OpdsClient(
        dio: _dio(
          _ScriptedAdapter(
            (RequestOptions options) => _body(
              '<!doctype html><html><body>Sign in</body></html>',
              contentType: 'text/html',
            ),
          ),
        ),
        credentials: InMemoryOpdsCredentials(),
      );

      // The usual cause is an address that points at the site and not at its
      // catalog, and the reader can only fix that if the screen says so.
      await expectLater(
        client.fetchFeed(_catalog()),
        throwsA(
          isA<OpdsException>().having(
            (OpdsException error) => error.failure,
            'failure',
            OpdsFailure.notAFeed,
          ),
        ),
      );
    });

    test('a connection that never opens is a network failure', () async {
      final OpdsClient client = OpdsClient(
        dio: _dio(
          _ScriptedAdapter((RequestOptions options) {
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'no route to host',
            );
          }),
        ),
        credentials: InMemoryOpdsCredentials(),
      );

      await expectLater(
        client.fetchFeed(_catalog()),
        throwsA(
          isA<OpdsException>().having(
            (OpdsException error) => error.failure,
            'failure',
            OpdsFailure.network,
          ),
        ),
      );
    });
  });
}
