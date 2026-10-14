import 'package:paperfold/models/statistic_data_model.dart';
import 'package:paperfold/providers/book_daily_reading_provider.dart';
import 'package:paperfold/providers/statistic_data.dart';
import 'package:paperfold/utils/date/convert_seconds.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/common/async_skeleton_wrapper.dart';
import 'package:paperfold/widgets/statistic/book_reading_chart.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_base.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_metadata.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_registry.dart';
import 'package:paperfold/widgets/tips/statistic_tips.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TopBookTile extends StatisticsDashboardTileBase {
  const TopBookTile();

  @override
  get metadata => StatisticsDashboardTileMetadata(
        type: StatisticsDashboardTileType.topBook,
        title: l10nLocal.tileTopBookTitle,
        description: l10nLocal.tileTopBookDescription,
        columnSpan: 4,
        rowSpan: 2,
        icon: Icons.bookmark_added_outlined,
      );

  @override
  Widget buildContent(
    BuildContext context,
    WidgetRef ref,
  ) {
    return AsyncSkeletonWrapper(
      asyncValue: ref.watch(statisticDataProvider),
      onRetry: () async => ref.invalidate(statisticDataProvider),
      mock: StatisticDataModel.mock(),
      builder: (statisticData, _) {
        if (statisticData.bookReadingTime.isEmpty) {
          return Center(child: FittedBox(child: StatisticsTips()));
        }
        final entry = statisticData.bookReadingTime.first;
        final book = entry.keys.first;
        final seconds = entry.values.first;

        // Material roles. A pinned CJK serif and a `Colors.grey` that
        // measures 2.49:1 on the light paper ground stood here.
        final theme = Theme.of(context);
        final TextStyle bookTitleStyle = theme.textTheme.titleMedium!.copyWith(
          fontWeight: FontWeight.bold,
          overflow: TextOverflow.ellipsis,
        );
        final TextStyle bookAuthorStyle = theme.textTheme.bodySmall!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          overflow: TextOverflow.ellipsis,
        );
        final TextStyle bookReadingTimeStyle =
            theme.textTheme.titleMedium!.copyWith(
          fontWeight: FontWeight.bold,
        );

        return Row(
          children: [
            BookCover(
              book: book,
              width: 120,
              radius: 10,
            ),
            const SizedBox(width: 15),
            Flexible(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: bookTitleStyle),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(book.author, style: bookAuthorStyle),
                        ),
                        Text(
                            // getReadingTime(context),
                            convertSeconds(seconds),
                            textAlign: TextAlign.end,
                            style: bookReadingTimeStyle),
                      ],
                    ),
                    const SizedBox(height: 10),
                    AsyncSkeletonWrapper(
                        onRetry: () async => ref.invalidate(
                          bookDailyReadingProvider(bookId: book.id),
                        ),
                        asyncValue: ref.watch(
                          bookDailyReadingProvider(bookId: book.id),
                        ),
                        mock: BookDailyReadingData.mock(),
                        builder: (bookReadingData, ready) {
                          return ready
                              ? Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: BookReadingChart(
                                      cumulativeValues:
                                          bookReadingData.readingTimes,
                                      dailySeconds:
                                          bookReadingData.readingTimes,
                                      dates: bookReadingData.dates,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }),
                  ]),
            ),
          ],
        );
      },
    );
  }
}
