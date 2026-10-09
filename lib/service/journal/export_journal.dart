import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/book_review.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/utils/convert_string_to_uint8list.dart';
import 'package:paperfold/utils/save_file_to_download.dart';

/// An empty journal returns an empty document, without opening a save dialog.
String journalToMarkdown(
  Book book,
  BookReview? review,
  List<JournalPage> pages,
  L10n l10n,
) {
  final writtenPages = pages.where((page) => !page.isEmpty).toList()
    ..sort((a, b) {
      final order = a.pageIndex.compareTo(b.pageIndex);
      return order != 0 ? order : (a.id ?? 0).compareTo(b.id ?? 0);
    });
  final hasReview = review != null && !review.isEmpty;
  if (!hasReview && writtenPages.isEmpty) return '';

  final buffer = StringBuffer()
    ..writeln(
        '# ${_heading(book.title.isEmpty ? l10n.navJournal : book.title)}')
    ..writeln();
  if (book.author.trim().isNotEmpty) {
    buffer
      ..writeln(
          '**${_heading(l10n.bookshelfAuthor)}:** ${_heading(book.author)}')
      ..writeln();
  }

  if (hasReview) {
    buffer
      ..writeln('## ${_heading(l10n.searchJournalReview)}')
      ..writeln();
    for (final (label, rating) in [
      (l10n.reviewRatingOverall, review.ratingOverall),
      (l10n.reviewRatingPlot, review.ratingPlot),
      (l10n.reviewRatingEnding, review.ratingEnding),
      (l10n.reviewRatingWorld, review.ratingWorld),
      (l10n.reviewRatingCharacters, review.ratingCharacters),
      (l10n.reviewRatingSpice, review.ratingSpice),
    ]) {
      if (rating > 0) buffer.writeln('- **${_heading(label)}:** $rating/5');
    }
    buffer.writeln();
    for (final (label, value) in [
      (l10n.reviewGenre, review.genre),
      (l10n.reviewFormat, review.format),
      (l10n.reviewFavoriteCharacter, review.favoriteCharacter),
      (l10n.reviewFavoriteQuote, review.favoriteQuote),
      (l10n.reviewThoughts, review.thoughts),
    ]) {
      if (value.trim().isEmpty) continue;
      buffer
        ..writeln('### ${_heading(label)}')
        ..writeln()
        ..writeln(_prose(value))
        ..writeln();
    }
  }

  if (writtenPages.isNotEmpty) {
    buffer
      ..writeln('## ${_heading(l10n.journalDotPages)}')
      ..writeln();
    for (final page in writtenPages) {
      buffer
        ..writeln('### ${_heading(l10n.searchJournalPage(page.pageIndex + 1))}')
        ..writeln();
      if (page.sourceChapter?.trim().isNotEmpty ?? false) {
        buffer
          ..writeln('**${_heading(l10n.readingPageReadingInfoChapterTitle)}:** '
              '${_heading(page.sourceChapter!)}')
          ..writeln();
      }
      if (page.sourceExcerpt?.trim().isNotEmpty ?? false) {
        buffer
          ..writeln(_prose(page.sourceExcerpt!)
              .split('\n')
              .map((line) => '> $line')
              .join('\n'))
          ..writeln();
      }
      if (page.sourceCfi?.trim().isNotEmpty ?? false) {
        buffer
          ..writeln('CFI: ${_heading(page.sourceCfi!)}')
          ..writeln();
      }
      if (page.body.trim().isNotEmpty) {
        if (page.hasSource) {
          buffer
            ..writeln('#### ${_heading(l10n.reviewThoughts)}')
            ..writeln();
        }
        buffer
          ..writeln(_prose(page.body))
          ..writeln();
      }
    }
  }
  return buffer.toString();
}

/// Null means the reader cancelled the native picker, or there was no writing.
Future<String?> exportJournal(
  Book book,
  BookReview? review,
  List<JournalPage> pages,
  L10n l10n,
) async {
  final markdown = journalToMarkdown(book, review, pages, l10n);
  if (markdown.isEmpty) return null;
  return await saveFileToDownload(
    bytes: convertStringToUint8List(markdown),
    fileName:
        '${book.title.replaceAll(RegExp(r'\s+'), ' ').trim()} - journal.md',
    mimeType: 'text/markdown',
  );
}

// Editors hold plain text. Escaping keeps book metadata and writing from
// becoming headings, links, HTML, or code when the exported file is rendered.
String _markdownText(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAllMapped(
        RegExp(r'[\\`*_{}\[\]()#+.!|~-]'), (match) => '\\${match[0]}');

String _heading(String value) =>
    _markdownText(value.replaceAll(RegExp(r'\s+'), ' ').trim());

String _prose(String value) => _markdownText(
      value.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
    ).replaceAll('\n', '  \n');
