import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/tag.dart';
import 'package:paperfold/enums/sort_field.dart';
import 'package:paperfold/enums/sort_order.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/providers/tb_groups.dart';
import 'package:paperfold/providers/book_filters.dart';
import 'package:paperfold/providers/tags.dart'
    show kNoTagFilterId, tagSelectionProvider;
import 'package:lpinyin/lpinyin.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'book_list.g.dart';

@riverpod
class BookList extends _$BookList {
  List<List<Book>> groupBooks(List<Book> books) {
    final groupedBooks = <List<Book>>[];
    final groupsById = <int, List<Book>>{};
    for (final book in books) {
      final groupId = book.groupId;
      if (groupId == 0) {
        groupedBooks.add([book]);
      } else {
        groupsById.putIfAbsent(groupId, () {
          final group = <Book>[];
          groupedBooks.add(group);
          return group;
        }).add(book);
      }
    }
    return groupedBooks;
  }

  String _sortText(String value) {
    try {
      return PinyinHelper.getPinyin(value, format: PinyinFormat.WITHOUT_TONE);
    } catch (_) {
      return value;
    }
  }

  List<Book> sortBooks(List<Book> books) {
    final sortField = Prefs().sortField;
    final ascending = Prefs().sortOrder == SortOrderEnum.ascending;
    // Keep keys only for this sort; editing a title or author cannot leave a
    // stale key in the next refresh.
    final textKeys = <String, String>{};
    String textKey(String value) =>
        textKeys.putIfAbsent(value, () => _sortText(value));

    books.sort((a, b) {
      int compareResult;
      switch (sortField) {
        case SortFieldEnum.title:
          compareResult = textKey(a.title).compareTo(textKey(b.title));
          break;
        case SortFieldEnum.author:
          compareResult = textKey(a.author).compareTo(textKey(b.author));
          break;
        case SortFieldEnum.lastReadTime:
          compareResult = a.updateTime.compareTo(b.updateTime);
          break;
        case SortFieldEnum.progress:
          compareResult = a.readingPercentage.compareTo(b.readingPercentage);
          break;
        case SortFieldEnum.importTime:
          compareResult = a.createTime.compareTo(b.createTime);
          break;
      }
      return ascending ? compareResult : -compareResult;
    });
    return books;
  }

  bool _matchesStatus(Book book, ReadingStatusFilter status) {
    const notStartThreshold = 0.02;
    const finishedThreshold = 0.98;
    switch (status) {
      case ReadingStatusFilter.none:
        return true;
      case ReadingStatusFilter.finished:
        return book.readingPercentage >= finishedThreshold;
      case ReadingStatusFilter.reading:
        return book.readingPercentage > notStartThreshold &&
            book.readingPercentage < finishedThreshold;
      case ReadingStatusFilter.notStarted:
        return book.readingPercentage <= notStartThreshold;
    }
  }

  Future<List<List<Book>>> _buildWithFilters({String? query}) async {
    final status = ref.watch(readingStatusFilterNotifierProvider);
    final selectedTags = ref.watch(tagSelectionProvider);

    final books = await bookDao.selectNotDeleteBooks();
    final filteredByQuery = query == null || query.isEmpty
        ? books
        : books
            .where(
              (book) =>
                  book.title.contains(query) || book.author.contains(query),
            )
            .toList();

    final filteredByStatus =
        filteredByQuery.where((book) => _matchesStatus(book, status)).toList();

    List<Book> filteredByTags = filteredByStatus;
    if (selectedTags.isNotEmpty) {
      final tagMap = await bookTagDao.bookIdToTagIds(
          bookIds: filteredByStatus.map((b) => b.id).toList());
      if (selectedTags.contains(kNoTagFilterId)) {
        // Filter books without any tags
        filteredByTags = filteredByStatus.where((book) {
          final tags = tagMap[book.id];
          return tags == null || tags.isEmpty;
        }).toList();
      } else {
        // Filter books that contain all selected tags
        filteredByTags = filteredByStatus.where((book) {
          final tags = tagMap[book.id];
          if (tags == null || tags.isEmpty) return false;
          return selectedTags.every((id) => tags.contains(id));
        }).toList();
      }
    }

    final sortedBooks = sortBooks(filteredByTags);
    return groupBooks(sortedBooks);
  }

  @override
  Future<List<List<Book>>> build() async {
    return _buildWithFilters();
  }

  Future<void> refresh() async {
    state = AsyncData(await _buildWithFilters());
  }

  void moveBook(Book data, int groupId) {
    updateBook(data.copyWith(groupId: groupId));
    // insert a new group if not exists
    ref.read(groupDaoProvider.notifier).insertGroup(groupId);
    refresh();
  }

  void updateBook(Book book) {
    bookDao.updateBook(book);
    refresh();
  }

  void dissolveGroup(List<Book> books) {
    for (var book in books) {
      updateBook(book.copyWith(groupId: 0));
    }
    // delete the group
    ref.read(groupDaoProvider.notifier).hardDeleteGroup(books.first.groupId);
    refresh();
  }

  void removeFromGroup(Book book) {
    updateBook(book.copyWith(groupId: 0));
    refresh();
  }

  void reorder(List<List<Book>> books) {
    state = AsyncData(books);
  }

  void moveBookToTop(int bookId) {
    var groups = state.value!.map((group) {
      if (group.any((book) => book.id == bookId)) {
        return [
          group.firstWhere((book) => book.id == bookId),
          ...group.where((b) => b.id != bookId)
        ];
      }
      return group;
    }).toList();

    state = AsyncData([
      groups.firstWhere((group) => group.any((book) => book.id == bookId)),
      ...groups.where((group) => group.every((book) => book.id != bookId))
    ]);
  }

  Future<void> search(String? value) async {
    state = AsyncData(await _buildWithFilters(query: value));
  }
}
