import 'package:flutter_riverpod/misc.dart' show Override;
// The OPDS browse screen.
//
// The load-bearing behaviour is that every failure reaches the reader as the
// failure it was. A catalog that answers 401 and a catalog that is down look
// identical if the screen says "could not load", and only one of the two is
// something the reader can fix.
//
//   flutter test test/widgets/opds_browse_test.dart

import 'package:material_ui/material_ui.dart';
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

Widget _host(List<Override> overrides, {double textScale = 1}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
      supportedLocales: L10n.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: OpdsBrowsePage(catalog: _catalog),
    ),
  );
}

Override _feedOverride(Object Function() result) {
  return opdsFeedProvider
      .overrideWith((Ref ref, OpdsFeedRequest request) async {
    final Object value = result();
    if (value is OpdsFeed) {
      return value;
    }
    throw value;
  });
}

void main() {
  OpdsFeed bookWithLinks(List<OpdsLink> links) => OpdsFeed(
        title: 'Shelf',
        publications: [
          OpdsEntry(title: 'A book with several choices', links: links)
        ],
        navigation: const [],
        facetGroups: const [],
      );

  testWidgets('format selection excludes purchase and unsupported links',
      (tester) async {
    final feed = bookWithLinks([
      OpdsLink(
          rels: ['${OpdsRel.acquisition}/buy'],
          href: Uri.parse('https://books.example/buy'),
          type: 'application/epub+zip'),
      OpdsLink(
          rels: [OpdsRel.acquisition],
          href: Uri.parse('https://books.example/download?format=epub'),
          type: 'application/epub+zip'),
      OpdsLink(
          rels: [OpdsRel.acquisition],
          href: Uri.parse('https://books.example/download?format=pdf'),
          type: 'application/pdf'),
      OpdsLink(
          rels: [OpdsRel.acquisition],
          href: Uri.parse('https://books.example/download?format=zip'),
          type: 'application/zip'),
    ]);
    await tester.pumpWidget(_host([_feedOverride(() => feed)]));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a format'), findsOneWidget);
    expect(find.text('EPUB'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('ZIP'), findsNothing);
    Navigator.of(tester.element(find.text('Choose a format'))).pop();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Download'), findsOneWidget);
  });

  testWidgets(
      'web purchase and borrowing options never display a download action',
      (tester) async {
    for (final relation in ['buy', 'borrow']) {
      final feed = bookWithLinks([
        OpdsLink(
            rels: ['${OpdsRel.acquisition}/$relation'],
            href: Uri.parse('https://books.example/$relation'),
            type: 'text/html'),
      ]);
      await tester.pumpWidget(_host([_feedOverride(() => feed)]));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Open website'), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('format selection and retry fit narrow screens with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final feed = bookWithLinks([
      for (final (format, type) in [
        ('epub', 'application/epub+zip'),
        ('pdf', 'application/pdf')
      ])
        OpdsLink(
            rels: [OpdsRel.acquisition],
            href: Uri.parse('https://books.example/book.$format'),
            type: type),
    ]);
    await tester.pumpWidget(_host([_feedOverride(() => feed)], textScale: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Download'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('PDF').hitTestable(), 150,
        scrollable: find.descendant(
            of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
    expect(find.text('PDF').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host([
      _feedOverride(() => const OpdsException(OpdsFailure.network)),
    ], textScale: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('The catalog could not be reached.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
