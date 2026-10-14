import 'package:paperfold/dao/reading_time.dart';
import 'package:paperfold/enums/chart_mode.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/statistic_data_model.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'statistic_data.g.dart';

@riverpod
class StatisticData extends _$StatisticData {
  /// Refresh a retained tab without resetting its chart, day, or scroll extent.
  Future<void> refresh() async {
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    final keepAlive = ref.keepAlive();
    try {
      final updated = await _fetchData(
        current.mode,
        current.isSelectingDay,
        current.date,
      );
      // A newer selection or refresh wins if it completed while this read ran.
      if (identical(state.value, current)) {
        state = AsyncValue.data(updated);
      }
    } finally {
      keepAlive.close();
    }
  }

  Future<void> _updateState({
    ChartMode? mode,
    bool? isSelectingDay,
    DateTime? date,
  }) async {
    final currentState = state.value!;
    final newMode = mode ?? currentState.mode;
    final newIsSelectingDay = isSelectingDay ?? currentState.isSelectingDay;
    final newDate = date ?? currentState.date;

    state = AsyncValue.data(await _fetchData(
      newMode,
      newIsSelectingDay,
      newDate,
    ));
  }

  Future<void> setMode(ChartMode mode) =>
      _updateState(mode: mode, isSelectingDay: false);

  Future<void> setIsSelectingDay(bool value, DateTime date) =>
      _updateState(isSelectingDay: value, date: date);

  Future<void> setDate(DateTime date) => _updateState(date: date);

  Future<void> touchMonth(int index) async {
    final date = state.value!.date;
    final newDate = DateTime(date.year, index + 1, 1);
    const mode = ChartMode.month;
    const isSelectingDay = false;
    await _updateState(
        date: newDate, mode: mode, isSelectingDay: isSelectingDay);
  }

  Future<void> touchDay(int days, int index) async {
    bool isWeek = days == 7;
    final date = state.value!.date;
    final newDate = isWeek
        ? date.subtract(Duration(days: date.weekday - 1 - index))
        : DateTime(date.year, date.month, index + 1);
    const isSelectingDay = true;
    await _updateState(date: newDate, isSelectingDay: isSelectingDay);
  }

  Future<StatisticDataModel> _fetchData(
    ChartMode mode,
    bool isSelectingDay,
    DateTime date,
  ) async {
    return StatisticDataModel(
      mode: mode,
      isSelectingDay: isSelectingDay,
      date: date,
      readingTime: await _getReadingTime(mode, date),
      xLabels: _getxLabels(mode, date),
      bookReadingTime: await _getBookReadingTime(isSelectingDay, mode, date),
    );
  }

  Future<List<int>> _getReadingTime(ChartMode mode, DateTime date) {
    final readingTimeMap = {
      ChartMode.week: () => readingTimeDao.selectReadingTimeOfWeek(date),
      ChartMode.month: () => readingTimeDao.selectReadingTimeOfMonth(date),
      ChartMode.year: () => readingTimeDao.selectReadingTimeOfYear(date),
      ChartMode.heatmap: () => Future.value([0]),
    };
    return readingTimeMap[mode]!();
  }

  List<String> _getxLabels(ChartMode mode, DateTime date) {
    BuildContext context = navigatorKey.currentContext!;
    final labelGenerators = {
      ChartMode.week: () => [
            L10n.of(context).statisticMonday,
            L10n.of(context).statisticTuesday,
            L10n.of(context).statisticWednesday,
            L10n.of(context).statisticThursday,
            L10n.of(context).statisticFriday,
            L10n.of(context).statisticSaturday,
            L10n.of(context).statisticSunday,
          ],
      ChartMode.month: () {
        final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
        return List.generate(daysInMonth,
            (i) => (i + 1) % 5 == 0 || i == 0 ? (i + 1).toString() : '');
      },
      ChartMode.year: () => List.generate(12, (i) => (i + 1).toString()),
      ChartMode.heatmap: () => [''],
    };
    return labelGenerators[mode]!();
  }

  Future<List<Map<Book, int>>> _getBookReadingTime(
    bool isSelectingDay,
    ChartMode mode,
    DateTime date,
  ) {
    if (isSelectingDay) {
      return readingTimeDao.selectBookReadingTimeOfDay(date);
    } else {
      final bookReadingTimeMap = {
        ChartMode.week: () => readingTimeDao.selectBookReadingTimeOfWeek(date),
        ChartMode.month: () =>
            readingTimeDao.selectBookReadingTimeOfMonth(date),
        ChartMode.year: () => readingTimeDao.selectBookReadingTimeOfYear(date),
        ChartMode.heatmap: () => readingTimeDao.selectBookReadingTimeOfAll(),
      };
      return bookReadingTimeMap[mode]!();
    }
  }

  @override
  FutureOr<StatisticDataModel> build() async {
    const initialMode = ChartMode.week;
    final initialDate = DateTime.now();

    return _fetchData(
      initialMode,
      false,
      initialDate,
    );
  }
}
