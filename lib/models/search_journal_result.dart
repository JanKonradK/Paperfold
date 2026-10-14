import 'package:paperfold/models/book.dart';

enum SearchJournalKind { review, page }

/// One saved piece of journal writing, with its destination.
class SearchJournalResult {
  const SearchJournalResult({
    required this.book,
    required this.id,
    required this.kind,
    required this.text,
    this.pageIndex,
  });

  final Book book;
  final int id;
  final SearchJournalKind kind;
  final String text;
  final int? pageIndex;
}
