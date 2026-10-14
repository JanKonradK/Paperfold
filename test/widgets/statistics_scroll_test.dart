import 'package:flutter_riverpod/misc.dart' show Override;
// Scrolling the statistics page, which skipped a chunk and threw itself to the
// top on the way up. Two faults: the auto-dispose `statisticDataProvider` lost
// its last listener mid-scroll and came back loading, and each book card
// re-read its own book in a `FutureBuilder` built inside `build`. Both put a
// spinner where a laid out section was, so content shrank under the offset.
//
//   flutter test test/widgets/statistics_scroll_test.dart

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/enums/chart_mode.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/statistic_data_model.dart';
import 'package:paperfold/page/home_page/statistics_page.dart';
import 'package:paperfold/providers/dashboard_tiles_provider.dart';
import 'package:paperfold/providers/month_tracker.dart';
import 'package:paperfold/providers/reading_challenge.dart';
import 'package:paperfold/providers/statistic_data.dart';
import 'package:paperfold/providers/total_reading_time.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _bookCount = 12;

Book _book(int id) {
  return Book(
    id: id,
    title: 'Book $id',
    coverPath: 'cover-$id.png',
    filePath: 'book-$id.epub',
    lastReadPosition: '',
    readingPercentage: 0.5,
    author: 'Ursula Le Guin',
    isDeleted: false,
    rating: 0,
    status: BookStatus.finished,
    createTime: DateTime.utc(2026),
    updateTime: DateTime.utc(2026),
  );
}

StatisticDataModel _model() {
  return StatisticDataModel(
    mode: ChartMode.week,
    isSelectingDay: false,
    date: DateTime(2026, 8, 13),
    readingTime: const <int>[600, 1200, 0, 300, 900, 0, 1500],
    xLabels: const <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'],
    bookReadingTime: <Map<Book, int>>[
      for (int id = 1; id <= _bookCount; id++) <Book, int>{_book(id): id * 600},
    ],
  );
}

/// Counts every fetch, so a test can tell a refetch from a rebuild.
class _FakeStatisticData extends StatisticData {
  _FakeStatisticData(this.onFetch);

  final VoidCallback onFetch;

  @override
  Future<StatisticDataModel> build() async {
    onFetch();
    return _model();
  }
}

class _FakeTotalReadingTime extends TotalReadingTime {
  @override
  Future<int> build() async => 7200;
}

/// No tiles, so the dashboard does not reach for the database.
class _EmptyTiles extends DashboardTilesNotifier {
  _EmptyTiles() {
    state = const DashboardTilesState(
      savedTiles: <StatisticsDashboardTileType>[],
      workingTiles: <StatisticsDashboardTileType>[],
      hasUnsavedChanges: false,
      isEditing: false,
    );
  }
}

class _FakeChallenge extends ReadingChallengeController {
  @override
  Future<ReadingChallengeData> build() async => ReadingChallengeData(
        year: 2026,
        target: 100,
        finished: <Book>[_book(1)],
        readingNow: <Book>[_book(2)],
        today: DateTime(2026, 8, 13),
      );

  @override
  Future<void> refresh() async {}
}

class _FakeMonth extends MonthTrackerController {
  @override
  Future<MonthTrackerData> build() async => const MonthTrackerData(
        year: 2026,
        month: 8,
        pagesByDay: <int, int>{1: 10, 13: 40},
        today: 13,
      );

  @override
  Future<void> refresh() async {}
}

List<Override> _overrides(VoidCallback onFetch) {
  return <Override>[
    statisticDataProvider.overrideWith(() => _FakeStatisticData(onFetch)),
    totalReadingTimeProvider.overrideWith(_FakeTotalReadingTime.new),
    dashboardTilesProvider.overrideWith((_) => _EmptyTiles()),
    readingChallengeProvider.overrideWith(_FakeChallenge.new),
    monthTrackerProvider.overrideWith(_FakeMonth.new),
  ];
}

MaterialApp _app(Widget child, Brightness brightness) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: L10n.supportedLocales,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: PaperfoldTokens.colorScheme(brightness),
    ),
    home: child,
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  /// A phone, so the page takes its narrow single-column branch.
  void useAPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('a book card', () {
    late List<Override> overrides;

    setUp(() => overrides = _overrides(() {}));

    Widget host(Brightness brightness) {
      return ProviderScope(
        overrides: overrides,
        child: _app(
          const Scaffold(
            body: CustomScrollView(slivers: <Widget>[DateBooks()]),
          ),
          brightness,
        ),
      );
    }

    testWidgets('survives a rebuild without going back to the database',
        (WidgetTester tester) async {
      useAPhone(tester);
      await tester.pumpWidget(host(Brightness.light));
      await tester.pumpAndSettle();

      expect(find.text('Book 1'), findsWidgets);

      // A new theme rebuilds every card. The book is already in hand, so the
      // card must paint on the very next frame rather than wait on a read.
      await tester.pumpWidget(host(Brightness.dark));
      await tester.pump();

      expect(
        find.text('Book 1'),
        findsWidgets,
        reason: 'the card re-read a book the statistics query already returned',
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('builds only the cards on screen', (WidgetTester tester) async {
      useAPhone(tester);
      await tester.pumpWidget(host(Brightness.light));
      await tester.pumpAndSettle();

      // One eager `Column` built all twelve, and each card stats its cover
      // file. The lower bound matters: a layout that throws builds none, which
      // would otherwise read as a pass.
      expect(
        find.byType(BookStatisticItem).evaluate().length,
        allOf(greaterThan(0), lessThan(_bookCount)),
      );
      expect(find.text('Book 1'), findsWidgets);
    });
  });

  group('the statistics page', () {
    testWidgets('reads the statistics once, however far it is scrolled',
        (WidgetTester tester) async {
      useAPhone(tester);
      int fetches = 0;
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(() => fetches++),
          child: _app(StatisticPage(controller: controller), Brightness.light),
        ),
      );
      await tester.pumpAndSettle();

      expect(fetches, 1);
      final double noteTop =
          tester.getTopLeft(find.byType(StatisticsMeasureNote)).dy;

      // Walk the whole page down and back up. The end of the list is an
      // estimate until it is reached, so this re-reads it every step.
      double offset = 0;
      for (int step = 0; step < 200; step++) {
        controller.jumpTo(offset);
        await tester.pumpAndSettle();
        final double end = controller.position.maxScrollExtent;
        if (offset >= end) break;
        offset = (offset + 200).clamp(0, end).toDouble();
      }
      for (int step = 0; step < 200 && offset > 0; step++) {
        offset = (offset - 200)
            .clamp(0, controller.position.maxScrollExtent)
            .toDouble();
        controller.jumpTo(offset);
        await tester.pumpAndSettle();
      }

      expect(
        fetches,
        1,
        reason: 'the page dropped its data mid-scroll and fetched it again',
      );
      expect(controller.offset, 0);
      expect(
        tester.getTopLeft(find.byType(StatisticsMeasureNote)).dy,
        closeTo(noteTop, 0.5),
        reason: 'the content moved under the reader on the way back up',
      );
    });

    testWidgets(
        'drops the statistics when the page closes, so reopening '
        'reads fresh numbers', (WidgetTester tester) async {
      useAPhone(tester);
      int fetches = 0;
      final ProviderContainer container =
          ProviderContainer(overrides: _overrides(() => fetches++));
      addTearDown(container.dispose);

      Widget host(Widget child) => UncontrolledProviderScope(
            container: container,
            child: _app(child, Brightness.light),
          );

      await tester.pumpWidget(host(const StatisticPage()));
      await tester.pumpAndSettle();
      expect(fetches, 1);

      await tester.pumpWidget(host(const SizedBox.shrink()));
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(const StatisticPage()));
      await tester.pumpAndSettle();

      expect(
        fetches,
        2,
        reason: 'the page held the data past its own life, so the numbers '
            'would go stale after a reading session',
      );
    });
  });
}
