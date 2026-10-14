import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/page/home_page/notes_page.dart';
import 'package:paperfold/page/home_page/statistics_page.dart';
import 'package:paperfold/page/settings_page/settings_home_page.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:paperfold/widgets/paperfold_library_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shelf_home_fixtures.dart';

/// The reduce-motion, right-to-left pass for the sliding navigation bar.
///
/// It used to sit at the end of the shelf home test, where it pumped into an
/// empty tree. The cause was not the bookcase: `Sync` is a Riverpod notifier
/// and a singleton at the same time, so the second ProviderContainer in an
/// isolate throws `LateInitializationError` on the notifier's write-once
/// `_element`, and `SyncButton` in the Library app bar is what reads it.
/// `flutter test` runs each file in its own isolate, so one container per file
/// keeps the singleton happy. Do not add a second `ProviderScope` here.
void main() {
  testWidgets(
    'four direct destinations mount lazily, retain state, and mirror in RTL',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await Prefs().initPrefs();
      fakeData = populatedData();
      var journalBuilds = 0;
      var journalRefreshes = 0;
      var challengeRefreshes = 0;
      var monthRefreshes = 0;
      var statisticsBuilds = 0;
      var statisticsRefreshes = 0;
      var failStatisticsRefresh = false;
      await tester.binding.setSurfaceSize(const Size(412, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: newTestOverrides(
            onJournalBuild: () => journalBuilds++,
            onJournalRefresh: () => journalRefreshes++,
            onChallengeRefresh: () => challengeRefreshes++,
            onMonthRefresh: () => monthRefreshes++,
            onStatisticsBuild: () => statisticsBuilds++,
            onStatisticsRefresh: () {
              statisticsRefreshes++;
              if (failStatisticsRefresh) {
                throw StateError('Statistics refresh unavailable');
              }
            },
          ),
          child: MaterialApp(
            navigatorKey: navigatorKey,
            // The locale stays English so the labels stay assertable. Only the
            // direction and the animation setting change.
            locale: const Locale('en'),
            localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
            supportedLocales: L10n.supportedLocales,
            theme: paperfoldLibraryTheme(ThemeData(
              useMaterial3: true,
              colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
            )),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: child!,
              ),
            ),
            home: HomePage(
              databaseReady: _never,
              startupRevealReady: Future<void>.value(),
            ),
          ),
        ),
      );
      // The bar sits behind a blur surface and a LayoutBuilder, so the sliding
      // indicator arrives on the frame after the first one, not on it.
      await tester.pumpAndSettle();

      Finder tab(int index) => find.byKey(ValueKey('navigation-tab-$index'));
      final labels = ['Journal', 'Library', 'Statistics', 'Settings'];
      for (var index = 0; index < labels.length; index++) {
        expect(
            find.descendant(of: tab(index), matching: find.text(labels[index])),
            findsOneWidget);
        expect(tester.widget<Semantics>(tab(index)).properties.selected,
            index == 1);
        if (index > 0) {
          expect(tester.getCenter(tab(index - 1)).dx,
              greaterThan(tester.getCenter(tab(index)).dx));
        }
      }
      expect(find.text('More'), findsNothing);
      expect(journalBuilds, 0);
      expect(statisticsBuilds, 0);
      expect(statisticsRefreshes, 0);
      expect(find.byType(StatisticPage, skipOffstage: false), findsNothing);
      expect(find.byType(SettingsHomePage, skipOffstage: false), findsNothing);
      expect(find.byType(NotesPage, skipOffstage: false), findsNothing);
      final bookcase = tester.state<BookcaseState>(find.byType(Bookcase));

      // skipOffstage is off for the same reason as in the shelf home test: the
      // Scaffold lays the bar out under extendBody and the default finder
      // stopped counting the pill after the taller bookcase landed.
      final indicator = find.byKey(
        const Key('sliding-navigation-indicator'),
        skipOffstage: false,
      );
      expect(indicator, findsOneWidget);
      expect(
        tester.widget<AnimatedPositionedDirectional>(indicator).duration,
        Duration.zero,
      );

      // The indicator is positioned from the start edge, which is the right
      // edge here. Library is selected first, so moving to Journal must send
      // the pill right, not left.
      final libraryTabRect = tester.getRect(indicator);
      await tester.tap(tab(0));
      await tester.pumpAndSettle();
      expect(tester.getRect(indicator).left, greaterThan(libraryTabRect.left));
      expect(journalBuilds, 1);
      expect(journalRefreshes, 0);
      expect(challengeRefreshes, 0);
      expect(monthRefreshes, 0);
      expect(statisticsBuilds, 0);
      expect(navigatorKey.currentState!.canPop(), isFalse);

      // Highlights is a Journal tool, not another root destination.
      final highlights = find.widgetWithText(ListTile, 'Highlights');
      await tester.ensureVisible(highlights);
      await tester.tap(highlights);
      await tester.pumpAndSettle();
      expect(find.byType(NotesPage), findsOneWidget);
      expect(navigatorKey.currentState!.canPop(), isTrue);
      expect(
          Theme.of(tester.element(find.byType(NotesPage))).colorScheme.surface,
          PaperfoldTokens.burgundy.ground);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(NotesPage), findsNothing);
      expect(tester.widget<Semantics>(tab(0)).properties.selected, isTrue);

      await tester.tap(tab(2));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticPage), findsOneWidget);
      expect(statisticsBuilds, 1);
      expect(statisticsRefreshes, 0,
          reason: 'the first visit already loads current statistics');
      expect(navigatorKey.currentState!.canPop(), isFalse);
      final statistics = tester.state(find.byType(StatisticPage));
      final statisticsScroll = tester
          .widget<CustomScrollView>(find.descendant(
            of: find.byType(StatisticPage),
            matching: find.byType(CustomScrollView),
          ))
          .controller!;
      expect(statisticsScroll.position.maxScrollExtent, greaterThan(100));
      statisticsScroll.jumpTo(100);
      await tester.pumpAndSettle();

      await tester.tap(tab(3));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsHomePage), findsOneWidget);
      expect(navigatorKey.currentState!.canPop(), isFalse);
      final settings = tester.state(find.byType(SettingsHomePage));
      await tester.tap(tab(2));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(StatisticPage)), same(statistics));
      expect(statisticsScroll.offset, 100);
      expect(statisticsBuilds, 1);
      expect(statisticsRefreshes, 1,
          reason: 'returning to Statistics refreshes its data in place');
      await tester.tap(tab(2));
      await tester.pumpAndSettle();
      expect(statisticsRefreshes, 1,
          reason: 'tapping the current tab does not refetch its data');
      await tester.tap(tab(3));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(SettingsHomePage)), same(settings));

      await tester.tap(tab(0));
      await tester.pumpAndSettle();
      expect(journalRefreshes, 1);
      expect(challengeRefreshes, 1);
      expect(monthRefreshes, 1);
      await tester.tap(tab(2));
      await tester.pumpAndSettle();
      expect(statisticsRefreshes, 2);
      expect(statisticsScroll.offset, 100);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(tab(0)).properties.selected, isTrue);
      expect(journalRefreshes, 2,
          reason: 'Back must refresh Journal just like selecting its tab');
      expect(challengeRefreshes, 2);
      expect(monthRefreshes, 2);

      failStatisticsRefresh = true;
      await tester.tap(tab(2));
      await tester.pumpAndSettle();
      expect(statisticsRefreshes, 3);
      expect(find.text('This could not be loaded.'), findsOneWidget);
      expect(tester.state(find.byType(StatisticPage)), same(statistics));
      expect(statisticsScroll.offset, 100);
      expect(tester.takeException(), isNull);
      failStatisticsRefresh = false;
      await tester.tap(find.widgetWithText(SnackBarAction, 'Retry'));
      await tester.pumpAndSettle();
      expect(statisticsRefreshes, 4);
      expect(statisticsScroll.offset, 100);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(tab(1));
      await tester.pumpAndSettle();
      expect(
          tester.state<BookcaseState>(find.byType(Bookcase)), same(bookcase));
      await bookcase.climbTo(2);
      await tester.pumpAndSettle();
      await tester.binding.setSurfaceSize(const Size(900, 412));
      await tester.pumpAndSettle();
      expect(
          tester.state<BookcaseState>(find.byType(Bookcase)), same(bookcase));
      expect(bookcase.shelf, 2);
      expect(find.byType(NavigationRail), findsOneWidget);
      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(
          rail.destinations
              .map((destination) => (destination.label as Text).data),
          labels);
      expect(rail.selectedIndex, 1);
      expect(tester.state(find.byType(StatisticPage, skipOffstage: false)),
          same(statistics));
      expect(tester.state(find.byType(SettingsHomePage, skipOffstage: false)),
          same(settings));
      expect(journalBuilds, 1);
      expect(statisticsBuilds, 1);
      expect(statisticsRefreshes, 4,
          reason: 'an offstage layout change must not refresh statistics');
      expect(journalRefreshes, 2);
      expect(challengeRefreshes, 2);
      expect(monthRefreshes, 2);

      expect(tester.takeException(), isNull);
    },
  );
}

final Future<void> _never = Completer<void>().future;
