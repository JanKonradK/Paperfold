import 'package:paperfold/dao/base_dao.dart';
import 'package:paperfold/dao/search_pattern.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/search_journal_result.dart';

class SearchJournalDao extends BaseDao {
  SearchJournalDao({super.database});

  Future<List<SearchJournalResult>> search(
    String keyword, {
    int? bookId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final query = keyword.trim();
    if (query.isEmpty || (limit != null && limit <= 0)) return const [];

    final where = <String>[
      'b.is_deleted = 0',
      r"writing.body LIKE ? ESCAPE '\'",
    ];
    final arguments = <Object?>[searchPattern(query)];
    if (bookId != null) {
      where.add('writing.book_id = ?');
      arguments.add(bookId);
    }
    if (from != null) {
      where.add('writing.update_time >= ?');
      arguments.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('writing.update_time <= ?');
      arguments.add(to.toIso8601String());
    }
    if (limit != null) arguments.add(limit);

    return rawQueryList(
      '''
      SELECT b.*, writing.id AS journal_id, writing.kind AS journal_kind,
        writing.page_index AS journal_page_index, writing.body AS journal_body
      FROM (
        SELECT id, book_id, update_time, 'review' AS kind, NULL AS page_index,
          COALESCE(thoughts, '') || CHAR(10) || COALESCE(favorite_quote, '') ||
          CHAR(10) || COALESCE(favorite_character, '') || CHAR(10) ||
          COALESCE(genre, '') || CHAR(10) || COALESCE(format, '') AS body
        FROM tb_reviews
        UNION ALL
        SELECT id, book_id, update_time, 'page' AS kind, page_index,
          COALESCE(body, '') || CHAR(10) || COALESCE(source_excerpt, '') ||
          CHAR(10) || COALESCE(source_chapter, '') AS body
        FROM tb_journal
      ) AS writing
      JOIN tb_books AS b ON b.id = writing.book_id
      WHERE ${where.join(' AND ')}
      ORDER BY writing.update_time DESC, writing.kind ASC, writing.id DESC
      ${limit == null ? '' : 'LIMIT ?'}
      ''',
      arguments: arguments,
      mapper: (row) => SearchJournalResult(
        book: Book.fromDb(row),
        id: row['journal_id'] as int,
        kind: row['journal_kind'] == 'review'
            ? SearchJournalKind.review
            : SearchJournalKind.page,
        text: row['journal_body'] as String,
        pageIndex: row['journal_page_index'] as int?,
      ),
    );
  }
}
