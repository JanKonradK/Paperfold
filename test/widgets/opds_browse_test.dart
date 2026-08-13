// The OPDS browse screen.
//
// The load-bearing behaviour is that every failure reaches the reader as the
// failure it was. A catalog that answers 401 and a catalog that is down look
// identical if the screen says "could not load", and only one of the two is
// something the reader can fix.
//
//   flutter test test/widgets/opds_browse_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/opds_catalog.dart';
import 'package:paperfold/page/opds/opds_browse_page.dart';
import 'package:paperfold/providers/opds.dart';
import 'package:paperfold/service/opds/opds.dart';
import 'package:paperfold/service/opds/opds_client.dart';

final OpdsCatalog _catalog = OpdsCatalog(
  id: 1,
  name: 'Standard Ebooks',
  url: Uri.parse('https://standardebooks.org/feeds/opds'),
);

const String _feed = '''
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"
      xmlns:thr="http://purl.org/syndication/thread/1.0">
  <title>Standard Ebooks</title>
  <link rel="next" href="?page=2" type="application/atom+xml;profile=opds-catalog"/>
  <entry>
    <title>Subjects</title>
    <link href="/feeds/opds/subjects"
          type="application/atom+xml;profile=opds-catalog" thr:count="42"/>
  </entry>
  <entry>
    <title>A Wizard of Earthsea</title>
    <author><name>Ursula K. Le Guin</name></author>
    <link rel="http://opds-spec.org/acquisition" href="/download/1.epub"
          type="application/epub+zip"/>
  </entry>
</feed>
''';

Widget _host(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
      ),
      home: OpdsBrowsePage(catalog: _catalog),
    ),
  );
}

Override _feedOverride(Object Function() result) {
  return opdsFeedProvider.overrideWith((Ref ref, OpdsFeedRequest request) async {
    final Object value = result();
    if (value is OpdsFeed) {
      return value;
    }
    throw value;
  });
}

void main() {
  testWidgets('a feed shows its shelves, its books and its next page',
      (WidgetTester tester) async {
    final OpdsFeed parsed = parseOpdsFeed(
      _feed,
      baseUri: _catalog.url,
      contentType: 'application/atom+xml;profile=opds-catalog',
    );

    await tester.pumpWidget(_host(<Override>[_feedOverride(() => parsed)]));
    await tester.pumpAndSettle();

    expect(find.text('Subjects'), findsOne);
    expect(find.text('A Wizard of Earthsea'), findsOne);
    expect(find.text('Ursula K. Le Guin'), findsOne);
    // A page, not an infinite scroll. A catalog can be very large.
    expect(find.text('More'), findsOne);
  });

  testWidgets('a book with no acquisition link cannot be downloaded',
      (WidgetTester tester) async {
    const OpdsFeed feed = OpdsFeed(
      title: 'Shelf',
      publications: <OpdsEntry>[
        OpdsEntry(title: 'A title only', links: <OpdsLink>[]),
      ],
      navigation: <OpdsLink>[],
      facetGroups: <OpdsFacetGroup>[],
    );

    await tester.pumpWidget(_host(<Override>[_feedOverride(() => feed)]));
    await tester.pumpAndSettle();

    final IconButton button = tester.widget(find.byType(IconButton));
    expect(button.onPressed, isNull);
  });

  group('a failure reaches the reader as the failure it was', () {
    for (final (OpdsFailure failure, String message) in <(OpdsFailure, String)>[
      (OpdsFailure.network, 'The catalog could not be reached.'),
      (OpdsFailure.unauthorized, 'The user name or the password is wrong.'),
      (OpdsFailure.notFound, 'The catalog has no feed at that address.'),
      (OpdsFailure.server, 'The catalog answered with an error.'),
      (
        OpdsFailure.notAFeed,
        'That address is a web page, not a catalog feed.',
      ),
    ]) {
      testWidgets(failure.name, (WidgetTester tester) async {
        await tester.pumpWidget(
          _host(<Override>[_feedOverride(() => OpdsException(failure))]),
        );
        await tester.pumpAndSettle();

        expect(find.text(message), findsOne);
      });
    }

    testWidgets('an unexpected error still says something true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(<Override>[_feedOverride(() => StateError('surprise'))]),
      );
      await tester.pumpAndSettle();

      expect(find.text('The catalog could not be reached.'), findsOne);
    });
  });

  testWidgets('an empty shelf says so rather than showing nothing',
      (WidgetTester tester) async {
    const OpdsFeed feed = OpdsFeed(
      title: 'Shelf',
      publications: <OpdsEntry>[],
      navigation: <OpdsLink>[],
      facetGroups: <OpdsFacetGroup>[],
    );

    await tester.pumpWidget(_host(<Override>[_feedOverride(() => feed)]));
    await tester.pumpAndSettle();

    expect(find.text('This shelf is empty.'), findsOne);
  });
}
