import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/page/opds/book_web_page.dart';
import 'package:paperfold/service/open_library.dart';

void main() {
  test('Open Library search keeps usable matches', () {
    final matches = parseOpenLibrarySearch({
      'docs': [
        {
          'key': '/works/OL66554W',
          'title': 'Pride and Prejudice',
          'author_name': ['Jane Austen'],
          'first_publish_year': 1813,
          'cover_i': 14348537,
        },
        {'key': '/works/OL1W', 'title': 'No author or cover'},
        {'title': 'No key'},
      ],
    });
    expect(matches, hasLength(2));
    expect(matches.first, (
      key: '/works/OL66554W',
      title: 'Pride and Prejudice',
      author: 'Jane Austen',
      year: 1813,
      coverId: 14348537,
    ));
    expect(matches.last.author, isEmpty);
    expect(matches.last.coverId, isNull);
  });

  test('Open Library descriptions drop appended source lists', () {
    expect(
      parseOpenLibraryDescription({
        'type': '/type/text',
        'value': 'A novel.\r\n\r\n----------\r\nAlso in: [Collected](x)',
      }),
      'A novel.',
    );
    expect(parseOpenLibraryDescription('Plain.'), 'Plain.');
    expect(parseOpenLibraryDescription(null), isNull);
  });

  test('downloads are recognised by type, link, or file name', () {
    final url = Uri.parse('https://example.org/download/42');
    expect(bookExtension(url, mimeType: 'application/epub+zip'), 'epub');
    expect(
      bookExtension(
        Uri.parse('https://example.org/b.pdf'),
        mimeType: 'application/octet-stream',
      ),
      'pdf',
    );
    expect(
      bookExtension(
        url,
        mimeType: 'application/octet-stream',
        fileName: 'Moby Dick.EPUB',
      ),
      'epub',
    );
    expect(
      bookExtension(url, mimeType: 'application/zip', fileName: 'a.zip'),
      isNull,
    );
    expect(bookExtension(url, mimeType: 'text/html'), isNull);
  });

  test('a typed link assumes https and refuses credentials', () {
    expect(
      parseBookLink(' standardebooks.org/ebooks '),
      Uri.parse('https://standardebooks.org/ebooks'),
    );
    expect(
      parseBookLink('http://example.org/a.epub'),
      Uri.parse('http://example.org/a.epub'),
    );
    expect(parseBookLink('https://user:pw@example.org/'), isNull);
    expect(parseBookLink('ftp://example.org/a.epub'), isNull);
    expect(parseBookLink(''), isNull);
  });
}
