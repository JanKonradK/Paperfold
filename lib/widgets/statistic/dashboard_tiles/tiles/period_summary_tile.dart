import 'package:paperfold/enums/chart_mode.dart';
import 'package:paperfold/models/statistic_data_model.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_registry.dart';
import 'package:paperfold/providers/statistic_data.dart';
import 'package:paperfold/providers/total_reading_time.dart';
import 'package:paperfold/utils/date/convert_seconds.dart';
import 'package:paperfold/widgets/common/async_skeleton_wrapper.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_base.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_metadata.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PeriodSummaryTile extends StatisticsDashboardTileBase {
  const PeriodSummaryTile();

  @override
  get metadata => StatisticsDashboardTileMetadata(
        type: StatisticsDashboardTileType.periodSummary,
        title: l10nLocal.tilePeriodSummaryTitle,
        description: l10nLocal.tilePeriodSummaryDescription,
        columnSpan: 2,
        rowSpan: 1,
        icon: Icons.bar_chart_rounded,
      );

  @override
  Widget buildContent(
    BuildContext context,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);

    return AsyncSkeletonWrapper(
        onRetry: () async {
          ref.invalidate(statisticDataProvider);
          ref.invalidate(totalReadingTimeProvider);
        },
        asyncValue: combineAsyncValues([
          ref.watch(statisticDataProvider),
          ref.watch(totalReadingTimeProvider),
        ]),
        mock: [
          StatisticDataModel.mock(),
          1,
        ],
        builder: (data, _) {
          final statisticData = data[0] as StatisticDataModel;
          final totalSeconds = data[1] as int;

          final periodSeconds = statisticData.mode == ChartMode.heatmap
              ? totalSeconds
              : statisticData.readingTime
                  .fold<int>(0, (sum, seconds) => sum + seconds);
          final formatted = convertSeconds(periodSeconds);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatted, style: theme.textTheme.headlineSmall),
              Text(
                  '${(periodSeconds / totalSeconds * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.labelMedium),
              const Spacer(),
              LinearProgressIndicator(
                value: periodSeconds == 0
                    ? 0
                    : (periodSeconds / totalSeconds).clamp(0, 1).toDouble(),
                minHeight: 6,
              ),
            ],
          );
        });
  }
}
