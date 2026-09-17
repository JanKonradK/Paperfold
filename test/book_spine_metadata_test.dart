import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/service/book_spine_metadata.dart';

List<int> epub(
    {String metadata = '', String nav = '', String ncx = '', int words = 0}) {
  final files = {
    'META-INF/container.xml':
        '<container><rootfiles><rootfile full-path="EPUB/book.opf"/></rootfiles></container>',
    'EPUB/book.opf': '''<package><metadata>$metadata</metadata><manifest>
      <item id="text" href="chapter.xhtml"/>
      <item id="nav" href="nav.xhtml" properties="nav"/>
      <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
      </manifest><spine><itemref idref="text"/></spine></package>''',
    'EPUB/chapter.xhtml':
        '<html><head><title>Ignored</title></head><body>${List.filled(words, 'word').join(' ')}</body></html>',
    'EPUB/nav.xhtml':
        '<html xmlns:epub="http://www.idpf.org/2007/ops"><body>$nav</body></html>',
    'EPUB/toc.ncx': '<ncx>$ncx</ncx>',
  };
  final archive = Archive();
  for (final entry in files.entries) {
    final bytes = utf8.encode(entry.value);
    archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
  }
  return ZipEncoder().encode(archive)!;
}

void main() {
  test('EPUB 3 series and print page labels override a text estimate', () {
    final value = readEpubSpineMetadata(epub(
        metadata: '''
      <meta property="belongs-to-collection" id="s">A Series</meta>
      <meta property="collection-type" refines="#s">series</meta>
      <meta property="group-position" refines="#s">2</meta>''',
        nav: '<nav epub:type="page-list"><a>1</a><a>278</a></nav>',
        words: 1000));
    expect(
        value, (series: 'A Series', volume: '2', pages: 278, estimated: false));
  });

  test('Calibre series and NCX print pages work for EPUB 2', () {
    final value = readEpubSpineMetadata(epub(
        metadata: '''
      <meta name="calibre:series" content="A Series"/>
      <meta name="calibre:series_index" content="3.0"/>''',
        ncx:
            '<pageList><pageTarget value="1"/><pageTarget value="302"/></pageList>'));
    expect(
        value, (series: 'A Series', volume: '3', pages: 302, estimated: false));
  });

  test('missing page lists use text length; empty books keep unknown length',
      () {
    expect(readEpubSpineMetadata(epub(words: 751)).pages, 4);
    expect(readEpubSpineMetadata(epub(words: 751)).estimated, isTrue);
    expect(readEpubSpineMetadata(epub()).pages, isNull);
    expect(readEpubSpineMetadata(epub()).estimated, isFalse);
  });

  test('only a known series, matching author and volume links an older title',
      () {
    Book book(String title, String author) => Book.mock()
      ..title = title
      ..author = author;
    final known = book('Rascal Does Not Dream of Santa Claus, Vol. 13',
        'Hajime Kamoshida, Keji Mizoguchi')
      ..series = 'Rascal Does Not Dream';
    final old = book('Rascal Does Not Dream of Bunny Girl Senpai, Vol. 1',
        'Hajime Kamoshida and Keji Mizoguchi');
    final unrelated = book(old.title, 'Another Writer');
    final standalone = book('Rascal Does Not Dream again', known.author);
    matchKnownBookSeries([known, old, unrelated, standalone]);
    expect(old.series, known.series);
    expect(old.volume, '1');
    expect(unrelated.series, isNot(known.series));
    expect(standalone.series, isNull);
    expect(old.copyWith(title: 'New title').series, known.series);
    expect(old.toMap().containsKey('series'), isFalse);
  });

  test('untyped EPUB collections work, explicit sets are not a series', () {
    const collection =
        '<meta property="belongs-to-collection" id="s">Series</meta>'
        '<meta property="group-position" refines="#s">2.0</meta>';
    final value = readEpubSpineMetadata(epub(metadata: collection));
    expect(value.series, 'Series');
    expect(value.volume, '2');
    expect(
        readEpubSpineMetadata(epub(
                metadata: '$collection'
                    '<meta property="collection-type" refines="#s">set</meta>'))
            .series,
        isNull);
  });
}
