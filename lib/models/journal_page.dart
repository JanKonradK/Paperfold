/// One dot page of free journal space, belonging to a book.
///
/// Pages are ordered by [pageIndex] within a book, so a reader can keep
/// writing past the end of one page without the order depending on when each
/// row happened to be saved.
class JournalPage {
  const JournalPage({
    this.id,
    required this.bookId,
    required this.pageIndex,
    this.body = '',
    this.updateTime,
  });

  /// Null until the row has been written.
  final int? id;
  final int bookId;
  final int pageIndex;
  final String body;
  final DateTime? updateTime;

  bool get isEmpty => body.trim().isEmpty;

  factory JournalPage.fromDb(Map<String, dynamic> row) {
    final updated = row['update_time'] as String?;
    return JournalPage(
      id: row['id'] as int?,
      bookId: row['book_id'] as int? ?? 0,
      pageIndex: row['page_index'] as int? ?? 0,
      body: row['body'] as String? ?? '',
      // A row written by an older build may hold something unparseable. A
      // missing date loses a sort key; throwing would lose the writing.
      updateTime: updated == null ? null : DateTime.tryParse(updated),
    );
  }

  Map<String, Object?> toDb() {
    return {
      'book_id': bookId,
      'page_index': pageIndex,
      'body': body,
    };
  }

  JournalPage copyWith({int? id, int? pageIndex, String? body}) {
    return JournalPage(
      id: id ?? this.id,
      bookId: bookId,
      pageIndex: pageIndex ?? this.pageIndex,
      body: body ?? this.body,
      updateTime: updateTime,
    );
  }
}
