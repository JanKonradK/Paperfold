import 'package:paperfold/dao/base_dao.dart';
import 'package:paperfold/models/book.dart';

class ShelfDao extends BaseDao {
  ShelfDao({super.database});

  static const String membershipTable = 'tb_shelf_books';

  Future<void> addBookToShelf({
    required int shelfId,
    required int bookId,
    int? sortOrder,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final resolvedSortOrder = sortOrder ??
          ((await txn.rawQuery(
                    'SELECT MAX(sort_order) AS maximum FROM $membershipTable WHERE shelf_id = ?',
                    [shelfId],
                  ))
                      .first['maximum'] as int? ??
                  -1) +
              1;

      await txn.insert(membershipTable, {
        'shelf_id': shelfId,
        'book_id': bookId,
        'sort_order': resolvedSortOrder,
        'create_time': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> removeBookFromShelf({
    required int shelfId,
    required int bookId,
  }) async {
    await delete(
      membershipTable,
      where: 'shelf_id = ? AND book_id = ?',
      whereArgs: [shelfId, bookId],
    );
  }

  Future<void> removeBookFromAllShelves(int bookId) async {
    await delete(
      membershipTable,
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  Future<bool> containsBook({
    required int shelfId,
    required int bookId,
  }) async {
    final rows = await queryList(
      membershipTable,
      columns: const ['book_id'],
      where: 'shelf_id = ? AND book_id = ?',
      whereArgs: [shelfId, bookId],
      limit: 1,
      mapper: (row) => row['book_id'] as int,
    );
    return rows.isNotEmpty;
  }

  /// Deletes a shelf and its memberships without relying on SQLite cascades.
  Future<void> deleteShelf(int shelfId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        membershipTable,
        where: 'shelf_id = ?',
        whereArgs: [shelfId],
      );
      await txn.delete(
        'tb_shelves',
        where: 'id = ?',
        whereArgs: [shelfId],
      );
    });
  }

  Future<List<Book>> listBooks(int shelfId) {
    return rawQueryList(
      '''
      SELECT books.*
      FROM tb_books AS books
      INNER JOIN $membershipTable AS shelf_books
        ON shelf_books.book_id = books.id
      WHERE shelf_books.shelf_id = ?
        AND books.is_deleted = 0
      ORDER BY shelf_books.sort_order ASC,
               shelf_books.create_time ASC,
               books.id ASC
      ''',
      arguments: [shelfId],
      mapper: Book.fromDb,
    );
  }

  /// Replaces the complete book order for one shelf.
  Future<void> reorderBooks(int shelfId, List<int> bookIds) async {
    if (bookIds.length != bookIds.toSet().length) {
      throw ArgumentError.value(bookIds, 'bookIds', 'contains duplicates');
    }

    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        membershipTable,
        columns: ['book_id'],
        where: 'shelf_id = ?',
        whereArgs: [shelfId],
      );
      final existingIds = rows.map((row) => row['book_id'] as int).toSet();
      if (existingIds.length != bookIds.length ||
          !existingIds.containsAll(bookIds)) {
        throw ArgumentError.value(
          bookIds,
          'bookIds',
          'must contain every book on the shelf exactly once',
        );
      }

      for (var index = 0; index < bookIds.length; index++) {
        await txn.update(
          membershipTable,
          {'sort_order': index},
          where: 'shelf_id = ? AND book_id = ?',
          whereArgs: [shelfId, bookIds[index]],
        );
      }
    });
  }
}

final shelfDao = ShelfDao();
