import 'package:paperfold/dao/base_dao.dart';
import 'package:paperfold/dao/daily_read.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/widgets/bookshelf/physical_progress_sheet.dart';
import 'package:paperfold/models/book_review.dart';
import 'package:paperfold/models/book_note.dart';
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
    await update(reviewTable, values, where: 'id = ?', whereArgs: [review.id]);
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
    return rawQueryList('''
      SELECT book_id, MAX(update_time) AS last_touched FROM (
        SELECT book_id, update_time FROM $pageTable
          WHERE TRIM(COALESCE(body, '')) <> ''
             OR TRIM(COALESCE(source_cfi, '')) <> ''
             OR TRIM(COALESCE(source_excerpt, '')) <> ''
             OR photo_path IS NOT NULL OR source_page IS NOT NULL OR source_locator IS NOT NULL
        UNION ALL
        SELECT book_id, update_time FROM $reviewTable
      )
      GROUP BY book_id
      ORDER BY last_touched DESC, book_id DESC
      ''', mapper: (row) => row['book_id'] as int);
  }

  /// Adds a blank page after the last one for this book.
  Future<int> addPage(int bookId) async {
    final pages = await listPages(bookId);
    final nextIndex = pages.isEmpty
        ? 0
        : pages.map((p) => p.pageIndex).reduce(_max) + 1;
    return insert(pageTable, {
      'book_id': bookId,
      'page_index': nextIndex,
      'body': '',
      'create_time': _now,
      'update_time': _now,
    });
  }

  /// Copies a saved passage without depending on the highlight's lifetime.
  Future<int> addPageFromNote(BookNote note) {
    if (note.id == null ||
        note.content.trim().isEmpty ||
        note.cfi.trim().isEmpty) {
      throw ArgumentError('A saved passage with a source location is required');
    }
    // Snapshot mutable note fields before the database yields.
    final page = JournalPage(
      bookId: note.bookId,
      pageIndex: 0,
      body: note.readerNote ?? '',
      entryKind: 'quote',
      sourceLocator: note.cfi,
      sourceCfi: note.cfi,
      sourceExcerpt: note.content,
      sourceChapter: note.chapter,
    );
    return transaction((txn) async {
      final existing = await txn.query(
        pageTable,
        columns: ['id'],
        where: 'book_id = ? AND source_cfi = ?',
        whereArgs: [page.bookId, page.sourceCfi],
        limit: 1,
      );
      if (existing.isNotEmpty) return existing.single['id'] as int;
      final rows = await txn.rawQuery(
        'SELECT COALESCE(MAX(page_index), -1) + 1 AS next_index '
        'FROM $pageTable WHERE book_id = ?',
        [page.bookId],
      );
      final values = page
          .copyWith(pageIndex: rows.single['next_index'] as int)
          .toDb();
      final now = _now;
      return txn.insert(pageTable, {
        ...values,
        'create_time': now,
        'update_time': now,
      });
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

  Future<int> deletePage(int pageId) =>
      delete(pageTable, where: 'id = ?', whereArgs: [pageId]);

  /// Removes everything a book's journal holds. Called when a book is deleted,
  /// because the schema declares foreign keys that SQLite does not enforce.
  Future<void> deleteForBook(int bookId) async {
    await delete(reviewTable, where: 'book_id = ?', whereArgs: [bookId]);
    await delete(pageTable, where: 'book_id = ?', whereArgs: [bookId]);
  }

  /// Every saved page photo, as a path relative to the documents folder.
  /// Sync and backup use it to keep `journal_photos/` complete.
  Future<List<String>> currentPhotos() async {
    final rows = await queryList(
      pageTable,
      mapper: JournalPage.fromDb,
      where: "photo_path IS NOT NULL AND photo_path <> ''",
    );
    return [for (final row in rows) if (row.photoPath != null) row.photoPath!];
  }

  Future<List<JournalPage>> recentEntries({int offset = 0, int limit = 30}) =>
      queryList(
        pageTable,
        mapper: JournalPage.fromDb,
        where: "TRIM(COALESCE(body, '')) <> '' OR source_excerpt IS NOT NULL OR source_locator IS NOT NULL OR source_page IS NOT NULL OR photo_path IS NOT NULL",
        orderBy: 'create_time DESC, id DESC',
        limit: limit,
        offset: offset,
      );

  /// Numeric reading order. Legacy rows without a position remain reachable.
  Future<List<JournalPage>> entriesAt(
    int bookId, {
    double? progress,
    int? page,
    bool includeLater = false,
  }) => queryList(
    pageTable,
    mapper: JournalPage.fromDb,
    where:
        'book_id = ?' +
        (includeLater
            ? ''
            : page != null
            ? ' AND (source_page IS NULL OR source_page <= ?)'
            : ' AND (source_progress IS NULL OR source_progress <= ?)'),
    whereArgs: [bookId, if (!includeLater) page ?? progress ?? 0],
    orderBy: 'COALESCE(source_page, source_progress, -1) ASC, id ASC',
  );

  /// Progress, tracker delta, and writing commit together. Mutate no caller data.
  Future<int> saveEntry(
    JournalPage entry, {
    int? physicalPage,
    int? totalPages,
  }) => transaction((txn) async {
    if (entry.id != null) {
      final existing = await txn.query(
        pageTable,
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [entry.id],
        limit: 1,
      );
      if (existing.isNotEmpty) return entry.id!;
    }
    final now = _now;
    if (physicalPage != null) {
      final rows = await txn.query(
        'tb_books',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [entry.bookId],
      );
      if (rows.isEmpty) throw ArgumentError('Book is unavailable');
      final book = Book.fromDb(rows.single);
      if (!book.isPhysical ||
          !validPhysicalProgress(physicalPage, totalPages ?? book.totalPages)) {
        throw ArgumentError('Invalid paper book progress');
      }
      final delta = physicalPage - book.currentPage;
      applyPhysicalProgress(book, physicalPage, totalPages: totalPages);
      await txn.update(
        'tb_books',
        {...book.toMap(), 'update_time': now},
        where: 'id = ?',
        whereArgs: [book.id],
      );
      if (delta > 0) {
        final date = DailyReadDao.dateKey(DateTime.now());
        await txn.rawInsert(
          'INSERT INTO tb_daily_read (date, pages_read, create_time, update_time) VALUES (?, ?, ?, ?) ON CONFLICT(date) DO UPDATE SET pages_read = pages_read + excluded.pages_read, update_time = excluded.update_time',
          [date, delta, now, now],
        );
      }
    }
    final rows = await txn.rawQuery(
      'SELECT COALESCE(MAX(page_index), -1) + 1 AS n FROM $pageTable WHERE book_id = ?',
      [entry.bookId],
    );
    return txn.insert(pageTable, {
      if (entry.id != null) 'id': entry.id,
      ...entry.copyWith(pageIndex: rows.single['n'] as int).toDb(),
      'create_time': now,
      'update_time': now,
    });
  });

  static int _max(int a, int b) => a > b ? a : b;
}

final journalDao = JournalDao();
