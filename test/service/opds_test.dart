// The OPDS feed parser, ported from assets/foliate-js/src/opds.js.
//
// plan.md Section 9.3 says feed variety is what makes OPDS take longer than it
// looks: Calibre-Web, Kavita, Komga, Standard Ebooks, Project Gutenberg and
// Feedbooks all differ in small ways. These fixtures carry those differences
// on purpose, so the parser meets them here and not on a real server.
//
//   flutter test test/service/opds_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/service/opds/opds.dart';
import 'package:xml/xml.dart';

final Uri _base = Uri.parse('https://books.example/opds/root.xml');

/// An acquisition feed with two books, a facet group and a next page.
const String _atomAcquisition = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"
      xmlns:opds="http://opds-spec.org/2010/catalog"
      xmlns:dcterms="http://purl.org/dc/terms/"
      xmlns:thr="http://purl.org/syndication/thread/1.0">
  <title>Recent additions</title>
  <link rel="self" href="root.xml" type="application/atom+xml;profile=opds-catalog"/>
  <link rel="next" href="?page=2" type="application/atom+xml;profile=opds-catalog"/>
  <link rel="search" href="/opds/search.xml" type="application/opensearchdescription+xml"/>
  <link rel="http://opds-spec.org/facet" href="?sort=title"
        opds:facetGroup="Sort by" title="Title"/>
  <link rel="http://opds-spec.org/facet" href="?sort=date"
        opds:facetGroup="Sort by" title="Date" opds:activeFacet="true"/>
  <entry>
    <title>A Wizard of Earthsea</title>
    <id>urn:uuid:1</id>
    <updated>2026-08-01T00:00:00Z</updated>
    <author><name>Ursula K. Le Guin</name></author>
    <summary>A boy learns his true name.</summary>
    <dcterms:language>en</dcterms:language>
    <dcterms:publisher>Parnassus</dcterms:publisher>
    <category term="fantasy" label="Fantasy"/>
    <link rel="http://opds-spec.org/image" href="/covers/1.jpg" type="image/jpeg"/>
    <link rel="http://opds-spec.org/image/thumbnail" href="/thumbs/1.jpg" type="image/jpeg"/>
    <link rel="http://opds-spec.org/acquisition" href="/download/1.epub"
          type="application/epub+zip"/>
  </entry>
  <entry>
    <title>The Tombs of Atuan</title>
    <id>urn:uuid:2</id>
    <author><name>Ursula K. Le Guin</name></author>
    <link rel="http://opds-spec.org/acquisition/buy" href="/buy/2"
          type="application/epub+zip">
      <opds:price currencycode="EUR">9.99</opds:price>
    </link>
  </entry>
  <entry>
    <title>Science fiction</title>
    <id>urn:uuid:shelf</id>
    <link href="/opds/scifi.xml" type="application/atom+xml;profile=opds-catalog"
          thr:count="42"/>
  </entry>
</feed>
''';

/// A navigation feed with no namespace prefix and no declared namespace, which
/// small self-hosted servers do produce.
const String _atomBareNavigation = '''
<?xml version="1.0" encoding="utf-8"?>
<feed>
  <title>Library</title>
  <entry>
    <title>By author</title>
    <link href="/opds/authors" type="application/atom+xml;profile=opds-catalog"/>
  </entry>
</feed>
''';

const String _opds2 = '''
{
  "metadata": { "title": "Standard Ebooks" },
  "links": [
    { "rel": "self", "href": "/opds/all", "type": "application/opds+json" },
    { "rel": "next", "href": "/opds/all?page=2", "type": "application/opds+json" },
    { "rel": "search", "href": "/opds/search", "type": "application/opds+json" }
  ],
  "navigation": [
    { "title": "Subjects", "href": "/opds/subjects", "type": "application/opds+json" }
  ],
  "groups": [
    {
      "metadata": { "title": "New" },
      "navigation": [
        { "title": "This month", "href": "/opds/new", "type": "application/opds+json" }
      ]
    }
  ],
  "publications": [
    {
      "metadata": {
        "title": "The Farthest Shore",
        "author": { "name": "Ursula K. Le Guin" },
        "language": ["en"],
        "identifier": "urn:uuid:3",
        "description": "The magic is draining away."
      },
      "images": [ { "href": "/covers/3.jpg", "type": "image/jpeg" } ],
      "links": [
        {
          "rel": "http://opds-spec.org/acquisition/open-access",
          "href": "/download/3.epub",
          "type": "application/epub+zip"
        }
      ]
    }
  ]
}
''';

void main() {
  group('media types', () {
    test('an OPDS catalog is recognised in both generations', () {
      expect(isOpdsCatalog('application/opds+json'), isTrue);
      expect(
        isOpdsCatalog('application/atom+xml;profile=opds-catalog'),
        isTrue,
      );
      expect(
        isOpdsCatalog('application/atom+xml; profile="opds-catalog"; kind=acquisition'),
        isTrue,
        reason: 'servers quote and space their parameters differently',
      );
    });

    test('a plain Atom feed is not a catalog', () {
      expect(isOpdsCatalog('application/atom+xml'), isFalse);
      expect(isOpdsCatalog('text/html'), isFalse);
      expect(isOpdsCatalog(null), isFalse);
      expect(isOpdsCatalog(''), isFalse);
    });
  });

  group('OPDS 1.2, Atom', () {
    late OpdsFeed feed;

    setUp(() {
      feed = parseOpdsFeed(
        _atomAcquisition,
        baseUri: _base,
        contentType: 'application/atom+xml;profile=opds-catalog',
      );
    });

    test('books and shelves are told apart by their links', () {
      expect(feed.title, 'Recent additions');
      expect(
        feed.publications.map((OpdsEntry entry) => entry.title),
        <String>['A Wizard of Earthsea', 'The Tombs of Atuan'],
      );
      // An entry with no acquisition link leads to another feed.
      expect(feed.navigation.single.title, 'Science fiction');
      expect(feed.navigation.single.numberOfItems, 42);
    });

    test('a relative link is resolved against the feed it came from', () {
      expect(
        feed.publications.first.acquisitionLinks.single.href,
        Uri.parse('https://books.example/download/1.epub'),
      );
      // A query-only reference keeps the path it was found on, per RFC 3986.
      expect(
        feed.nextHref,
        Uri.parse('https://books.example/opds/root.xml?page=2'),
      );
    });

    test('metadata comes off the entry', () {
      final OpdsEntry entry = feed.publications.first;

      expect(entry.authors, <String>['Ursula K. Le Guin']);
      expect(entry.summary, 'A boy learns his true name.');
      expect(entry.identifier, 'urn:uuid:1');
      expect(entry.language, 'en');
      expect(entry.publisher, 'Parnassus');
      expect(entry.subjects, <String>['Fantasy']);
      expect(entry.coverHref, Uri.parse('https://books.example/covers/1.jpg'));
      expect(
        entry.thumbnailHref,
        Uri.parse('https://books.example/thumbs/1.jpg'),
      );
    });

    test('a paid link keeps its price', () {
      final OpdsLink buy = feed.publications[1].acquisitionLinks.single;

      expect(buy.price?.currency, 'EUR');
      expect(buy.price?.value, '9.99');
    });

    test('facets group, and the active one is marked', () {
      final OpdsFacetGroup group = feed.facetGroups.single;

      expect(group.title, 'Sort by');
      expect(group.links.length, 2);
      expect(group.links.first.isActiveFacet, isFalse);
      // opds:activeFacet is an attribute, not a rel. The port folds it in.
      expect(group.links.last.isActiveFacet, isTrue);
    });

    test('the search link is found', () {
      expect(
        feed.searchLink?.href,
        Uri.parse('https://books.example/opds/search.xml'),
      );
    });

    test('a feed that declares no namespace still parses', () {
      final OpdsFeed bare =
          parseOpdsFeed(_atomBareNavigation, baseUri: _base);

      expect(bare.title, 'Library');
      expect(bare.navigation.single.title, 'By author');
      expect(bare.publications, isEmpty);
    });
  });

  group('OPDS 2.0, JSON', () {
    late OpdsFeed feed;

    setUp(() {
      feed = parseOpdsFeed(
        _opds2,
        baseUri: _base,
        contentType: 'application/opds+json',
      );
    });

    test('publications carry their metadata', () {
      final OpdsEntry entry = feed.publications.single;

      expect(feed.title, 'Standard Ebooks');
      expect(entry.title, 'The Farthest Shore');
      expect(entry.authors, <String>['Ursula K. Le Guin']);
      expect(entry.language, 'en');
      expect(entry.summary, 'The magic is draining away.');
    });

    test('an image array reads back as a cover', () {
      // OPDS 2.0 keeps images in their own array. Tagging them with the 1.2
      // rel gives a browse screen one cover lookup for both generations.
      expect(
        feed.publications.single.coverHref,
        Uri.parse('https://books.example/covers/3.jpg'),
      );
    });

    test('groups fold into the navigation', () {
      expect(
        feed.navigation.map((OpdsLink link) => link.title),
        <String>['Subjects', 'This month'],
      );
    });

    test('pagination and search are found', () {
      expect(
        feed.nextHref,
        Uri.parse('https://books.example/opds/all?page=2'),
      );
      expect(
        feed.searchLink?.href,
        Uri.parse('https://books.example/opds/search'),
      );
    });
  });

  group('a server that says nothing useful', () {
    test('a JSON body is read as OPDS 2.0 with no content type', () {
      final OpdsFeed feed = parseOpdsFeed(_opds2, baseUri: _base);
      expect(feed.publications.single.title, 'The Farthest Shore');
    });

    test('an XML body is read as Atom with no content type', () {
      final OpdsFeed feed = parseOpdsFeed(_atomAcquisition, baseUri: _base);
      expect(feed.publications.length, 2);
    });

    test('a body that is neither fails loudly', () {
      expect(
        () => parseOpdsFeed('not a feed', baseUri: _base),
        throwsA(isA<XmlException>()),
      );
    });
  });
}
