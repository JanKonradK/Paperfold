import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/opds_catalog.dart';
import 'package:paperfold/page/opds/opds_catalogs_page.dart';
import 'package:paperfold/providers/opds.dart';
import 'package:paperfold/service/opds/opds.dart';

class _Catalogs extends OpdsCatalogsController {
  _Catalogs([this.rows = const []]);
  List<OpdsCatalog> rows;
  bool failSave = false;
  int saveCalls = 0;

  @override
  Future<List<OpdsCatalog>> build() async => rows;

  @override
  Future<int> add(
      {required String name,
      required Uri url,
      OpdsAuthType authType = OpdsAuthType.none,
      String? username,
      String? password}) async {
    saveCalls++;
    if (failSave) throw StateError('Storage unavailable');
    rows = [
      ...rows,
      OpdsCatalog(
          id: 10, name: name, url: url, authType: authType, username: username)
    ];
    state = AsyncData(rows);
    return 10;
  }
}

Widget _host(_Catalogs catalogs, {double textScale = 1}) => ProviderScope(
      overrides: [
        opdsCatalogsProvider.overrideWith(() => catalogs),
        opdsFeedProvider.overrideWith((ref, request) async => OpdsFeed(
              title: request.catalog.name,
              publications: const [],
              navigation: const [],
              facetGroups: const [],
            )),
      ],
      child: MaterialApp(
        localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: L10n.supportedLocales,
        theme: ThemeData(
            useMaterial3: true,
            colorScheme: PaperfoldTokens.colorScheme(Brightness.light)),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const OpdsCatalogsPage(),
      ),
    );

void main() {
  testWidgets('download catalogs and external services have distinct groups',
      (tester) async {
    await tester.pumpWidget(_host(_Catalogs()));
    await tester.pumpAndSettle();
    expect(find.text('Read in Paperfold'), findsOneWidget);
    expect(find.text('Project Gutenberg'), findsOneWidget);
    expect(find.text('Ebooks libres et gratuits'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Libby'), 300);
    expect(find.text('Libby'), findsOneWidget);
    expect(find.text('Global Grey'), findsOneWidget);
    expect(find.text('Open Library'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsWidgets);
    await tester.scrollUntilVisible(find.text('Explore on the web'), -250);
    expect(find.text('Explore on the web'), findsOneWidget);
  });

  testWidgets('custom catalogs are kept and legacy Gutenberg is not repeated',
      (tester) async {
    final catalogs = _Catalogs([
      OpdsCatalog(
          id: 1,
          name: 'Project Gutenberg',
          url: Uri.parse('https://m.gutenberg.org/ebooks.opds/')),
      OpdsCatalog(
          id: 2,
          name: 'My private books',
          url: Uri.parse('https://home.example/opds')),
    ]);
    await tester.pumpWidget(_host(catalogs));
    await tester.pumpAndSettle();
    expect(find.text('Project Gutenberg'), findsOneWidget);
    expect(find.text('Your catalogs'), findsOneWidget);
    expect(find.text('My private books'), findsOneWidget);
    await tester.tap(find.text('My private books'));
    await tester.pumpAndSettle();
    expect(find.text('This shelf is empty.'), findsOneWidget);
    expect(catalogs.rows, hasLength(2));
  });

  testWidgets('a failed save keeps the complete draft for retry',
      (tester) async {
    final catalogs = _Catalogs()..failSave = true;
    await tester.pumpWidget(_host(catalogs));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add a catalog'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'My books');
    await tester.enterText(fields.at(1), 'https://home.example/opds');
    await tester.enterText(fields.at(2), 'reader');
    await tester.enterText(fields.at(3), 'secret');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'The catalog could not be saved. Your entries are kept; try again.'),
        findsOneWidget);
    for (final (index, text) in [
      (0, 'My books'),
      (1, 'https://home.example/opds'),
      (2, 'reader'),
      (3, 'secret')
    ]) {
      expect(tester.widget<TextFormField>(fields.at(index)).controller!.text,
          text);
    }
    catalogs.failSave = false;
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(catalogs.saveCalls, 2);
    expect(catalogs.rows.single.name, 'My books');
  });

  testWidgets('credential URLs are rejected by the catalog form',
      (tester) async {
    final catalogs = _Catalogs();
    await tester.pumpWidget(_host(catalogs));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add a catalog'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'My books');
    await tester.enterText(find.byType(TextFormField).at(1),
        'https://reader:secret@home.example/opds');
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Do not include a user name or password'),
        findsOneWidget);
    expect(catalogs.saveCalls, 0);
  });

  testWidgets('discovery and add form fit a narrow screen at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_host(_Catalogs(), textScale: 2));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Libby').hitTestable(), 300);
    expect(find.text('Libby').hitTestable(), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Add a catalog').hitTestable(), -250);
    await tester.tap(find.text('Add a catalog').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
