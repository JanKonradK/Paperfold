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
    this.sourceCfi,
    this.sourceExcerpt,
    this.sourceChapter,
    this.entryKind = 'note',
    this.sourceLocator,
    this.sourceProgress,
    this.sourcePage,
    this.sourceLabel,
    this.photoPath,
    this.updateTime,
  });

  /// Null until the row has been written.
  final int? id;
  final int bookId;
  final int pageIndex;
  final String body;
  // Keep a snapshot: editing or deleting a highlight must not break its page.
  final String? sourceCfi;
  final String? sourceExcerpt;
  final String? sourceChapter;
  final String entryKind;
  final String? sourceLocator;
  final double? sourceProgress;
  final int? sourcePage;
  final String? sourceLabel;
  final String? photoPath;
  final DateTime? updateTime;

  bool get hasSource =>
      sourcePage != null ||
      sourceLocator != null ||
      sourceProgress != null ||
      (sourceCfi?.trim().isNotEmpty ?? false) ||
      (sourceExcerpt?.trim().isNotEmpty ?? false);

  bool get isEmpty =>
      body.trim().isEmpty && !hasSource && (photoPath?.isEmpty ?? true);

  factory JournalPage.fromDb(Map<String, dynamic> row) {
    final updated = row['update_time'] as String?;
    return JournalPage(
      id: row['id'] as int?,
      bookId: row['book_id'] as int? ?? 0,
      pageIndex: row['page_index'] as int? ?? 0,
      body: row['body'] as String? ?? '',
      sourceCfi: row['source_cfi'] as String?,
      sourceExcerpt: row['source_excerpt'] as String?,
      sourceChapter: row['source_chapter'] as String?,
      entryKind: row['entry_kind'] as String? ?? 'note',
      sourceLocator: row['source_locator'] as String?,
      sourceProgress: (row['source_progress'] as num?)?.toDouble(),
      sourcePage: row['source_page'] as int?,
      sourceLabel: row['source_label'] as String?,
      photoPath: row['photo_path'] as String?,

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
      'entry_kind': entryKind,
      'source_locator': sourceLocator,
      'source_progress': sourceProgress,
      'source_page': sourcePage,
      'source_label': sourceLabel,
      'photo_path': photoPath,

      'source_cfi': sourceCfi,
      'source_excerpt': sourceExcerpt,
      'source_chapter': sourceChapter,
    };
  }

  JournalPage copyWith({
    int? id,
    int? pageIndex,
    String? body,
    String? sourceCfi,
    String? sourceExcerpt,
    String? sourceChapter,
    String? entryKind,
    String? sourceLocator,
    double? sourceProgress,
    int? sourcePage,
    String? sourceLabel,
    String? photoPath,
    bool clearSource = false,
  }) {
    return JournalPage(
      id: id ?? this.id,
      bookId: bookId,
      pageIndex: pageIndex ?? this.pageIndex,
      body: body ?? this.body,
      sourceCfi: clearSource ? null : sourceCfi ?? this.sourceCfi,
      sourceExcerpt: clearSource ? null : sourceExcerpt ?? this.sourceExcerpt,
      sourceChapter: clearSource ? null : sourceChapter ?? this.sourceChapter,
      entryKind: entryKind ?? this.entryKind,
      sourceLocator: clearSource ? null : sourceLocator ?? this.sourceLocator,
      sourceProgress: clearSource
          ? null
          : sourceProgress ?? this.sourceProgress,
      sourcePage: clearSource ? null : sourcePage ?? this.sourcePage,
      sourceLabel: clearSource ? null : sourceLabel ?? this.sourceLabel,
      photoPath: photoPath ?? this.photoPath,
      updateTime: updateTime,
    );
  }
}
