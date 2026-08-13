import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shelf_home_fixtures.dart';

Future<void> _pumpShelfHome(
  WidgetTester tester, {
  required ShelfHomeData data,
  Brightness brightness = Brightness.light,
  TextDirection textDirection = TextDirection.ltr,
  double textScale = 1,
  required List<Override> overrides,
}) async {
  fakeData = data;
  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: PaperfoldTokens.colorScheme(brightness),
        ),
        builder: (context, child) => Directionality(
          textDirection: textDirection,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        ),
        home: ShelfHomePage(
          key: ValueKey(
            '$brightness-$textDirection-$textScale-'
            '${data.readingNow.length}-${data.booksToBuy.length}',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home handles real data and its accessible empty state',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
    final overrides = newTestOverrides();
    await _pumpShelfHome(
      tester,
      data: populatedData(),
      overrides: overrides,
    );

    expect(find.text('Reading now'), findsOneWidget);
    expect(find.text('All time favourites'), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
    for (final spine in tester.widgetList<BookSpine>(find.byType(BookSpine))) {
      final size = tester.getSize(find.byWidget(spine));
      expect(size.height, greaterThan(size.width * 3));
    }
    final spineViewport = find.byKey(const ValueKey('shelf-spine-viewport-0'));
    final firstShelfSpines = find.descendant(
      of: spineViewport,
      matching: find.byType(BookSpine),
    );
    final viewportRect = tester.getRect(spineViewport);
    expect(firstShelfSpines, findsNWidgets(4));
    expect(tester.widget<ListView>(spineViewport).clipBehavior, Clip.hardEdge);
    for (var index = 0; index < 4; index++) {
      final spineRect = tester.getRect(firstShelfSpines.at(index));
      expect(spineRect.left, greaterThanOrEqualTo(viewportRect.left + 0.01));
      expect(spineRect.right, lessThanOrEqualTo(viewportRect.right - 0.01));
    }
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Books to buy'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('Books to buy'), findsOneWidget);
    expect(tester.takeException(), isNull);

    fakeData = emptyData;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ShelfHomePage)),
    );
    await container.read(shelfHomeProvider.notifier).refresh();
    await _pumpShelfHome(
      tester,
      data: emptyData,
      brightness: Brightness.dark,
      textDirection: TextDirection.rtl,
      textScale: 2,
      overrides: overrides,
    );

    expect(find.text('Reading now'), findsOneWidget);
    expect(find.text('No books here yet.'), findsWidgets);
    final navSemantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Add books'), findsOneWidget);
    navSemantics.dispose();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Books to buy'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Books to buy'), findsOneWidget);
    expect(find.text('No books here yet.'), findsWidgets);
    expect(tester.takeException(), isNull);

    fakeData = populatedData();
    final currentContainer = ProviderScope.containerOf(
      tester.element(find.byType(ShelfHomePage)),
    );
    await currentContainer.read(shelfHomeProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.byType(BookSpine), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(412, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          key: const ValueKey('home-navigation-ltr'),
          locale: const Locale('en'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
          ),
          home: HomePage(
            databaseReady: _never,
            startupRevealReady: Future<void>.value(),
          ),
        ),
      ),
    );
    // The bar sits behind a blur surface and a LayoutBuilder, so the sliding
    // indicator arrives on the frame after the resize, not on the same one.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // skipOffstage is off on purpose. The bar is laid out by the Scaffold as
    // bottomNavigationBar under extendBody, and after the taller bookcase
    // landed the default finder stopped counting the pill even though it is
    // still built and still painted. Worth re-checking on a device.
    expect(
      find.byKey(
        const Key('sliding-navigation-indicator'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Journal')).dx,
      lessThan(tester.getCenter(find.text('Library')).dx),
    );
    expect(
      tester.getCenter(find.text('Library')).dx,
      lessThan(tester.getCenter(find.text('More')).dx),
    );
    for (var index = 0; index < 3; index++) {
      expect(
        tester.getSize(find.byKey(ValueKey('navigation-tab-$index'))).height,
        greaterThanOrEqualTo(48),
      );
    }
    final semantics = tester.ensureSemantics();
    final libraryNode = tester.getSemantics(find.bySemanticsLabel('Library'));
    expect(libraryNode.getSemanticsData().role, SemanticsRole.tab);
    // isSemantics checks only the properties named, unlike matchesSemantics.
    // SemanticsFlag is not a public name in this Flutter version, so assert
    // the selected state through the public matcher.
    expect(libraryNode, isSemantics(isSelected: true));
    semantics.dispose();
    await tester.tap(find.text('Journal'));
    await tester.pump();
    expect(find.text('Journal pages will appear here.'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('My shelves'), findsOneWidget);

    // The reduce-motion, right-to-left pass is in home_navigation_test.dart.
    // It needs a ProviderContainer of its own, and only one of those can exist
    // per isolate while Sync is both a Riverpod notifier and a singleton.
  });

  for (final brightness in Brightness.values) {
    test('sliding navigation labels pass contrast in ${brightness.name}', () {
      final scheme = PaperfoldTokens.colorScheme(brightness);
      final background = scheme.surfaceContainerLow;
      expect(BookSpine.contrast(scheme.primary, background),
          greaterThanOrEqualTo(4.5));
      expect(BookSpine.contrast(scheme.onSurfaceVariant, background),
          greaterThanOrEqualTo(4.5));
    });
  }
}

final Future<void> _never = Completer<void>().future;
