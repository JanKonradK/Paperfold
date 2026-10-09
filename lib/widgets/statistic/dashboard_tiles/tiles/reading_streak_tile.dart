import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/providers/reading_streak_provider.dart';
import 'package:paperfold/widgets/common/async_skeleton_wrapper.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_base.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_metadata.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_registry.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReadingStreakTile extends StatisticsDashboardTileBase {
  const ReadingStreakTile();

  @override
  StatisticsDashboardTileMetadata get metadata {
    final l10n = l10nLocal;
    return StatisticsDashboardTileMetadata(
      type: StatisticsDashboardTileType.readingStreak,
      title: l10n.tileReadingStreakTitle,
      description: l10n.tileReadingStreakDescription,
      columnSpan: 2,
      rowSpan: 2,
      icon: Icons.local_fire_department_outlined,
    );
  }

  @override
  Widget buildContent(BuildContext context, WidgetRef ref) {
    final asyncValue = ref.watch(readingStreakProvider);
    return AsyncSkeletonWrapper<ReadingStreakData>(
      asyncValue: asyncValue,
      onRetry: () async => ref.invalidate(readingStreakProvider),
      mock: const ReadingStreakData(
        currentStreak: 4,
        longestStreak: 12,
        lastReadingDay: null,
      ),
      builder: (data, _) => _ReadingStreakContent(data: data),
    );
  }
}

class _ReadingStreakContent extends StatelessWidget {
  const _ReadingStreakContent({required this.data});

  final ReadingStreakData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasReadToday = _isSameDay(data.lastReadingDay, DateTime.now());
    final fireColor =
        hasReadToday ? theme.colorScheme.primary : theme.colorScheme.outline;
    final l10n = L10n.of(context);
    final encouragement = hasReadToday
        ? l10n.tileReadingStreakEncouragementActive
        : l10n.tileReadingStreakEncouragementInactive;
    final subtitle = hasReadToday
        ? l10n.tileReadingStreakSubtitleActive
        : l10n.tileReadingStreakSubtitleInactive;

    // Every child states how it gives way when the tile is short. A Spacer
    // here took the remaining space before the encouragement had been laid
    // out, so at a raised font size the tile overflowed its own box.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.local_fire_department, color: fireColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.tileReadingStreakCurrent(data.currentStreak),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: fireColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            )
          ],
        ),
        const SizedBox(height: 8),
        _StatPill(
          label: l10n.tileReadingStreakBestLabel,
          value: l10n.tileReadingStreakCurrent(data.longestStreak),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: Text(
            encouragement,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime? date1, DateTime? date2) {
    if (date1 == null || date2 == null) return false;
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
