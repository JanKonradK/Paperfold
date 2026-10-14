import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/challenge.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/models/book.dart';

/// What the challenge page paints: a year, a target, and the books behind it.
class ReadingChallengeData {
  const ReadingChallengeData({
    required this.year,
    required this.target,
    required this.finished,
    required this.readingNow,
    required this.today,
  });

  final int year;

  /// How many books the reader means to finish. One painted spine each.
  final int target;

  /// Finished during [year], in the order they were finished. Spine 1 is the
  /// first book of the year.
  final List<Book> finished;

  /// In progress right now. These fill the spines after the finished ones, so
  /// the page shows the reader where they stand, not only where they have been.
  final List<Book> readingNow;

  /// The local calendar day used to judge the reader's pace.
  ///
  /// Keeping this in the data makes the pace stable while the page is open
  /// and lets tests cover leap years and year boundaries.
  final DateTime today;

  int get finishedCount => finished.length;

  /// Above one when the reader passes the target. The page shows the overflow
  /// as a number rather than painting spines it has no room for.
  double get progress => target <= 0 ? 0 : finishedCount / target;

  /// How many books a steady reader would have finished by this point.
  ///
  /// A past year is judged at 31 December. The page does not navigate into
  /// future years, but zero is still a safe answer if another caller does.
  int get expectedFinished {
    if (year < today.year) {
      return target;
    }
    if (year > today.year || target <= 0) {
      return 0;
    }

    final DateTime firstDay = DateTime(year);
    final int daysInYear = DateTime(year + 1).difference(firstDay).inDays;
    final int daysElapsed = DateTime(today.year, today.month, today.day)
            .difference(firstDay)
            .inDays +
        1;
    return (target * daysElapsed / daysInYear).floor();
  }

  /// Positive is ahead of pace, negative is behind, and zero is on pace.
  int get paceDelta => finishedCount - expectedFinished;

  /// The book on a one-based spine, or null when the spine is still empty.
  Book? bookForSlot(int slot) {
    if (slot < 1) {
      return null;
    }
    if (slot <= finished.length) {
      return finished[slot - 1];
    }
    final int readingIndex = slot - finished.length - 1;
    if (readingIndex < readingNow.length) {
      return readingNow[readingIndex];
    }
    return null;
  }

  /// The state a one-based spine is painted in.
  ChallengeSlotState stateForSlot(int slot) {
    if (slot < 1) {
      return ChallengeSlotState.empty;
    }
    if (slot <= finished.length) {
      return ChallengeSlotState.finished;
    }
    if (slot <= finished.length + readingNow.length) {
      return ChallengeSlotState.reading;
    }
    return ChallengeSlotState.empty;
  }
}

/// The three states in the tracker legend.
///
/// plan.md Section 8 lists the challenge page and the tracker shelf separately.
/// They are one painted shelf here: the spines are the challenge, and the
/// legend is what the tracker shelf added.
enum ChallengeSlotState { finished, reading, empty }

final readingChallengeProvider =
    AsyncNotifierProvider<ReadingChallengeController, ReadingChallengeData>(
  ReadingChallengeController.new,
);

/// The year shown by the full challenge page.
///
/// The Journal and Statistics summaries watch the same value, so both entry
/// points describe the year the reader last chose instead of disagreeing.
final trackedChallengeYearProvider = StateProvider<int>((ref) {
  return DateTime.now().year;
});

class ReadingChallengeController extends AsyncNotifier<ReadingChallengeData> {
  @override
  Future<ReadingChallengeData> build() {
    final int year = ref.watch(trackedChallengeYearProvider);
    return _load(year);
  }

  Future<void> refresh() async {
    final int year = ref.read(trackedChallengeYearProvider);
    state = await AsyncValue.guard(() => _load(year));
  }

  /// Stores a new target and repaints. Returns the value that was stored,
  /// which the DAO may have clamped.
  Future<int> setTarget(int target) async {
    final int year = ref.read(trackedChallengeYearProvider);
    final int stored = await challengeDao.setTarget(year, target);
    await refresh();
    return stored;
  }

  Future<ReadingChallengeData> _load(int year) async {
    final DateTime today = DateTime.now();
    final Future<int> targetFuture = challengeDao.targetForYear(year);
    final Future<List<Book>> finishedFuture =
        bookDao.selectFinishedInYear(year);
    final Future<List<Book>> allFuture = bookDao.selectNotDeleteBooks();

    final int target = await targetFuture;
    final List<Book> finished = await finishedFuture;
    final List<Book> all = await allFuture;

    return ReadingChallengeData(
      year: year,
      target: target,
      finished: finished,
      // A past challenge is a historical record. Books being read now do not
      // belong on its shelf.
      readingNow: year == today.year
          ? all
              .where((book) => book.status == BookStatus.reading)
              .toList(growable: false)
          : const <Book>[],
      today: today,
    );
  }
}
