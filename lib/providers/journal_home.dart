import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/book_review.dart';

/// One book's journal, as the Journal destination lists it.
class JournalEntry {
  const JournalEntry({
    required this.book,
    required this.review,
    required this.pageCount,
  });

  final Book book;

  /// Null when the reader has written pages but not filled in a review sheet.
  final BookReview? review;

  /// Dot pages holding real text. Blank pages are not counted, because a blank
  /// page is not writing.
  final int pageCount;
}

final journalHomeProvider =
    AsyncNotifierProvider<JournalHomeController, List<JournalEntry>>(
  JournalHomeController.new,
);

class JournalHomeController extends AsyncNotifier<List<JournalEntry>> {
  @override
  Future<List<JournalEntry>> build() => _load();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  Future<List<JournalEntry>> _load() async {
    final ids = await journalDao.listBookIdsWithWriting();
    if (ids.isEmpty) {
      return const [];
    }

    // The DAO returns ids most recently written first. Look the books up once
    // and keep that order rather than re-sorting by title.
    final books = await bookDao.selectNotDeleteBooks();
    final byId = {for (final book in books) book.id: book};

    final entries = <JournalEntry>[];
    for (final id in ids) {
      final book = byId[id];
      // A book can be deleted while its journal rows survive, since the
      // schema's foreign keys are declared but never enforced. Skip rather
      // than show an entry with no book behind it.
      if (book == null) {
        continue;
      }
      final pages = await journalDao.listPages(id);
      entries.add(
        JournalEntry(
          book: book,
          review: await journalDao.findReview(id),
          pageCount: pages.where((page) => !page.isEmpty).length,
        ),
      );
    }
    return entries;
  }
}
