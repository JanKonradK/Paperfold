import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/wishlist_item.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/journal_home.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeShelfHomeController extends ShelfHomeController {
  @override
  Future<ShelfHomeData> build() async => _fakeData;

  @override
  Future<void> refresh() async => state = AsyncData(_fakeData);
}

class _FakeBookList extends BookList {
  @override
  Future<List<List<Book>>> build() async => const [];
}

/// The Journal destination reads the database. In a widget test it must be
/// fed, or the screen sits on its loading spinner forever.
class _FakeJournalHome extends JournalHomeController {
  @override
  Future<List<JournalEntry>> build() async => const [];
}

Book _book(int id, String title, BookStatus status) {
  return Book(
    id: id,
    title: title,
    coverPath: '',
    filePath: 'book-$id.epub',
    lastReadPosition: '',
    readingPercentage: 0,
    author: 'Ursula Le Guin',
    isDeleted: false,
    rating: 0,
    status: status,
    createTime: DateTime.utc(2026),
    updateTime: DateTime.utc(2026),
  );
}

ShelfHomeData _populatedData() {
  return ShelfHomeData(
    readingNow: [
      _book(1, 'The Left Hand of Darkness', BookStatus.reading),
      _book(6, 'The Tombs of Atuan', BookStatus.reading),
      _book(7, 'The Farthest Shore', BookStatus.reading),
      _book(8, 'Tehanu', BookStatus.reading),
    ],
    favourites: [_book(2, 'A Wizard of Earthsea', BookStatus.finished)],
    toBeRead: [_book(3, 'The Dispossessed', BookStatus.notStarted)],
    finished: [_book(4, 'Always Coming Home', BookStatus.finished)],
    booksToBuy: const [
      WishlistItem(
          id: 5, title: 'The Lathe of Heaven', author: 'Ursula Le Guin'),
    ],
  );
}

const _emptyData = ShelfHomeData(
  readingNow: [],
  favourites: [],
  toBeRead: [],
  finished: [],
  booksToBuy: [],
);

ShelfHomeData _fakeData = _emptyData;

List<Override> _newTestOverrides() => [
      shelfHomeProvider.overrideWith(_FakeShelfHomeController.new),
      bookListProvider.overrideWith(_FakeBookList.new),
      journalHomeProvider.overrideWith(_FakeJournalHome.new),
    ];

Future<void> _pumpShelfHome(
  WidgetTester tester, {
  required ShelfHomeData data,
  Brightness brightness = Brightness.light,
  TextDirection textDirection = TextDirection.ltr,
  double textScale = 1,
  required List<Override> overrides,
}) async {
  _fakeData = data;
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
    final overrides = _newTestOverrides();
    await _pumpShelfHome(
      tester,
      data: _populatedData(),
      overrides: overrides,
    );

    expect(find.text('Reading now'), findsOneWidget);
    expect(find.text('All time favourites'), findsOneWidget);
    expect(find.byType(ListView), findsWidgets);
    expect(
      tester
          .widgetList<BookSpine>(find.byType(BookSpine))
          .any((spine) => spine.orientation == BookSpineOrientation.horizontal),
      isTrue,
    );
    expect(find.byType(Scaffold), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(RefreshIndicator), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('Books to buy'), findsOneWidget);
    expect(tester.takeException(), isNull);

    _fakeData = _emptyData;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ShelfHomePage)),
    );
    await container.read(shelfHomeProvider.notifier).refresh();
    await _pumpShelfHome(
      tester,
      data: _emptyData,
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

    await tester.drag(find.byType(RefreshIndicator), const Offset(0, -1100));
    await tester.pumpAndSettle();

    expect(find.text('Books to buy'), findsOneWidget);
    expect(find.text('No books here yet.'), findsWidgets);
    expect(tester.takeException(), isNull);

    _fakeData = _populatedData();
    await container.read(shelfHomeProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.byType(BookSpine), findsWidgets);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(412, 800);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
          ),
          home: HomePage(
            databaseReady: Completer<void>().future,
            startupRevealReady: Future<void>.value(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
        find.byKey(const Key('sliding-navigation-indicator')), findsOneWidget);
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

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: PaperfoldTokens.colorScheme(Brightness.dark),
          ),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: HomePage(
                databaseReady: _never,
                startupRevealReady: null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final indicator = tester.widget<AnimatedPositionedDirectional>(
      find.byKey(const Key('sliding-navigation-indicator')),
    );
    expect(indicator.duration, Duration.zero);
    expect(
      tester.getCenter(find.text('Journal')).dx,
      greaterThan(tester.getCenter(find.text('Library')).dx),
    );
    expect(
      tester.getCenter(find.text('Library')).dx,
      greaterThan(tester.getCenter(find.text('More')).dx),
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(800, 800);
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('sliding-navigation-indicator')), findsNothing);
    expect(tester.takeException(), isNull);
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
