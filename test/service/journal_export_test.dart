import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/l10n/generated/L10n_en.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/book_review.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/service/journal/export_journal.dart';
import 'package:paperfold/utils/convert_string_to_uint8list.dart';

void main() {
  final l10n = L10nEn();
  final book = Book.mock().copyWith(title: '夜の本 📖', author: 'Zoë');

  test('exports every populated review field and rating as UTF-8', () {
    const review = BookReview(
      bookId: 1,
      genre: '幻想',
      format: 'EPUB',
      ratingOverall: 5,
      ratingPlot: 4,
      ratingEnding: 3,
      ratingWorld: 2,
      ratingCharacters: 1,
      ratingSpice: 4,
      favoriteCharacter: 'Éowyn',
      favoriteQuote: '第一行\nδεύτερη γραμμή',
      thoughts: 'مرحبا\n\nRemember this 🌙',
    );
    final markdown = journalToMarkdown(book, review, [], l10n);
    final saved = utf8.decode(convertStringToUint8List(markdown));

    expect(saved, startsWith('# 夜の本 📖\n\n**Author:** Zoë\n'));
    for (final rating in [
      'Overall:** 5/5',
      'Plot:** 4/5',
      'Ending:** 3/5',
      'World:** 2/5',
      'Characters:** 1/5',
      'Spice:** 4/5',
    ]) {
      expect(saved, contains(rating));
    }
    expect(saved, contains('### Genre\n\n幻想'));
    expect(saved, contains('### Format\n\nEPUB'));
    expect(saved, contains('### Favourite character\n\nÉowyn'));
    expect(saved, contains('### Favourite quote\n\n第一行  \nδεύτερη γραμμή'));
    expect(saved, contains('### Thoughts\n\nمرحبا  \n  \nRemember this 🌙'));
  });

  test('keeps page order and passage provenance without changing input', () {
    final pages = [
      const JournalPage(bookId: 1, pageIndex: 3, body: 'Last page'),
      const JournalPage(bookId: 1, pageIndex: 1),
      const JournalPage(
        bookId: 1,
        pageIndex: 0,
        body: 'A thought\r\nAnother line',
        sourceExcerpt: 'A passage\nIts second line',
        sourceChapter: 'Winter',
        sourceCfi: 'epubcfi(/6/2[chapter]!/4/2/1:0)',
      ),
      const JournalPage(
        bookId: 1,
        pageIndex: 2,
        sourceExcerpt: 'A passage with no reflection yet',
      ),
    ];
    final markdown = journalToMarkdown(book, null, pages, l10n);

    expect(markdown, isNot(contains('## Review')));
    expect(markdown, isNot(contains('### Dot page 2')));
    expect(markdown.indexOf('### Dot page 1'),
        lessThan(markdown.indexOf('### Dot page 3')));
    expect(markdown.indexOf('### Dot page 3'),
        lessThan(markdown.indexOf('### Dot page 4')));
    expect(markdown, contains('**Chapter Title:** Winter'));
    expect(markdown, contains('> A passage  \n> Its second line'));
    expect(markdown, contains(r'CFI: epubcfi\(/6/2\[chapter\]\!/4/2/1:0\)'));
    expect(markdown, contains('A thought  \nAnother line'));
    expect(markdown, contains('A passage with no reflection yet'));
    expect(pages.first.pageIndex, 3);
  });

  test('metadata and plain writing cannot alter Markdown structure', () {
    final markdown = journalToMarkdown(
      book.copyWith(
        title: '# First\n[second](https://example.com) <b>',
        author: '*Writer*\r\n<script> & Co',
      ),
      const BookReview(bookId: 1, thoughts: '# Heading\n```\n*literal*'),
      [],
      l10n,
    );

    expect(markdown,
        startsWith(r'# \# First \[second\]\(https://example\.com\) &lt;b&gt;'));
    expect(
        markdown, contains(r'**Author:** \*Writer\* &lt;script&gt; &amp; Co'));
    expect(markdown, contains('\\# Heading  \n\\`\\`\\`  \n\\*literal\\*'));
    expect(markdown, isNot(contains('<script>')));
    expect(markdown, isNot(contains('### Genre')));
    expect(markdown, isNot(contains('Overall:** 0/5')));
  });

  test('an empty journal does not open the save picker', () async {
    const review = BookReview(bookId: 1, thoughts: ' \n ');
    const pages = [JournalPage(bookId: 1, pageIndex: 0, body: ' \n ')];

    expect(journalToMarkdown(book, review, pages, l10n), isEmpty);
    expect(await exportJournal(book, review, pages, l10n), isNull);
  });
}
