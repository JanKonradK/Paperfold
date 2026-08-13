// The two tracker pages: the reading challenge shelf and the month ring.
//
// Both draw on one canvas rather than one widget per spine or per day, which
// plan.md Section 11.2 asks for. A canvas has no widgets to find, so these
// tests read the semantics tree instead. That is the point: a painted control
// with no semantics is unusable, and nothing else would catch it.
//
//   flutter test test/widgets/tracker_pages_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/journal/month_tracker_page.dart';
import 'package:paperfold/page/journal/reading_challenge_page.dart';
import 'package:paperfold/providers/month_tracker.dart';
import 'package:paperfold/providers/reading_challenge.dart';

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

ReadingChallengeData _challenge({int target = 100}) {
  return ReadingChallengeData(
    year: 2026,
    target: target,
    finished: <Book>[
      _book(1, 'A Wizard of Earthsea'),
      _book(2, 'The Tombs of Atuan'),
      _book(3, 'The Farthest Shore'),
    ],
    readingNow: <Book>[_book(4, 'Tehanu')],
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
}
