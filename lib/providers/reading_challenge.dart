import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  int get finishedCount => finished.length;

  /// Above one when the reader passes the target. The page shows the overflow
  /// as a number rather than painting spines it has no room for.
  double get progress => target <= 0 ? 0 : finishedCount / target;

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

class ReadingChallengeController extends AsyncNotifier<ReadingChallengeData> {
  @override
  Future<ReadingChallengeData> build() => _load();

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  /// Stores a new target and repaints. Returns the value that was stored,
  /// which the DAO may have clamped.
  Future<int> setTarget(int target) async {
    final int year = _currentYear;
    final int stored = await challengeDao.setTarget(year, target);
    await refresh();
    return stored;
  }

  int get _currentYear => DateTime.now().year;

  Future<ReadingChallengeData> _load() async {
    final int year = _currentYear;
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
      readingNow: all
          .where((book) => book.status == BookStatus.reading)
          .toList(growable: false),
    );
  }
}
