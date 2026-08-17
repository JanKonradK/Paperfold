import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/service/book_binding.dart';

void main() {
  BookBindingVerdict resolve({
    String title = 'A Book',
    String author = 'Somebody',
    String? description,
    List<String> tags = const [],
    BookBindingChoice choice = BookBindingChoice.automatic,
    BookBinding fallback = BookBinding.hardback,
  }) {
    return BookBindingResolver.resolve(
      title: title,
      author: author,
      description: description,
      tags: tags,
      choice: choice,
      fallback: fallback,
      currentYear: 2026,
    );
  }

  group('the reader always wins', () {
    test('an explicit choice beats every signal in the metadata', () {
      final verdict = resolve(
        title: 'Chainsaw Man, Vol. 1',
        description: 'A shonen manga first published in 2018.',
        choice: BookBindingChoice.hardback,
      );

      expect(verdict.binding, BookBinding.hardback);
      expect(verdict.reason, BookBindingReason.reader);
      expect(verdict.isAutomatic, isFalse);
    });

    test('automatic leaves the choice to the metadata', () {
      expect(BookBindingChoice.automatic.forced, isNull);
      expect(BookBindingChoice.hardback.forced, BookBinding.hardback);
      expect(BookBindingChoice.softback.forced, BookBinding.softback);
    });
  });

  group('what the metadata says', () {
    test('a stated format outranks the date', () {
      final hard = resolve(
        title: 'Dracula',
        description: 'Hardcover reissue of the 1897 novel.',
      );
      final soft = resolve(
        title: 'Middlemarch',
        description: 'A mass market paperback of the 1871 novel.',
      );

      expect(hard.binding, BookBinding.hardback);
      expect(hard.reason, BookBindingReason.statedFormat);
      expect(soft.binding, BookBinding.softback);
      expect(soft.reason, BookBindingReason.statedFormat);
      expect(soft.evidence, 'paperback');
    });

    test('manga and light novels are softbacks whatever their date', () {
      for (final description in [
        'A shonen manga about a boy and a demon.',
        'The first light novel in the series.',
        'Volume 3 of the seinen series.',
        'ライトノベル、第一巻',
        'A webtoon collected in print.',
      ]) {
        final verdict = resolve(description: description);
        expect(
          verdict.binding,
          BookBinding.softback,
          reason: description,
        );
        expect(verdict.reason, BookBindingReason.comicOrLightNovel);
      }
    });

    test('a tag counts as much as a description', () {
      final verdict = resolve(tags: ['Fantasy', 'Manga']);

      expect(verdict.binding, BookBinding.softback);
      expect(verdict.evidence, 'manga');
    });

    test('a public-domain transcription is an old book', () {
      // These files carry two dates, the work's and the transcription's, and
      // the transcription's is always modern. The date is the wrong signal
      // here and the imprint is the right one.
      final verdict = resolve(
        title: 'Moby Dick',
        description: 'The Project Gutenberg eBook, produced in 2021.',
      );

      expect(verdict.binding, BookBinding.hardback);
      expect(verdict.reason, BookBindingReason.publicDomain);
    });

    test('the paperback era splits old from modern', () {
      final old = resolve(description: 'First published in 1922.');
      final modern = resolve(description: 'First published in 1997.');

      expect(old.binding, BookBinding.hardback);
      expect(old.reason, BookBindingReason.earlyPublication);
      expect(old.evidence, '1922');
      expect(modern.binding, BookBinding.softback);
      expect(modern.reason, BookBindingReason.modernPublication);
      expect(BookBindingResolver.paperbackEra, 1960);
    });

    test('the earliest plausible year is the one that counts', () {
      // A description that names two years usually names the work's first
      // publication and this edition's. The first is the one that says how the
      // book was bound.
      expect(
        BookBindingResolver.firstPublicationYear(
          'First published 1908. This edition 2014.',
          currentYear: 2026,
        ),
        1908,
      );
      // A page count, a print run and a year in the future are not dates.
      expect(
        BookBindingResolver.firstPublicationYear(
          '1200 copies, 0450 pages, 2199',
          currentYear: 2026,
        ),
        isNull,
      );
      expect(
        BookBindingResolver.firstPublicationYear('no dates here'),
        isNull,
      );
    });

    test('nothing to go on falls back to the library default', () {
      final byDefault = resolve(title: 'Untitled', author: '');
      final otherDefault = resolve(
        title: 'Untitled',
        author: '',
        fallback: BookBinding.softback,
      );

      expect(byDefault.binding, BookBinding.hardback);
      expect(byDefault.reason, BookBindingReason.libraryDefault);
      expect(byDefault.evidence, isNull);
      expect(otherDefault.binding, BookBinding.softback);
    });
  });

  test('the same book always gets the same binding', () {
    final first = resolve(title: 'Ulysses', description: 'Published 1922.');
    final second = resolve(title: 'Ulysses', description: 'Published 1922.');

    expect(first, second);
    expect(first.hashCode, second.hashCode);
  });

  test('stored codes are stable', () {
    for (final binding in BookBinding.values) {
      expect(BookBinding.fromCode(binding.code), binding);
    }
    for (final choice in BookBindingChoice.values) {
      expect(BookBindingChoice.fromCode(choice.code), choice);
    }
    expect(BookBinding.fromCode('nonsense'), BookBinding.hardback);
    expect(BookBindingChoice.fromCode(null), BookBindingChoice.automatic);
  });
}
