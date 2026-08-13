import 'package:paperfold/dao/base_dao.dart';

/// The reading challenge: how many books the reader means to finish in a year.
///
/// One row per year, so a new year starts a new challenge without touching the
/// old one. A year with no row has never been set, and reads as
/// [ChallengeDao.defaultTarget].
class ChallengeDao extends BaseDao {
  ChallengeDao({super.database});

  static const String table = 'tb_challenge';

  /// The challenge in the reference sheet is a hundred numbered spines, so a
  /// reader who never opens the target picker still gets that page.
  static const int defaultTarget = 100;

  /// The page paints every slot, so the target has to stay a number a page can
  /// hold. Nine hundred and ninety-nine spines is already far past useful.
  static const int minimumTarget = 1;
  static const int maximumTarget = 999;

  Future<int> targetForYear(int year) async {
    final int? stored = await querySingle<int?>(
      table,
      columns: const ['target_count'],
      where: 'year = ?',
      whereArgs: [year],
      mapper: (row) => row['target_count'] as int?,
    );
    return stored ?? defaultTarget;
  }

  /// Sets the target for [year] and returns the value that was stored.
  ///
  /// The value is clamped rather than rejected. A picker cannot offer an
  /// impossible number, but an import or a future caller can.
  Future<int> setTarget(int year, int target) async {
    final int clamped = target.clamp(minimumTarget, maximumTarget);
    final String now = DateTime.now().toIso8601String();

    final int changed = await update(
      table,
      {'target_count': clamped, 'update_time': now},
      where: 'year = ?',
      whereArgs: [year],
    );
    if (changed == 0) {
      await insert(table, {
        'year': year,
        'target_count': clamped,
        'create_time': now,
        'update_time': now,
      });
    }
    return clamped;
  }
}

final challengeDao = ChallengeDao();
