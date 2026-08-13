import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/dao/shelf.dart';
import 'package:paperfold/dao/wishlist.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/wishlist_item.dart';

class ShelfHomeData {
  const ShelfHomeData({
    required this.readingNow,
    required this.favourites,
    required this.toBeRead,
    required this.finished,
    required this.booksToBuy,
  });

  final List<Book> readingNow;
  final List<Book> favourites;
  final List<Book> toBeRead;
  final List<Book> finished;
  final List<WishlistItem> booksToBuy;
}

final shelfHomeProvider =
    AsyncNotifierProvider<ShelfHomeController, ShelfHomeData>(
  ShelfHomeController.new,
);

class ShelfHomeController extends AsyncNotifier<ShelfHomeData> {
  @override
  Future<ShelfHomeData> build() => _load();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  Future<ShelfHomeData> _load() async {
    final allBooksFuture = bookDao.selectNotDeleteBooks();
    final favouritesFuture = shelfDao.listBooks(builtInFavouritesShelfId);
    final booksToBuyFuture = wishlistDao.listBooksToBuy();

    final allBooks = await allBooksFuture;
    final favourites = await favouritesFuture;
    final booksToBuy = await booksToBuyFuture;

    return ShelfHomeData(
      readingNow: allBooks
          .where((book) => book.status == BookStatus.reading)
          .toList(growable: false),
      favourites: favourites,
      toBeRead: allBooks
          .where((book) => book.status == BookStatus.notStarted)
          .toList(growable: false),
      finished: allBooks
          .where((book) => book.status == BookStatus.finished)
          .toList(growable: false),
      booksToBuy: booksToBuy,
    );
  }
}
