import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/book_note.dart';
import 'package:paperfold/dao/search_journal.dart';
import 'package:paperfold/models/book_note.dart';
import 'package:paperfold/models/search_note_group.dart';
import 'package:paperfold/models/search_result_data.dart';
import 'package:sqflite/sqflite.dart';

class SearchRepository {
  const SearchRepository({Database? database}) : _database = database;

  final Database? _database;

  Future<SearchResultData> search(
    String keyword, {
    int? bookId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final query = keyword.trim();
    if (query.isEmpty || (limit != null && limit <= 0)) {
      return SearchResultData.empty;
    }

    final booksDao = BookDao(database: _database);
    final books = await booksDao.searchBooks(
      query,
      bookId: bookId,
      from: from,
      to: to,
      limit: limit,
    );
    final notes =
        await BookNoteDao(database: _database).searchBookNotesAdvanced(
      keyword: query,
      bookId: bookId,
      from: from,
      to: to,
      limit: limit,
    );

    final journalResults = await SearchJournalDao(database: _database).search(
      query,
      bookId: bookId,
      from: from,
      to: to,
      limit: limit,
    );

    final notesByBookId = <int, List<BookNote>>{};
    for (final note in notes) {
      notesByBookId.putIfAbsent(note.bookId, () => []).add(note);
    }

    final relatedBookIds = notesByBookId.keys.toList(growable: false);
    final relatedBooks = await booksDao.selectBooksByIds(relatedBookIds);
    final relatedBookMap = {
      for (final book in relatedBooks) book.id: book,
    };

    final seenBookIds = <int>{};
    final noteGroups = <SearchNoteGroup>[];
    for (final note in notes) {
      final bookId = note.bookId;
      if (!seenBookIds.add(bookId)) {
        continue;
      }

      final book = relatedBookMap[bookId];
      if (book == null) {
        continue;
      }

      final groupNotes = List<BookNote>.from(notesByBookId[bookId] ?? const []);
      noteGroups.add(
        SearchNoteGroup(
          book: book,
          notes: groupNotes,
        ),
      );
    }

    return SearchResultData(
      books: books,
      noteGroups: noteGroups,
      journalResults: journalResults,
    );
  }
}
