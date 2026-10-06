import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/enums/chart_mode.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/statistic_data_model.dart';
import 'package:paperfold/models/wishlist_item.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/dashboard_tiles_provider.dart';
import 'package:paperfold/providers/journal_home.dart';
import 'package:paperfold/providers/month_tracker.dart';
import 'package:paperfold/providers/notes_statistics.dart';
import 'package:paperfold/providers/reading_challenge.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/providers/statistic_data.dart';
import 'package:paperfold/providers/total_reading_time.dart';

/// Fakes and data shared by the shelf home tests and the navigation tests.
///
/// These live outside both test files because `Sync` is a Riverpod notifier and
/// a hand-rolled singleton at the same time, so only one ProviderContainer can
/// exist per isolate. `flutter test` gives each file its own isolate, which is
/// why the navigation tests sit in a file of their own rather than beside the
/// shelf tests.

class FakeShelfHomeController extends ShelfHomeController {
  @override
  Future<ShelfHomeData> build() async => fakeData;

  @override
  Future<void> refresh() async => state = AsyncData(fakeData);
}

class FakeBookList extends BookList {
  @override
  Future<List<List<Book>>> build() async => const [];
}

/// The Journal destination reads the database. In a widget test it must be
/// fed, or the screen sits on its loading spinner forever.
class FakeJournalHome extends JournalHomeController {
  FakeJournalHome([this.onBuild, this.onRefresh]);

  final void Function()? onBuild;
  final void Function()? onRefresh;

  @override
  Future<List<JournalEntry>> build() async {
    onBuild?.call();
    return const [];
  }

  @override
  Future<void> refresh() async {
    onRefresh?.call();
    state = const AsyncData([]);
  }
}

class FakeReadingChallenge extends ReadingChallengeController {
  FakeReadingChallenge([this.onRefresh]);

  final void Function()? onRefresh;

  @override
  Future<ReadingChallengeData> build() async => ReadingChallengeData(
        year: 2026,
        target: 12,
        finished: const [],
        readingNow: const [],
        // The pace calculation needs a fixed day, or the test drifts with the
        // calendar.
        today: DateTime(2026, 8, 13),
      );

  @override
  Future<void> refresh() async {
    onRefresh?.call();
    state = AsyncData(await build());
  }
}

class FakeMonthTracker extends MonthTrackerController {
  FakeMonthTracker([this.onRefresh]);

  final void Function()? onRefresh;

  @override
  Future<MonthTrackerData> build() async => const MonthTrackerData(
        year: 2026,
        month: 8,
        pagesByDay: {},
        today: null,
      );

  @override
  Future<void> refresh() async {
    onRefresh?.call();
    state = AsyncData(await build());
  }
}

class FakeStatisticData extends StatisticData {
  FakeStatisticData([this.onBuild, this.onRefresh]);

  final void Function()? onBuild;
  final void Function()? onRefresh;

  @override
  Future<StatisticDataModel> build() async {
    onBuild?.call();
    return StatisticDataModel(
      mode: ChartMode.week,
      isSelectingDay: false,
      date: DateTime(2026, 8, 13),
      readingTime: const [600, 1200, 0, 300, 900, 0, 1500],
      xLabels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
      bookReadingTime: const [],
    );
  }

  @override
  Future<void> refresh() async => onRefresh?.call();
}

class FakeTotalReadingTime extends TotalReadingTime {
  @override
  Future<int> build() async => 7200;
}

// Navigation tests do not need dashboard tiles to query the database.
class FakeDashboardTiles extends DashboardTilesNotifier {
  FakeDashboardTiles() {
    state = const DashboardTilesState(
      savedTiles: [],
      workingTiles: [],
      hasUnsavedChanges: false,
      isEditing: false,
    );
  }
}

class FakeNotesStatistics extends NotesStatistics {
  @override
  Future<Map<String, int>> build() async =>
      const {'numberOfNotes': 0, 'numberOfBooks': 0};
}

class FakeBookIdAndNotes extends BookIdAndNotes {
  @override
  Future<List<Map<String, dynamic>>> build() async => const [];
}

Book book(int id, String title, BookStatus status) {
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

ShelfHomeData populatedData() {
  return ShelfHomeData(
    readingNow: [
      book(1, 'The Left Hand of Darkness', BookStatus.reading),
      book(6, 'The Tombs of Atuan', BookStatus.reading),
      book(7, 'The Farthest Shore', BookStatus.reading),
      book(8, 'Tehanu', BookStatus.reading),
    ],
    favourites: [book(2, 'A Wizard of Earthsea', BookStatus.finished)],
    toBeRead: [book(3, 'The Dispossessed', BookStatus.notStarted)],
    finished: [book(4, 'Always Coming Home', BookStatus.finished)],
    booksToBuy: const [
      WishlistItem(
          id: 5, title: 'The Lathe of Heaven', author: 'Ursula Le Guin'),
    ],
  );
}

const emptyData = ShelfHomeData(
  readingNow: [],
  favourites: [],
  toBeRead: [],
  finished: [],
  booksToBuy: [],
);

/// What [FakeShelfHomeController] serves. Set it before pumping.
ShelfHomeData fakeData = emptyData;

List<Override> newTestOverrides({
  void Function()? onJournalBuild,
  void Function()? onJournalRefresh,
  void Function()? onChallengeRefresh,
  void Function()? onMonthRefresh,
  void Function()? onStatisticsBuild,
  void Function()? onStatisticsRefresh,
}) =>
    [
      shelfHomeProvider.overrideWith(FakeShelfHomeController.new),
      bookListProvider.overrideWith(FakeBookList.new),
      journalHomeProvider.overrideWith(
          () => FakeJournalHome(onJournalBuild, onJournalRefresh)),
      readingChallengeProvider
          .overrideWith(() => FakeReadingChallenge(onChallengeRefresh)),
      monthTrackerProvider.overrideWith(() => FakeMonthTracker(onMonthRefresh)),
      statisticDataProvider.overrideWith(
          () => FakeStatisticData(onStatisticsBuild, onStatisticsRefresh)),
      totalReadingTimeProvider.overrideWith(FakeTotalReadingTime.new),
      dashboardTilesProvider.overrideWith((_) => FakeDashboardTiles()),
      notesStatisticsProvider.overrideWith(FakeNotesStatistics.new),
      bookIdAndNotesProvider.overrideWith(FakeBookIdAndNotes.new),
    ];
