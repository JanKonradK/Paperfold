import 'package:paperfold/dao/base_dao.dart';
import 'package:paperfold/models/opds_catalog.dart';

/// The OPDS catalogs the reader has added.
///
/// **No password is ever written here.** [OpdsCatalog] carries the type of
/// authentication and the user name only. plan.md Section 9.2.
class CatalogDao extends BaseDao {
  CatalogDao({super.database});

  static const String table = 'tb_catalogs';

  /// Two free public catalogs, so a new shelf is never empty.
  ///
  /// plan.md Section 9.4: the weak first run and the OPDS feature are the same
  /// feature. A new reader has real books in one tap, before they own a file.
  static const List<({String name, String url})> defaultCatalogs =
      <({String name, String url})>[
    (name: 'Standard Ebooks', url: 'https://standardebooks.org/feeds/opds'),
    (
      name: 'Project Gutenberg',
      url: 'https://m.gutenberg.org/ebooks.opds/',
    ),
  ];

  Future<List<OpdsCatalog>> listCatalogs() {
    return queryList(
      table,
      mapper: OpdsCatalog.fromDb,
      orderBy: 'sort_order ASC, create_time ASC, id ASC',
    );
  }

  Future<OpdsCatalog?> findById(int id) {
    return querySingle(
      table,
      mapper: OpdsCatalog.fromDb,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Adds a catalog and returns its row id.
  Future<int> addCatalog({
    required String name,
    required Uri url,
    OpdsAuthType authType = OpdsAuthType.none,
    String? username,
    int sortOrder = 0,
  }) {
    return insert(table, <String, Object?>{
      'name': name.trim(),
      'url': url.toString(),
      'auth_type': authType.databaseValue,
      'username': username?.trim(),
      'sort_order': sortOrder,
      'create_time': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateCatalog(OpdsCatalog catalog) async {
    await update(
      table,
      catalog.toDb(),
      where: 'id = ?',
      whereArgs: [catalog.id],
    );
  }

  /// Removes a catalog.
  ///
  /// The caller must clear the stored password as well. The keystore is a
  /// different store, so a delete here leaves nothing behind that could still
  /// hold a secret, but it also cannot reach one.
  Future<void> deleteCatalog(int id) async {
    await delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// Writes the two default catalogs, once.
  ///
  /// Does nothing when the reader already has catalogs, so a reader who
  /// deleted them does not get them back on the next start.
  Future<bool> seedDefaultsIfEmpty() async {
    final List<OpdsCatalog> existing = await listCatalogs();
    if (existing.isNotEmpty) {
      return false;
    }
    for (int index = 0; index < defaultCatalogs.length; index++) {
      final ({String name, String url}) catalog = defaultCatalogs[index];
      await addCatalog(
        name: catalog.name,
        url: Uri.parse(catalog.url),
        sortOrder: index,
      );
    }
    return true;
  }
}

final catalogDao = CatalogDao();
