import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/wishlist_item.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/journal_home.dart';
import 'package:paperfold/providers/month_tracker.dart';
import 'package:paperfold/providers/reading_challenge.dart';
import 'package:paperfold/providers/shelf_home.dart';

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
  @override
  Future<List<JournalEntry>> build() async => const [];
}

class FakeReadingChallenge extends ReadingChallengeController {
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
}

class FakeMonthTracker extends MonthTrackerController {
  @override
  Future<MonthTrackerData> build() async => const MonthTrackerData(
        year: 2026,
        month: 8,
        pagesByDay: {},
        today: null,
      );
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

List<Override> newTestOverrides() => [
      shelfHomeProvider.overrideWith(FakeShelfHomeController.new),
      bookListProvider.overrideWith(FakeBookList.new),
      journalHomeProvider.overrideWith(FakeJournalHome.new),
      readingChallengeProvider.overrideWith(FakeReadingChallenge.new),
      monthTrackerProvider.overrideWith(FakeMonthTracker.new),
    ];
