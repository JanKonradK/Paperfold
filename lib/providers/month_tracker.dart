import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/dao/daily_read.dart';

/// One month of pages read, as the circular tracker paints it.
class MonthTrackerData {
  const MonthTrackerData({
    required this.year,
    required this.month,
    required this.pagesByDay,
    required this.today,
  });

  final int year;
  final int month;

  /// Day of the month to pages read. A day with no reading is absent, which is
  /// not the same as a day recorded as zero.
  final Map<int, int> pagesByDay;

  /// The day the ring marks as now, or null when the month is not this month.
  final int? today;

  /// Days in this month. February and the short months matter here, because
  /// the ring paints one segment per real day.
  int get dayCount => DateTime(year, month + 1, 0).day;

  int get totalPages => pagesByDay.values.fold(0, (sum, pages) => sum + pages);

  int get daysRead => pagesByDay.values.where((pages) => pages > 0).length;

  int pagesFor(int day) => pagesByDay[day] ?? 0;

  bool isRecorded(int day) => pagesByDay.containsKey(day);

  double get averagePagesOnReadDays =>
      daysRead == 0 ? 0 : totalPages / daysRead;

  /// The busiest day, used to scale every other day against it. Never zero, so
  /// callers can divide by it.
  int get busiestDay {
    int busiest = 0;
    for (final int pages in pagesByDay.values) {
      if (pages > busiest) {
        busiest = pages;
      }
    }
    return busiest == 0 ? 1 : busiest;
  }

  /// How full a day's segment is drawn, from 0 to 1.
  double fillFor(int day) {
    final int pages = pagesFor(day);
    if (pages <= 0) {
      return 0;
    }
    // A day the reader read at all is never drawn as nothing, or a light day
    // beside a heavy one disappears.
    return (pages / busiestDay).clamp(0.16, 1);
  }
}

/// The month the tracker shows. Changing it moves the ring.
final trackedMonthProvider = StateProvider<DateTime>((ref) {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month);
});

final monthTrackerProvider =
    AsyncNotifierProvider<MonthTrackerController, MonthTrackerData>(
  MonthTrackerController.new,
);

class MonthTrackerController extends AsyncNotifier<MonthTrackerData> {
  @override
  Future<MonthTrackerData> build() {
    // Watching the month means the ring reloads when the reader steps back a
    // month, without every caller remembering to refresh.
    final DateTime month = ref.watch(trackedMonthProvider);
    return _load(month);
  }

  Future<void> refresh() async {
    final DateTime month = ref.read(trackedMonthProvider);
    state = await AsyncValue.guard(() => _load(month));
  }

  /// Records pages the reader entered by hand for [day].
  Future<void> setPages(DateTime day, int pages) async {
    await dailyReadDao.setPages(day, pages);
    await refresh();
  }

  Future<MonthTrackerData> _load(DateTime month) async {
    final Map<int, int> pages =
        await dailyReadDao.pagesByDay(month.year, month.month);
    final DateTime now = DateTime.now();
    final bool isThisMonth = now.year == month.year && now.month == month.month;

    return MonthTrackerData(
      year: month.year,
      month: month.month,
      pagesByDay: pages,
      today: isThisMonth ? now.day : null,
    );
  }
}
