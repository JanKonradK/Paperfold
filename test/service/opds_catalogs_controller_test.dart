import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/dao/catalog.dart';
import 'package:paperfold/models/opds_catalog.dart';
import 'package:paperfold/providers/opds.dart';
import 'package:paperfold/service/opds/online_book_sources.dart';
import 'package:paperfold/service/opds/opds_credentials.dart';

class _CatalogDao extends CatalogDao {
  final rows = <OpdsCatalog>[];
  int seedCalls = 0;
  int nextId = 1;

  @override
  Future<List<OpdsCatalog>> listCatalogs() async => List.of(rows);

  @override
  Future<bool> seedDefaultsIfEmpty() async {
    seedCalls++;
    return false;
  }

  @override
  Future<int> addCatalog({
    required String name,
    required Uri url,
    OpdsAuthType authType = OpdsAuthType.none,
    String? username,
    int sortOrder = 0,
  }) async {
    final id = nextId++;
    rows.add(OpdsCatalog(
        id: id,
        name: name,
        url: url,
        authType: authType,
        username: username,
        sortOrder: sortOrder));
    return id;
  }

  @override
  Future<void> deleteCatalog(int id) async {
    rows.removeWhere((catalog) => catalog.id == id);
  }
}

class _FailingCredentials extends InMemoryOpdsCredentials {
  @override
  Future<void> write(int catalogId, String password) async {
    throw StateError('Keystore unavailable');
  }
}

void main() {
  ProviderContainer createContainer(_CatalogDao dao,
      {OpdsCredentials? credentials}) {
    final container = ProviderContainer(overrides: [
      opdsCatalogDaoProvider.overrideWithValue(dao),
      opdsCredentialsProvider
          .overrideWithValue(credentials ?? InMemoryOpdsCredentials()),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('saved catalogs stay empty after removal and provider recreation',
      () async {
    final dao = _CatalogDao();
    final container = createContainer(dao);
    expect(await container.read(opdsCatalogsProvider.future), isEmpty);
    final controller = container.read(opdsCatalogsProvider.notifier);
    final id = await controller.add(
        name: 'My library', url: Uri.parse('https://home.example/opds'));
    await controller.remove(id);
    container.invalidate(opdsCatalogsProvider);
    expect(await container.read(opdsCatalogsProvider.future), isEmpty);
    expect(dao.seedCalls, 0);
  });

  test(
      'custom catalogs are returned unchanged alongside static recommendations',
      () async {
    final dao = _CatalogDao();
    await dao.addCatalog(
        name: 'Private library',
        url: Uri.parse('https://home.example/opds'),
        authType: OpdsAuthType.basic,
        username: 'reader',
        sortOrder: 9);
    final container = createContainer(dao);
    final saved = await container.read(opdsCatalogsProvider.future);
    expect(saved.single.name, 'Private library');
    expect(saved.single.authType, OpdsAuthType.basic);
    expect(saved.single.username, 'reader');
    expect(saved.single.sortOrder, 9);
    expect(dao.rows, hasLength(1));
    expect(dao.seedCalls, 0);
  });

  test('a failed secret write rolls back the row before a retry', () async {
    final dao = _CatalogDao();
    final container = createContainer(dao, credentials: _FailingCredentials());
    await container.read(opdsCatalogsProvider.future);
    await expectLater(
        container.read(opdsCatalogsProvider.notifier).add(
              name: 'Private library',
              url: Uri.parse('https://home.example/opds'),
              authType: OpdsAuthType.basic,
              username: 'reader',
              password: 'secret',
            ),
        throwsStateError);
    expect(dao.rows, isEmpty);
    expect(container.read(opdsCatalogsProvider).requireValue, isEmpty);
  });

  test('credential URLs never reach catalog storage', () async {
    final dao = _CatalogDao();
    final container = createContainer(dao);
    await container.read(opdsCatalogsProvider.future);
    await expectLater(
        container.read(opdsCatalogsProvider.notifier).add(
              name: 'Private library',
              url: Uri.parse('https://reader:secret@home.example/opds'),
            ),
        throwsA(isA<ArgumentError>().having((error) => error.toString(),
            'diagnostic', isNot(contains('secret')))));
    expect(dao.rows, isEmpty);
  });

  test('email-only login keeps its explicitly empty password', () async {
    final dao = _CatalogDao();
    final credentials = InMemoryOpdsCredentials();
    final container = createContainer(dao, credentials: credentials);
    await container.read(opdsCatalogsProvider.future);
    final id = await container.read(opdsCatalogsProvider.notifier).add(
          name: 'Patron library',
          url: Uri.parse('https://books.example/opds'),
          authType: OpdsAuthType.basic,
          username: 'reader@example.com',
          password: '',
        );
    expect(await credentials.read(id), '');
  });

  test('legacy Gutenberg address matches its current recommendation', () {
    final legacy = OpdsCatalog(
        id: 2,
        name: 'Gutenberg',
        url: Uri.parse('https://m.gutenberg.org/ebooks.opds/'));
    expect(OnlineBookSource.gutenberg.matchesCatalog(legacy), isTrue);
    expect(OnlineBookSource.ebooksGratuits.matchesCatalog(legacy), isFalse);
  });
}
