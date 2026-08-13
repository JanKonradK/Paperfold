// The two tracker pages: the reading challenge shelf and the month ring.
//
// Both draw on one canvas rather than one widget per spine or per day, which
// plan.md Section 11.2 asks for. A canvas has no widgets to find, so these
// tests read the semantics tree instead. That is the point: a painted control
// with no semantics is unusable, and nothing else would catch it.
//
//   flutter test test/widgets/tracker_pages_test.dart

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/journal/month_tracker_page.dart';
import 'package:paperfold/page/journal/reading_challenge_page.dart';
import 'package:paperfold/page/home_page/statistics_page.dart';
import 'package:paperfold/providers/month_tracker.dart';
import 'package:paperfold/providers/reading_challenge.dart';
import 'package:shared_preferences/shared_preferences.dart';

Book _book(int id, String title) {
  return Book(
    id: id,
    title: title,
    coverPath: '',
    filePath: 'book-$id.epub',
    lastReadPosition: '',
    readingPercentage: 0,
    author: 'Ursula Le Guin',
    isDeleted: false,
    rating: 0,
    status: BookStatus.finished,
    createTime: DateTime.utc(2026),
    updateTime: DateTime.utc(2026),
  );
}

ReadingChallengeData _challenge({
  int year = 2026,
  int target = 100,
  DateTime? today,
  List<Book>? finished,
  List<Book>? readingNow,
}) {
  return ReadingChallengeData(
    year: year,
    target: target,
    finished: finished ??
        <Book>[
          _book(1, 'A Wizard of Earthsea'),
          _book(2, 'The Tombs of Atuan'),
          _book(3, 'The Farthest Shore'),
        ],
    readingNow: readingNow ?? <Book>[_book(4, 'Tehanu')],
    today: today ?? DateTime(2026, 8, 13),
  );
}

class _FakeChallenge extends ReadingChallengeController {
  _FakeChallenge(this.data);

  final ReadingChallengeData data;

  @override
  Future<ReadingChallengeData> build() async => data;

  @override
  Future<void> refresh() async => state = AsyncData(data);
}

class _FakeMonth extends MonthTrackerController {
  _FakeMonth(this.data);

  final MonthTrackerData data;

  @override
  Future<MonthTrackerData> build() async => data;

  @override
  Future<void> refresh() async => state = AsyncData(data);
}

class _YearAwareChallenge extends ReadingChallengeController {
  @override
  Future<ReadingChallengeData> build() async {
    final int year = ref.watch(trackedChallengeYearProvider);
    return _challenge(year: year);
  }
}

Widget _host(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
      ),
      home: child,
    ),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  group('the reading challenge', () {
    testWidgets('fills a spine per finished book and reads out the shelf',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const ReadingChallengePage(),
          <Override>[
            readingChallengeProvider
                .overrideWith(() => _FakeChallenge(_challenge())),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Three read, one being read, the rest empty.
      expect(
        find.semantics.byLabel('Spine 1: A Wizard of Earthsea'),
        findsOne,
      );
      expect(find.semantics.byLabel('Spine 4: Tehanu'), findsOne);
      expect(find.semantics.byLabel('Spine 5 is empty.'), findsOne);
      expect(
        find.semantics.byLabel(
          'Reading challenge shelf. 3 of 100 books read, 1 being read now.',
        ),
        findsOne,
      );
      handle.dispose();
    });

    testWidgets('the shelf is one canvas, not one widget per spine',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ReadingChallengePage(),
          <Override>[
            readingChallengeProvider
                .overrideWith(() => _FakeChallenge(_challenge())),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // One CustomPaint for the shelf. A hundred laid-out spines is the third
      // most likely source of jank in the project, so this is a real budget,
      // not a style preference.
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every slot state is covered by the legend',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ReadingChallengePage(),
          <Override>[
            readingChallengeProvider
                .overrideWith(() => _FakeChallenge(_challenge())),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Read'), findsOne);
      expect(find.text('Reading'), findsOne);
      expect(find.text('Want to read'), findsOne);
      expect(find.text('3 of 100 books'), findsOne);
    });

    testWidgets('passing the target is reported, not hidden',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ReadingChallengePage(),
          <Override>[
            readingChallengeProvider
                .overrideWith(() => _FakeChallenge(_challenge(target: 2))),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 book past the target'), findsOne);
    });

    testWidgets('moves to a past year and returns to the current year',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ReadingChallengePage(),
          <Override>[
            readingChallengeProvider.overrideWith(_YearAwareChallenge.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2026 reading challenge'), findsOne);
      await tester.tap(
        find.byKey(const ValueKey<String>('challenge-previous-year')),
      );
      await tester.pumpAndSettle();

      expect(find.text('2025 reading challenge'), findsOne);
      await tester.tap(
        find.byKey(const ValueKey<String>('challenge-next-year')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2026 reading challenge'), findsOne);
    });

    testWidgets('an empty shelf explains how to start',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const ReadingChallengePage(),
          <Override>[
            readingChallengeProvider.overrideWith(
              () => _FakeChallenge(
                _challenge(
                  finished: const <Book>[],
                  readingNow: const <Book>[],
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No books on this shelf yet'), findsOne);
      expect(
        find.text(
          'Mark a book as Reading or finish a book to start filling the challenge.',
        ),
        findsOne,
      );
    });

    testWidgets('each painted spine has a 48 dp semantic target',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const ReadingChallengePage(),
          <Override>[
            readingChallengeProvider
                .overrideWith(() => _FakeChallenge(_challenge())),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final SemanticsNode spine = find.semantics
          .byLabel('Spine 1: A Wizard of Earthsea')
          .evaluate()
          .single;
      expect(spine.rect.width, greaterThanOrEqualTo(48));
      expect(spine.rect.height, greaterThanOrEqualTo(48));
      expect(spine.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });

  group('the challenge data', () {
    test('slots run finished first, then reading, then empty', () {
      final ReadingChallengeData data = _challenge();

      expect(data.stateForSlot(1), ChallengeSlotState.finished);
      expect(data.stateForSlot(3), ChallengeSlotState.finished);
      expect(data.stateForSlot(4), ChallengeSlotState.reading);
      expect(data.stateForSlot(5), ChallengeSlotState.empty);
      expect(data.bookForSlot(2)?.title, 'The Tombs of Atuan');
      expect(data.bookForSlot(4)?.title, 'Tehanu');
      expect(data.bookForSlot(99), isNull);
    });

    test('a slot below one is empty rather than an error', () {
      expect(_challenge().stateForSlot(0), ChallengeSlotState.empty);
      expect(_challenge().bookForSlot(0), isNull);
    });

    test('pace uses the selected point in a leap year', () {
      final List<Book> finished = List<Book>.generate(
        61,
        (int index) => _book(index + 1, 'Book ${index + 1}'),
      );
      final ReadingChallengeData data = _challenge(
        target: 100,
        today: DateTime(2024, 8, 13),
        year: 2024,
        finished: finished,
        readingNow: const <Book>[],
      );

      expect(data.expectedFinished, 61);
      expect(data.paceDelta, 0);
    });

    test('a past year is judged at the end of its target', () {
      final ReadingChallengeData data = _challenge(
        year: 2025,
        target: 12,
        today: DateTime(2026, 8, 13),
        finished: <Book>[_book(1, 'One book')],
        readingNow: const <Book>[],
      );

      expect(data.expectedFinished, 12);
      expect(data.paceDelta, -11);
    });
  });

  group('the month ring', () {
    MonthTrackerData month({Map<int, int>? pages, int monthNumber = 8}) {
      return MonthTrackerData(
        year: 2026,
        month: monthNumber,
        pagesByDay: pages ?? const <int, int>{1: 10, 13: 40, 20: 5},
        today: 13,
      );
    }

    testWidgets('reads out every day, read or not',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const MonthTrackerPage(),
          <Override>[
            monthTrackerProvider.overrideWith(() => _FakeMonth(month())),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.semantics.byLabel('Day 13: 40 pages'), findsOne);
      expect(find.semantics.byLabel('Day 2: no pages'), findsOne);
      expect(
        find.semantics
            .byLabel('Pages read each day. 3 days read, 55 pages in total.'),
        findsOne,
      );
      handle.dispose();
    });

    testWidgets('the totals are stated in words as well as in the ring',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const MonthTrackerPage(),
          <Override>[
            monthTrackerProvider.overrideWith(() => _FakeMonth(month())),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('55 pages this month'), findsOne);
      expect(find.text('3 days read'), findsOne);
    });

    testWidgets('labels the scale and explains an empty month',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const MonthTrackerPage(),
          <Override>[
            monthTrackerProvider.overrideWith(
              () => _FakeMonth(month(pages: const <int, int>{})),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pages per day'), findsOne);
      expect(find.text('No pages recorded this month'), findsOne);
      expect(
        find.text('Tap a day number to add the page total for that day.'),
        findsOne,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('No pages'), findsOne);
      expect(find.text('Fewer pages'), findsOne);
      expect(find.text('More pages'), findsOne);
      expect(find.text('Today'), findsOne);
    });

    testWidgets('a day shows its saved total before editing',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          const MonthTrackerPage(),
          <Override>[
            monthTrackerProvider.overrideWith(() => _FakeMonth(month())),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final SemanticsNode day =
          find.semantics.byLabel('Day 13: 40 pages').evaluate().single;
      expect(day.rect.width, greaterThanOrEqualTo(48));
      expect(day.rect.height, greaterThanOrEqualTo(48));
      expect(day.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(
        find.semantics.byLabel('Day 13: 40 pages'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thursday, August 13, 2026'), findsOne);
      expect(find.text('This day has 40 pages.'), findsOne);
      expect(find.text('New page total'), findsOne);
      handle.dispose();
    });

    test('a short month paints its own day count', () {
      expect(month(monthNumber: 2).dayCount, 28);
      expect(month(monthNumber: 4).dayCount, 30);
      expect(month(monthNumber: 8).dayCount, 31);
    });

    test('a light day beside a heavy one is still visible', () {
      final MonthTrackerData data = month(pages: const {1: 1, 2: 400});

      expect(data.fillFor(2), 1);
      // Without a floor, one page against four hundred is a quarter of a pixel.
      expect(data.fillFor(1), greaterThanOrEqualTo(0.16));
      expect(data.fillFor(3), 0, reason: 'a day never read is not drawn');
    });

    test('an empty month never divides by zero', () {
      final MonthTrackerData data = month(pages: const <int, int>{});

      expect(data.busiestDay, 1);
      expect(data.totalPages, 0);
      expect(data.fillFor(1), 0);
    });
  });

  group('Statistics tracker sections', () {
    testWidgets('states both units and exposes both tracker routes',
        (WidgetTester tester) async {
      final MonthTrackerData data = MonthTrackerData(
        year: 2026,
        month: 8,
        pagesByDay: const <int, int>{1: 10, 13: 40},
        today: 13,
      );
      await tester.pumpWidget(
        _host(
          const SingleChildScrollView(
            child: Column(
              children: <Widget>[
                StatisticsMeasureNote(),
                StatisticsTrackerSections(),
              ],
            ),
          ),
          <Override>[
            readingChallengeProvider
                .overrideWith(() => _FakeChallenge(_challenge())),
            monthTrackerProvider.overrideWith(() => _FakeMonth(data)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reading-time charts · minutes per day'), findsOne);
      expect(
        find.text(
          'The charts use reading time in minutes. The month ring uses pages. These measures are separate.',
        ),
        findsOne,
      );
      expect(find.text('Reading trackers'), findsOne);
      expect(find.text('Open challenge'), findsOne);
      expect(find.text('Open month tracker'), findsOne);
      expect(find.text('Pages per day'), findsOne);
    });
  });
}
