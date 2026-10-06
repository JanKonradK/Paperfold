import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:paperfold/widgets/bookshelf/continue_reading_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shelf_home_fixtures.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  test('resume uses the latest current reading book and skips stale entries',
      () {
    final older = book(1, 'Older', BookStatus.reading);
    final latest = book(2, 'Latest', BookStatus.reading)
      ..updateTime = DateTime.utc(2026, 9);
    final deleted = book(3, 'Deleted', BookStatus.reading)
      ..isDeleted = true
      ..updateTime = DateTime.utc(2026, 10);
    final finished = book(4, 'Finished', BookStatus.finished)
      ..updateTime = DateTime.utc(2026, 10);
    final unread = book(5, 'Unread', BookStatus.notStarted)
      ..updateTime = DateTime.utc(2026, 10);
    final noFile = book(6, 'No file', BookStatus.reading)
      ..filePath = ' '
      ..updateTime = DateTime.utc(2026, 10);
    final source = [older, deleted, latest, finished, unread, noFile];

    expect(continueReadingBook(source), same(latest));
    expect(source.first, same(older));
    expect(continueReadingBook([deleted, finished, unread, noFile]), isNull);
    expect(continueReadingBook([]), isNull);
  });

  testWidgets('resume is one labelled action with safe reading progress',
      (tester) async {
    final current = book(1, 'A Wizard of Earthsea', BookStatus.reading)
      ..readingPercentage = 0.42;
    var opened = 0;
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Widget host() => MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: ThemeData(
            colorScheme: PaperfoldTokens.colorScheme(Brightness.dark),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.4)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ContinueReadingBanner(
                book: current,
                onOpen: () => opened++,
              ),
            ),
          ),
        );

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('42% read'), findsOneWidget);
    await tester.tap(find.byType(ContinueReadingBanner));
    expect(opened, 1);

    final semantics = tester.ensureSemantics();
    try {
      await tester.pump();
      expect(
        find.semantics.byLabel(
            'Continue reading, A Wizard of Earthsea, Ursula Le Guin, 42% read'),
        findsOne,
      );
    } finally {
      semantics.dispose();
    }

    current.readingPercentage = double.nan;
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('0% read'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short library keeps resume and shelves usable at large text',
      (tester) async {
    final current = book(9, 'The Dispossessed', BookStatus.reading)
      ..readingPercentage = 0.33
      ..updateTime = DateTime.utc(2026, 10);
    fakeData = ShelfHomeData(
      readingNow: [current],
      favourites: const [],
      toBeRead: const [],
      finished: const [],
      booksToBuy: const [],
    );
    var openedId = 0;
    await tester.binding.setSurfaceSize(const Size(320, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: newTestOverrides(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: ThemeData(
            colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ShelfHomePage(
            bookActions: ShelfHomeBookActions(
              open: (selected) => openedId = selected.id,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Bookcase)).height, greaterThan(80));

    // A very tall text-scaled banner can extend below the short header's
    // viewport. Its visible leading area must still open the book.
    await tester.tapAt(tester.getTopLeft(
            find.byKey(const ValueKey('library-continue-reading'))) +
        const Offset(24, 24));
    expect(openedId, current.id);

    await tester.drag(
      find.byKey(const ValueKey('shelf-header-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shelf-sort-control')).hitTestable(),
        findsOneWidget);
    expect(tester.takeException(), isNull);

    current.status = BookStatus.finished;
    fakeData = ShelfHomeData(
      readingNow: const [],
      favourites: const [],
      toBeRead: const [],
      finished: [current],
      booksToBuy: const [],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ShelfHomePage)),
    );
    await container.read(shelfHomeProvider.notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.byType(ContinueReadingBanner), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
