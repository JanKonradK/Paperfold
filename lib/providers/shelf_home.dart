import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/dao/shelf.dart';
import 'package:paperfold/dao/tag.dart';
import 'package:paperfold/dao/wishlist.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/tag.dart';
import 'package:paperfold/models/wishlist_item.dart';

class ShelfHomeData {
  const ShelfHomeData({
    required this.readingNow,
    required this.favourites,
    required this.toBeRead,
    required this.finished,
    required this.booksToBuy,
    this.tags = const [],
    this.bookTagIds = const {},
  });

  final List<Book> readingNow;
  final List<Book> favourites;
  final List<Book> toBeRead;
  final List<Book> finished;
  final List<WishlistItem> booksToBuy;
  final List<Tag> tags;
  final Map<int, List<int>> bookTagIds;
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
    final tagsFuture = tagDao.fetchAllTags();

    final allBooks = await allBooksFuture;
    final favourites = await favouritesFuture;
    final booksToBuy = await booksToBuyFuture;
    final tags = await tagsFuture;
    final bookTagIds = await bookTagDao.bookIdToTagIds(
      bookIds: allBooks.map((book) => book.id).toList(growable: false),
    );

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
      tags: tags,
      bookTagIds: bookTagIds,
    );
  }
}

enum ShelfSortField { title, author, dateAdded, progress, rating }

enum ShelfSortDirection { ascending, descending }

/// The controls are independent of the shelf query. This keeps a filter from
/// changing which books belong to a shelf while still making the visible rows
/// predictable and testable.
class ShelfHomeControls extends ChangeNotifier {
  ShelfHomeControls({Prefs? prefs}) : _prefs = prefs ?? Prefs() {
    _read();
  }

  static const _sortFieldKey = 'shelfSortField';
  static const _sortDirectionKey = 'shelfSortDirection';
  static const _statusFiltersKey = 'shelfStatusFilters';
  static const _minimumRatingKey = 'shelfMinimumRating';
  static const _tagFiltersKey = 'shelfTagFilters';

  final Prefs _prefs;

  ShelfSortField sortField = ShelfSortField.dateAdded;
  ShelfSortDirection sortDirection = ShelfSortDirection.descending;
  Set<BookStatus> statusFilters = <BookStatus>{};
  double? minimumRating;
  Set<int> tagFilters = <int>{};

  bool get hasFilters => statusFilters.isNotEmpty ||
      minimumRating != null ||
      tagFilters.isNotEmpty;

  int get filterCount =>
      statusFilters.length + (minimumRating == null ? 0 : 1) + tagFilters.length;

  void _read() {
    final storedField = _prefs.prefs.getString(_sortFieldKey);
    sortField = ShelfSortField.values.firstWhere(
      (value) => value.name == storedField,
      orElse: () => ShelfSortField.dateAdded,
    );
    final storedDirection = _prefs.prefs.getString(_sortDirectionKey);
    sortDirection = ShelfSortDirection.values.firstWhere(
      (value) => value.name == storedDirection,
      orElse: () => ShelfSortDirection.descending,
    );
    final storedStatuses =
        _prefs.prefs.getStringList(_statusFiltersKey) ?? const <String>[];
    statusFilters = BookStatus.values
        .where((status) => storedStatuses.contains(status.name))
        .toSet();
    final rating = _prefs.prefs.getDouble(_minimumRatingKey);
    minimumRating =
        rating == null || rating <= 0 ? null : rating.clamp(1, 5).toDouble();
    tagFilters = (_prefs.prefs.getStringList(_tagFiltersKey) ?? const <String>[])
        .map(int.tryParse)
        .whereType<int>()
        .toSet();
  }

  void setSortField(ShelfSortField value) {
    if (sortField == value) return;
    sortField = value;
    _prefs.prefs.setString(_sortFieldKey, value.name);
    notifyListeners();
  }

  void setSortDirection(ShelfSortDirection value) {
    if (sortDirection == value) return;
    sortDirection = value;
    _prefs.prefs.setString(_sortDirectionKey, value.name);
    notifyListeners();
  }

  void toggleStatus(BookStatus status) {
    if (!statusFilters.remove(status)) statusFilters.add(status);
    _prefs.prefs.setStringList(
      _statusFiltersKey,
      statusFilters.map((value) => value.name).toList(growable: false),
    );
    notifyListeners();
  }

  void setMinimumRating(double? rating) {
    final next = rating == null || rating <= 0
        ? null
        : rating.clamp(1, 5).toDouble();
    if (minimumRating == next) return;
    minimumRating = next;
    if (next == null) {
      _prefs.prefs.remove(_minimumRatingKey);
    } else {
      _prefs.prefs.setDouble(_minimumRatingKey, next);
    }
    notifyListeners();
  }

  void toggleTag(int tagId) {
    if (!tagFilters.remove(tagId)) tagFilters.add(tagId);
    _prefs.prefs.setStringList(
      _tagFiltersKey,
      tagFilters.map((value) => '$value').toList(growable: false),
    );
    notifyListeners();
  }

  void clearFilters() {
    if (!hasFilters) return;
    statusFilters.clear();
    minimumRating = null;
    tagFilters.clear();
    _prefs.prefs.remove(_statusFiltersKey);
    _prefs.prefs.remove(_minimumRatingKey);
    _prefs.prefs.remove(_tagFiltersKey);
    notifyListeners();
  }

  List<Book> booksForShelf(
    List<Book> source,
    Map<int, List<int>> bookTagIds,
  ) {
    final indexed = source.indexed.where((entry) {
      final book = entry.$2;
      if (statusFilters.isNotEmpty && !statusFilters.contains(book.status)) {
        return false;
      }
      if (minimumRating case final rating?) {
        if (book.rating < rating) return false;
      }
      if (tagFilters.isNotEmpty) {
        final bookTags = bookTagIds[book.id]?.toSet() ?? const <int>{};
        if (!tagFilters.every(bookTags.contains)) return false;
      }
      return true;
    }).toList();

    indexed.sort((left, right) {
      final compared = _compareBooks(left.$2, right.$2);
      if (compared == 0) return left.$1.compareTo(right.$1);
      return sortDirection == ShelfSortDirection.ascending
          ? compared
          : -compared;
    });
    return indexed.map((entry) => entry.$2).toList(growable: false);
  }

  List<WishlistItem> wishlistForShelf(List<WishlistItem> source) {
    // Wishlist entries have no reading state, rating, or tags. Hiding them is
    // more truthful than showing entries that cannot satisfy an active filter.
    if (hasFilters) return const [];
    final indexed = source.indexed.toList();
    indexed.sort((left, right) {
      final compared = switch (sortField) {
        ShelfSortField.title => _text(left.$2.title, right.$2.title),
        ShelfSortField.author => _text(left.$2.author, right.$2.author),
        ShelfSortField.dateAdded ||
        ShelfSortField.progress ||
        ShelfSortField.rating => 0,
      };
      if (compared == 0) return left.$1.compareTo(right.$1);
      return sortDirection == ShelfSortDirection.ascending
          ? compared
          : -compared;
    });
    return indexed.map((entry) => entry.$2).toList(growable: false);
  }

  int _compareBooks(Book left, Book right) => switch (sortField) {
        ShelfSortField.title => _text(left.title, right.title),
        ShelfSortField.author => _text(left.author, right.author),
        ShelfSortField.dateAdded => left.createTime.compareTo(right.createTime),
        ShelfSortField.progress =>
          left.readingPercentage.compareTo(right.readingPercentage),
        ShelfSortField.rating => left.rating.compareTo(right.rating),
      };

  static int _text(String left, String right) =>
      left.toLowerCase().compareTo(right.toLowerCase());
}

final shelfHomeControlsProvider =
    ChangeNotifierProvider<ShelfHomeControls>((ref) => ShelfHomeControls());
