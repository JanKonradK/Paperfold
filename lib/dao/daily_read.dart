import 'package:paperfold/dao/base_dao.dart';

/// Pages read per day, which the circular month tracker keys on.
///
/// tb_reading_time already stores minutes per day. This stores pages. They are
/// different measures and the fork only has the first one. plan.md Section 3.2.
class DailyReadDao extends BaseDao {
  DailyReadDao({super.database});

  static const String table = 'tb_daily_read';

  /// `date` is UNIQUE, so the key has to be one fixed shape. A calendar day in
  /// the reader's own time zone, never an instant.
  static String dateKey(DateTime day) {
    final String month = day.month.toString().padLeft(2, '0');
    final String date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  /// Pages read on every day of [month], keyed by day of the month.
  ///
  /// Days with no reading are absent rather than zero. The ring draws an empty
  /// day differently from a day that was recorded as nothing.
  Future<Map<int, int>> pagesByDay(int year, int month) async {
    final String prefix = '$year-${month.toString().padLeft(2, '0')}-';
    final List<MapEntry<int, int>> rows = await queryList(
      table,
      columns: const ['date', 'pages_read'],
      where: 'date LIKE ?',
      whereArgs: ['$prefix%'],
      mapper: (row) {
        final String date = row['date'] as String;
        final int day = int.parse(date.substring(date.length - 2));
        return MapEntry(day, (row['pages_read'] as int?) ?? 0);
      },
    );
    return Map<int, int>.fromEntries(rows);
  }

  /// Adds [pages] to the count for [day].
  ///
  /// Reading happens in sittings, so the day accumulates. Use [setPages] when
  /// the reader corrects a day by hand.
  Future<int> addPages(DateTime day, int pages) async {
    final int existing = await pagesOn(day) ?? 0;
    return setPages(day, existing + pages);
  }

  /// Replaces the count for [day]. A count below zero is stored as zero.
  Future<int> setPages(DateTime day, int pages) async {
    final int stored = pages < 0 ? 0 : pages;
    final String key = dateKey(day);
    final String now = DateTime.now().toIso8601String();

    final int changed = await update(
      table,
      {'pages_read': stored, 'update_time': now},
      where: 'date = ?',
      whereArgs: [key],
    );
    if (changed == 0) {
      await insert(table, {
        'date': key,
        'pages_read': stored,
        'create_time': now,
        'update_time': now,
      });
    }
    return stored;
  }

  /// Null when the day has never been recorded.
  Future<int?> pagesOn(DateTime day) {
    return querySingle<int?>(
      table,
      columns: const ['pages_read'],
      where: 'date = ?',
      whereArgs: [dateKey(day)],
      mapper: (row) => row['pages_read'] as int?,
    );
  }
}

final dailyReadDao = DailyReadDao();
