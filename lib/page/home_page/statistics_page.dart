import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/reading_time.dart';
import 'package:paperfold/enums/chart_mode.dart';
import 'package:paperfold/enums/hint_key.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/book_detail.dart';
import 'package:paperfold/page/journal/month_tracker_page.dart';
import 'package:paperfold/page/journal/reading_challenge_page.dart';
import 'package:paperfold/providers/month_tracker.dart';
import 'package:paperfold/providers/reading_challenge.dart';
import 'package:paperfold/providers/statistic_data.dart';
import 'package:paperfold/utils/date/convert_seconds.dart';
import 'package:paperfold/utils/date/week_of_year.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/common/container/filled_container.dart';
import 'package:paperfold/widgets/common/container/outlined_container.dart';
import 'package:paperfold/widgets/hint/hint_banner.dart';
import 'package:paperfold/widgets/statistic/statistic_card.dart';
import 'package:paperfold/widgets/statistic/statistics_dashboard_title.dart';
import 'package:paperfold/widgets/common/load_failure.dart';
import 'package:paperfold/widgets/statistic/statistics_dashboard.dart';
import 'package:paperfold/widgets/tips/statistic_tips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class StatisticPage extends StatefulWidget {
  const StatisticPage({super.key, this.controller});

  final ScrollController? controller;

  @override
  State<StatisticPage> createState() => _StatisticPageState();
}

class _StatisticPageState extends State<StatisticPage> {
  int totalNumberOfBook = 0;
  int totalNumberOfDate = 0;
  int totalNumberOfNotes = 0;
  late final ScrollController _scrollController =
      widget.controller ?? ScrollController();

  void setNumbers() async {
    final numberOfBook = await readingTimeDao.selectTotalNumberOfBook();
    final numberOfDate = await readingTimeDao.selectTotalNumberOfDate();
    final numberOfNotes = await readingTimeDao.selectTotalNumberOfNotes();
    setState(() {
      totalNumberOfBook = numberOfBook;
      totalNumberOfDate = numberOfDate;
      totalNumberOfNotes = numberOfNotes;
    });
  }

  @override
  void initState() {
    setNumbers();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text(context.navBarStatistics),
      // ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              StatisticsDashboardTitle(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      return Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StatisticsDashboard(),
                                  const StatisticsMeasureNote(),
                                  const StatisticCard(),
                                  const SizedBox(height: 20),
                                  const StatisticsTrackerSections(),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: ListView(
                              controller: _scrollController,
                              children: const [
                                DateBooks(),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ListView(
                                padding: const EdgeInsets.only(bottom: 80),
                                controller: _scrollController,
                                children: const [
                                  StatisticsDashboard(),
                                  StatisticsMeasureNote(),
                                  StatisticCard(),
                                  SizedBox(height: 20),
                                  StatisticsTrackerSections(),
                                  SizedBox(height: 20),
                                  DateBooks(),
                                ]),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatisticsMeasureNote extends StatelessWidget {
  const StatisticsMeasureNote({super.key});

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.schedule_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l10n.statisticReadingTimeUnit,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.statisticMeasureNote,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The two journal trackers as first-class Statistics sections.
///
/// These summaries use the same providers and routes as Journal. The month
/// section also reuses the painted ring, so the day controls stay available
/// without duplicating 31 widgets.
class StatisticsTrackerSections extends ConsumerWidget {
  const StatisticsTrackerSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = L10n.of(context);
    final AsyncValue<ReadingChallengeData> challenge =
        ref.watch(readingChallengeProvider);
    final AsyncValue<MonthTrackerData> month = ref.watch(monthTrackerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            l10n.statisticTrackersTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 12),
        FilledContainer(
          padding: const EdgeInsets.all(16),
          child: challenge.when(
            loading: () => const _TrackerLoading(),
            error: (Object error, StackTrace stackTrace) => _TrackerError(
              onRetry: () =>
                  ref.read(readingChallengeProvider.notifier).refresh(),
            ),
            data: (ReadingChallengeData data) =>
                _ChallengeStatisticsSection(data: data),
          ),
        ),
        const SizedBox(height: 12),
        FilledContainer(
          padding: const EdgeInsets.all(16),
          child: month.when(
            loading: () => const _TrackerLoading(),
            error: (Object error, StackTrace stackTrace) => _TrackerError(
              onRetry: () => ref.read(monthTrackerProvider.notifier).refresh(),
            ),
            data: (MonthTrackerData data) =>
                _MonthStatisticsSection(data: data),
          ),
        ),
      ],
    );
  }
}

class _ChallengeStatisticsSection extends StatelessWidget {
  const _ChallengeStatisticsSection({required this.data});

  final ReadingChallengeData data;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final ThemeData theme = Theme.of(context);
    final int pace = data.paceDelta;
    final String paceLabel = pace > 0
        ? l10n.challengePaceAhead(pace)
        : pace < 0
            ? l10n.challengePaceBehind(-pace)
            : l10n.challengePaceOnTrack;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.local_library_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.challengeYearTitle(data.year.toString()),
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.challengeProgress(data.finishedCount, data.target),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          value: data.progress.clamp(0, 1),
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          color: theme.colorScheme.primary,
          semanticsLabel: l10n.challengeTitle,
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Icon(
              pace < 0
                  ? Icons.trending_down
                  : pace > 0
                      ? Icons.trending_up
                      : Icons.trending_flat,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(paceLabel)),
          ],
        ),
        if (data.finished.isEmpty && data.readingNow.isEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            l10n.challengeEmptyTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            l10n.challengeEmptyBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const ReadingChallengePage(),
            ),
          ),
          icon: const Icon(Icons.arrow_forward),
          label: Text(l10n.statisticOpenChallenge),
        ),
      ],
    );
  }
}

class _MonthStatisticsSection extends StatelessWidget {
  const _MonthStatisticsSection({required this.data});

  final MonthTrackerData data;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final ThemeData theme = Theme.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.donut_large_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.monthTrackerPagesPerDay,
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    material.formatMonthYear(DateTime(data.year, data.month)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${l10n.monthTrackerPagesTotal(data.totalPages)} · '
          '${l10n.monthTrackerDaysRead(data.daysRead)}',
          style: theme.textTheme.bodyLarge,
        ),
        if (data.daysRead == 0) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            l10n.monthTrackerEmptyTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            l10n.monthTrackerEmptyBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        MonthTrackerRing(data: data, maximumDiameter: 260),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const MonthTrackerPage(),
            ),
          ),
          icon: const Icon(Icons.arrow_forward),
          label: Text(l10n.statisticOpenMonthTracker),
        ),
      ],
    );
  }
}

class _TrackerLoading extends StatelessWidget {
  const _TrackerLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _TrackerError extends StatelessWidget {
  const _TrackerError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.statisticTrackerLoadError),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.commonRetry),
        ),
      ],
    );
  }
}

class DateBooks extends ConsumerStatefulWidget {
  const DateBooks({super.key});

  @override
  ConsumerState<DateBooks> createState() => _DateBooksState();
}

class _DateBooksState extends ConsumerState<DateBooks> {
  // A Material role. The hardcoded `SourceHanSerif` set this heading in a CJK
  // serif in every language and ignored the Paperfold text theme, which
  // already substitutes a Chinese face where one is needed.
  TextStyle get titleStyle =>
      Theme.of(context).textTheme.headlineMedium!.copyWith(
            fontWeight: FontWeight.bold,
            overflow: TextOverflow.ellipsis,
          );

  List<int> deleteBookIds = [];

  @override
  void dispose() {
    super.dispose();
    if (deleteBookIds.isNotEmpty) {
      readingTimeDao.deleteReadingTimeByBookId(deleteBookIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statisticData = ref.watch(statisticDataProvider);

    Widget dragToDelete(Widget child, int bookId) {
      return StatefulBuilder(builder: (context, localSetState) {
        if (deleteBookIds.contains(bookId)) {
          return OutlinedContainer(
            margin: const EdgeInsets.only(bottom: 10),
            height: 146,
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete,
                          size: 30,
                        ),
                        Text(
                          L10n.of(context).statisticDeletedRecords,
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    FilledButton(
                        onPressed: () {
                          localSetState(() {
                            deleteBookIds.remove(bookId);
                          });
                        },
                        child: Text(L10n.of(context).commonUndo)),
                  ],
                ),
                const Spacer(),
                const Divider(),
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18),
                    Text(L10n.of(context).statisticDeletedRecordsTips),
                  ],
                ),
              ],
            ),
          );
        }
        ActionPane actionPane = ActionPane(
          motion: const StretchMotion(),
          children: [
            SlidableAction(
              onPressed: (context) {
                localSetState(() {
                  deleteBookIds.add(bookId);
                });
              },
              icon: Icons.delete,
              label: L10n.of(context).commonDelete,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            ),
          ],
        );
        return Slidable(
          key: ValueKey(bookId),
          startActionPane: actionPane,
          endActionPane: actionPane,
          child: child,
        );
      });
    }

    return statisticData.when(
      data: (data) {
        final title = data.isSelectingDay
            ? data.date.toString().substring(0, 10)
            : data.mode == ChartMode.week
                ? weekOfYear(data.date)
                : data.mode == ChartMode.month
                    ? '${data.date.year}.${data.date.month}'
                    : data.mode == ChartMode.year
                        ? data.date.year.toString()
                        : L10n.of(context).statisticAllTime;

        final books = data.bookReadingTime;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 10, right: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                ],
              ),
            ),
            if (books.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 50),
                child: StatisticsTips(),
              )
            else
              Column(
                children: [
                  HintBanner(
                    icon: const Icon(Icons.swipe_left),
                    hintKey: HintKey.statisticsSwipeToDelete,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Text(L10n.of(context).statisticsSwipeToDeleteHint),
                  ),
                  ...books.map((bookMap) {
                    final book = bookMap.keys.first;
                    final readingTime = bookMap.values.first;
                    return dragToDelete(
                      BookStatisticItem(
                        bookId: book.id,
                        readingTime: readingTime,
                      ),
                      book.id,
                    );
                  })
                ],
              ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stack) => LoadFailure.inline(
        title: L10n.of(context).statisticsLoadFailed,
        error: error,
      ),
    );
  }
}

class BookStatisticItem extends StatelessWidget {
  const BookStatisticItem(
      {super.key, required this.bookId, required this.readingTime});

  final int bookId;
  final int readingTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Material roles. These were a pinned CJK serif and a `Colors.grey` that
    // measures 2.49:1 on the light paper ground, under the 4.5:1 minimum.
    final TextStyle bookTitleStyle = theme.textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.bold,
      overflow: TextOverflow.ellipsis,
    );
    final TextStyle bookAuthorStyle = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      overflow: TextOverflow.ellipsis,
    );
    final TextStyle bookReadingTimeStyle =
        theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold);

    return FutureBuilder<Book>(
      future: bookDao.selectBookById(bookId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => BookDetail(book: snapshot.data!)));
            },
            child: FilledContainer(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Hero(
                      tag: snapshot.data!.coverFullPath,
                      child: BookCover(
                        book: snapshot.data!,
                        height: 130,
                        width: 90,
                        radius: 20,
                      )),
                  const SizedBox(width: 15),
                  Flexible(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(snapshot.data!.title, style: bookTitleStyle),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(snapshot.data!.author,
                                    style: bookAuthorStyle),
                              ),
                              Text(
                                  // getReadingTime(context),
                                  convertSeconds(readingTime),
                                  textAlign: TextAlign.end,
                                  style: bookReadingTimeStyle),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: snapshot.data!.readingPercentage,
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                  '${(snapshot.data!.readingPercentage * 100).toInt()} %'),
                            ],
                          ),
                        ]),
                  ),
                ],
              ),
            ),
          );
        } else {
          return const CircularProgressIndicator();
        }
      },
    );
  }
}
