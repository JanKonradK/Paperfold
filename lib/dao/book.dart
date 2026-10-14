import 'package:paperfold/dao/base_dao.dart';
import 'package:paperfold/dao/search_pattern.dart';
import 'package:paperfold/dao/shelf.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/models/book.dart';

class BookDao extends BaseDao {
  BookDao({super.database});

  static const String table = 'tb_books';

  Future<int> save(Book book) async {
    if (book.id != -1) {
      await updateBook(book);
      return book.id;
    }
    return insert(table, book.toMap());
  }

  Future<int> insertBook(Book book) => save(book);

  Future<void> updateBook(Book book) async {
    book.updateTime = DateTime.now();
    await update(
      table,
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  /// Soft-deletes a book and removes it from every shelf atomically.
  Future<void> deleteBook(int bookId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        ShelfDao.membershipTable,
        where: 'book_id = ?',
        whereArgs: [bookId],
      );
      await txn.update(
        table,
        {
          'is_deleted': 1,
          'update_time': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [bookId],
      );
    });
  }

  Future<List<Book>> selectBooks({bool includeDeleted = true}) {
    return queryList(
      table,
      mapper: Book.fromDb,
      where: includeDeleted ? null : 'is_deleted = 0',
      orderBy: 'update_time DESC',
    );
  }

  Future<List<Book>> selectNotDeleteBooks() {
    return selectBooks(includeDeleted: false);
  }

  /// Books finished during [year], oldest first.
  ///
  /// The reading challenge counts these, and it fills its spines in the order
  /// the reader finished them, so the order is part of the answer.
  ///
  /// `finished_on` holds an ISO 8601 string, so a year is a prefix match. A
  /// book marked finished before migration version 8 has no date and is not
  /// counted, because there is no year to count it in.
  Future<List<Book>> selectFinishedInYear(int year) {
    return queryList(
      table,
      mapper: Book.fromDb,
      where: 'is_deleted = 0 AND status = ? AND finished_on LIKE ?',
      whereArgs: [bookStatusFinished, '$year-%'],
      orderBy: 'finished_on ASC, id ASC',
    );
  }

  Future<Book> selectBookById(int id) async {
    final book = await querySingle(
      table,
      mapper: Book.fromDb,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (book == null) {
      throw StateError('Book with id $id not found');
    }
    return book;
  }

  Future<List<String>> getCurrentBooks() async {
    final books = await selectNotDeleteBooks();
    return books.map((book) => book.filePath).toList(growable: false);
  }

  Future<List<String>> getCurrentCover() async {
    final books = await selectNotDeleteBooks();
    return books.map((book) => book.coverPath).toList(growable: false);
  }

  Future<List<Book>> selectAllBooks() {
    return selectBooks();
  }

  Future<Book?> getBookByMd5(String md5) {
    return querySingle(
      table,
      mapper: Book.fromDb,
      where: 'file_md5 = ?',
      whereArgs: [md5],
    );
  }

  Future<List<Book>> searchBooks(
    String keyword, {
    int? bookId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final query = keyword.trim();
    if (query.isEmpty || (limit != null && limit <= 0)) {
      return const [];
    }

    final pattern = searchPattern(query);
    final where = [
      'is_deleted = 0',
      r"(title LIKE ? ESCAPE '\' OR author LIKE ? ESCAPE '\')",
    ];
    final arguments = <Object?>[pattern, pattern];
    if (bookId != null) {
      where.add('id = ?');
      arguments.add(bookId);
    }
    if (from != null) {
      where.add('update_time >= ?');
      arguments.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('update_time <= ?');
      arguments.add(to.toIso8601String());
    }

    return queryList(
      table,
      mapper: Book.fromDb,
      where: where.join(' AND '),
      whereArgs: arguments,
      orderBy: 'update_time DESC, id DESC',
      limit: limit,
    );
  }

  Future<List<Book>> selectBooksByIds(List<int> ids) async {
    if (ids.isEmpty) {
      return const [];
    }

    final placeholders = List.filled(ids.length, '?').join(',');
    return rawQueryList(
      'SELECT * FROM $table WHERE is_deleted = 0 AND id IN ($placeholders)',
      arguments: ids,
      mapper: Book.fromDb,
    );
  }

  Future<void> updateBookMd5(int bookId, String md5) {
    return update(
      table,
      {
        'file_md5': md5,
        'update_time': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<List<Book>> getBooksWithoutMd5() {
    return queryList(
      table,
      mapper: Book.fromDb,
      where: "is_deleted = 0 AND (file_md5 IS NULL OR file_md5 = '')",
      orderBy: 'update_time DESC',
    );
  }
}

final bookDao = BookDao();
