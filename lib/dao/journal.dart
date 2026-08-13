import 'package:paperfold/dao/base_dao.dart';
import 'package:paperfold/models/book_review.dart';
import 'package:paperfold/models/journal_page.dart';

/// The journal: one review sheet per book, and any number of dot pages.
///
/// tb_notes is a highlight table anchored to a location inside a book. Reviews
/// and journal pages are book-level, so they live in their own tables and are
/// read through here. plan.md Section 3.2.
class JournalDao extends BaseDao {
  JournalDao({super.database});

  static const String reviewTable = 'tb_reviews';
  static const String pageTable = 'tb_journal';

  String get _now => DateTime.now().toIso8601String();

  /// The review sheet for [bookId], or null when the reader has not written
  /// one. Callers that want an editable sheet should use [reviewOrEmpty].
  Future<BookReview?> findReview(int bookId) {
    return querySingle(
      reviewTable,
      mapper: BookReview.fromDb,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'id ASC',
    );
  }

  /// The stored sheet, or a blank one that has never been written. This is what
  /// a review screen opens on, so the caller never has to special-case a book
  /// with no review yet.
  Future<BookReview> reviewOrEmpty(int bookId) async {
    return await findReview(bookId) ?? BookReview(bookId: bookId);
  }

  /// Writes [review] and returns its row id.
  ///
  /// An empty sheet is deleted rather than stored. A reader who opens a review,
  /// changes nothing and leaves should not create a row, and one who clears
  /// every field is asking for the review to go away.
  Future<int?> saveReview(BookReview review) async {
    if (review.isEmpty) {
      if (review.id != null) {
        await delete(reviewTable, where: 'id = ?', whereArgs: [review.id]);
      }
      return null;
    }

    final values = review.toDb()..['update_time'] = _now;
    if (review.id == null) {
      values['create_time'] = _now;
      return insert(reviewTable, values);
    }
    await update(
      reviewTable,
      values,
      where: 'id = ?',
      whereArgs: [review.id],
    );
    return review.id;
  }

  /// Every dot page for a book, in reading order.
  Future<List<JournalPage>> listPages(int bookId) {
    return queryList(
      pageTable,
      mapper: JournalPage.fromDb,
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'page_index ASC, id ASC',
    );
  }

  /// Books that have any journal writing, most recently touched first. This is
  /// what the Journal destination lists.
  Future<List<int>> listBookIdsWithWriting() {
    return rawQueryList(
      '''
      SELECT book_id, MAX(update_time) AS last_touched FROM (
        SELECT book_id, update_time FROM $pageTable
          WHERE TRIM(COALESCE(body, '')) <> ''
        UNION ALL
        SELECT book_id, update_time FROM $reviewTable
      )
      GROUP BY book_id
      ORDER BY last_touched DESC, book_id DESC
      ''',
      mapper: (row) => row['book_id'] as int,
    );
  }

  /// Adds a blank page after the last one for this book.
  Future<int> addPage(int bookId) async {
    final pages = await listPages(bookId);
    final nextIndex =
        pages.isEmpty ? 0 : pages.map((p) => p.pageIndex).reduce(_max) + 1;
    return insert(pageTable, {
      'book_id': bookId,
      'page_index': nextIndex,
      'body': '',
      'create_time': _now,
      'update_time': _now,
    });
  }

  /// Writes [page] and returns its row id, or null when it was removed.
  ///
  /// A page emptied of text is deleted, for the same reason an empty review is.
  Future<int?> savePage(JournalPage page) async {
    if (page.isEmpty && page.id != null) {
      await delete(pageTable, where: 'id = ?', whereArgs: [page.id]);
      return null;
    }

    final values = page.toDb()..['update_time'] = _now;
    if (page.id == null) {
      values['create_time'] = _now;
      return insert(pageTable, values);
    }
    await update(pageTable, values, where: 'id = ?', whereArgs: [page.id]);
    return page.id;
  }

  /// Removes everything a book's journal holds. Called when a book is deleted,
  /// because the schema declares foreign keys that SQLite does not enforce.
  Future<void> deleteForBook(int bookId) async {
    await delete(reviewTable, where: 'book_id = ?', whereArgs: [bookId]);
    await delete(pageTable, where: 'book_id = ?', whereArgs: [bookId]);
  }

  static int _max(int a, int b) => a > b ? a : b;
}

final journalDao = JournalDao();
