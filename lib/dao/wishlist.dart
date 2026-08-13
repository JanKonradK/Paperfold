import 'package:paperfold/dao/base_dao.dart';
import 'package:paperfold/models/wishlist_item.dart';

class WishlistDao extends BaseDao {
  WishlistDao({super.database});

  static const String table = 'tb_wishlist';

  Future<List<WishlistItem>> listBooksToBuy() {
    return queryList(
      table,
      mapper: WishlistItem.fromDb,
      where: 'COALESCE(bought, 0) = 0',
      orderBy: 'sort_order ASC, create_time ASC, id ASC',
    );
  }

  Future<int> addBookToBuy({
    required String title,
    required String author,
  }) {
    final now = DateTime.now().toIso8601String();
    return insert(table, {
      'title': title.trim(),
      'author': author.trim(),
      'bought': 0,
      'sort_order': 0,
      'create_time': now,
      'update_time': now,
    });
  }
}

final wishlistDao = WishlistDao();
