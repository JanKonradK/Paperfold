import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/dao/catalog.dart';
import 'package:paperfold/models/opds_catalog.dart';
import 'package:paperfold/service/opds/opds.dart';
import 'package:paperfold/service/opds/opds_client.dart';
import 'package:paperfold/service/opds/opds_credentials.dart';

/// The password store. Overridden in tests with an in-memory one.
final opdsCredentialsProvider = Provider<OpdsCredentials>(
  (Ref ref) => const KeystoreOpdsCredentials(),
);

final opdsClientProvider = Provider<OpdsClient>(
  (Ref ref) => OpdsClient(credentials: ref.watch(opdsCredentialsProvider)),
);

final opdsCatalogDaoProvider = Provider<CatalogDao>((ref) => catalogDao);

/// Saved catalogs only. Built-in suggestions live in the discovery hub.
final opdsCatalogsProvider =
    AsyncNotifierProvider<OpdsCatalogsController, List<OpdsCatalog>>(
  OpdsCatalogsController.new,
);

class OpdsCatalogsController extends AsyncNotifier<List<OpdsCatalog>> {
  @override
  Future<List<OpdsCatalog>> build() => _load();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  Future<int> add({
    required String name,
    required Uri url,
    OpdsAuthType authType = OpdsAuthType.none,
    String? username,
    String? password,
  }) async {
    if (!isOpdsWebUri(url)) {
      throw ArgumentError('Catalog addresses must not contain credentials.');
    }
    final dao = ref.read(opdsCatalogDaoProvider);
    final int id = await dao.addCatalog(
      name: name,
      url: url,
      authType: authType,
      username: username,
    );
    try {
      if (authType == OpdsAuthType.basic) {
        // Some catalogs authenticate an email address with an empty password.
        await ref.read(opdsCredentialsProvider).write(id, password ?? '');
      }
    } catch (_) {
      await dao.deleteCatalog(id);
      rethrow;
    }
    await refresh();
    return id;
  }

  Future<void> setPassword(int catalogId, String password) async {
    await ref.read(opdsCredentialsProvider).write(catalogId, password);
  }

  /// Removes a catalog and its password together.
  ///
  /// The keystore is a separate store. Deleting the row alone would leave the
  /// password behind with nothing left to name it.
  Future<void> remove(int catalogId) async {
    await ref.read(opdsCredentialsProvider).delete(catalogId);
    await ref.read(opdsCatalogDaoProvider).deleteCatalog(catalogId);
    await refresh();
  }

  Future<List<OpdsCatalog>> _load() =>
      ref.read(opdsCatalogDaoProvider).listCatalogs();
}

/// Which feed of which catalog a browse screen is showing.
class OpdsFeedRequest {
  const OpdsFeedRequest(this.catalog, this.url);

  final OpdsCatalog catalog;

  /// Null means the catalog's own address.
  final Uri? url;

  Uri get resolved => url ?? catalog.url;

  @override
  bool operator ==(Object other) =>
      other is OpdsFeedRequest &&
      other.catalog.id == catalog.id &&
      other.resolved == resolved;

  @override
  int get hashCode => Object.hash(catalog.id, resolved);
}

/// One feed, fetched and parsed.
///
/// Keyed by the request, so following a link and coming back does not refetch,
/// and two catalogs never share a cached feed.
final opdsFeedProvider = FutureProvider.family<OpdsFeed, OpdsFeedRequest>(
    (Ref ref, OpdsFeedRequest request) {
  return ref
      .watch(opdsClientProvider)
      .fetchFeed(request.catalog, url: request.url);
});
