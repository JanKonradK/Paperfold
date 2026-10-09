import 'package:flutter_riverpod/misc.dart' show Override;
// The reading challenge page: progress, real books, and safe target changes.
//
//   flutter test test/widgets/reading_challenge_page_test.dart

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/journal/reading_challenge_page.dart';
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

ReadingChallengeData _data({
  int year = 2026,
  int target = 100,
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
        ],
    readingNow: readingNow ?? <Book>[_book(3, 'Tehanu')],
    today: DateTime(2026, 8, 13),
  );
}

class _Fake extends ReadingChallengeController {
  _Fake(this.data);

  final ReadingChallengeData data;
  final List<int> saved = <int>[];
  bool failSave = false;
  int saveCalls = 0;
  Completer<void>? pendingSave;

  @override
  Future<ReadingChallengeData> build() async {
    // Still watched, so the year buttons drive a real rebuild.
    ref.watch(trackedChallengeYearProvider);
    return data;
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<int> setTarget(int target) async {
    saveCalls++;
    await pendingSave?.future;
    if (failSave) throw StateError('storage unavailable');
    saved.add(target);
    return target;
  }
}

class _YearAware extends ReadingChallengeController {
  @override
  Future<ReadingChallengeData> build() async {
    return _data(year: ref.watch(trackedChallengeYearProvider));
  }

  @override
  Future<void> refresh() async {}
}

class _Broken extends ReadingChallengeController {
  int loads = 0;

  @override
  Future<ReadingChallengeData> build() async {
    loads++;
    throw StateError('no shelves');
  }

  @override
  Future<void> refresh() async {
    loads++;
    state = AsyncError<ReadingChallengeData>(
      StateError('no shelves'),
      StackTrace.empty,
    );
  }
}

Widget _host(ReadingChallengeController Function() controller) {
  return ProviderScope(
    overrides: <Override>[
      readingChallengeProvider.overrideWith(controller),
    ],
    child: MaterialApp(
      localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
      supportedLocales: L10n.supportedLocales,
      locale: const Locale('en'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
      ),
      home: const ReadingChallengePage(),
    ),
  );
}

int _countSemantics(WidgetTester tester) {
  final SemanticsNode root = tester
      .binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!;
  int total = 0;
  void visit(SemanticsNode node) {
    total++;
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return total;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  group('the target dialog', () {
    testWidgets('saves, and survives a keyboard write during the exit',
        (WidgetTester tester) async {
      final _Fake fake = _Fake(_data());
      await tester.pumpWidget(_host(() => fake));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('challenge-target-field')),
        '42',
      );
      await tester.tap(find.text('Save'));

      // Do not settle. showDialog's future completes when the route is popped,
      // while the dialog is still animating out and still attached to the
      // keyboard. A controller disposed at that await would throw here.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      tester.testTextInput.enterText('421');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fake.saved, <int>[42]);
    });

    testWidgets('dismisses without saving, and without a late write crashing',
        (WidgetTester tester) async {
      final _Fake fake = _Fake(_data());
      await tester.pumpWidget(_host(() => fake));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      tester.testTextInput.enterText('7');
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fake.saved, isEmpty);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('refuses an out-of-range target in place',
        (WidgetTester tester) async {
      final _Fake fake = _Fake(_data());
      await tester.pumpWidget(_host(() => fake));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();

      final Finder field =
          find.byKey(const ValueKey<String>('challenge-target-field'));

      // Zero is below the floor. The dialog says so rather than letting the
      // DAO silently clamp it.
      await tester.enterText(field, '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(field, findsOne, reason: 'the dialog stays open');
      expect(find.text('Enter 1 to 999 books.'), findsWidgets);
      expect(fake.saved, isEmpty);

      await tester.enterText(field, '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(field, findsOne);
      expect(fake.saved, isEmpty);

      await tester.enterText(field, '12');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(fake.saved, <int>[12]);
    });

    testWidgets('waits for a save and retains the target after failure',
        (tester) async {
      final fake = _Fake(_data())
        ..failSave = true
        ..pendingSave = Completer<void>();
      await tester.pumpWidget(_host(() => fake));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.flag_outlined));
      await tester.pumpAndSettle();
      final field =
          find.byKey(const ValueKey<String>('challenge-target-field'));
      await tester.enterText(field, '42');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      expect(fake.saveCalls, 1);

      fake.pendingSave!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Your target could not be saved. Try again.'),
          findsOneWidget);
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          '42');
      fake.failSave = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(fake.saved, [42]);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the challenge', () {
    testWidgets('shows real books without creating rows for the target',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(() => _Fake(_data(target: 999))));
      await tester.pumpAndSettle();

      expect(
        tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((tile) => (tile.title! as Text).data),
        ['A Wizard of Earthsea', 'The Tombs of Atuan', 'Tehanu'],
      );
      expect(_countSemantics(tester), lessThan(50));
      handle.dispose();
    });

    testWidgets('a large target keeps a compact progress summary',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(() => _Fake(_data(target: 999))));
      await tester.pumpAndSettle();

      final Size summary = tester.getSize(
        find.byKey(const ValueKey<String>('challenge-progress')),
      );
      expect(summary.height, lessThan(400));
    });

    testWidgets('a book keeps a 48 dp target and a tap action',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(() => _Fake(_data())));
      await tester.pumpAndSettle();

      final SemanticsNode book = find.semantics
          .byLabel(RegExp('A Wizard of Earthsea'))
          .evaluate()
          .single;
      expect(book.rect.width, greaterThanOrEqualTo(48));
      expect(book.rect.height, greaterThanOrEqualTo(48));
      expect(book.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets('states progress, pace, and book status sections',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(() => _Fake(_data())));
      await tester.pumpAndSettle();

      expect(find.text('2026'), findsOne);
      expect(find.text('2 of 100 books'), findsOne);
      expect(find.text('A steady pace is 61 books by this point.'), findsOne);
      expect(find.text('Read'), findsOne);
      expect(find.text('Reading'), findsOne);
      // The state the shelf no longer paints has no key either.
      expect(find.text('Want to read'), findsNothing);
    });

    testWidgets('a status section appears only when it contains books',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(() => _Fake(_data(readingNow: const <Book>[]))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Read'), findsOne);
      expect(find.text('Reading'), findsNothing);
    });

    testWidgets('passing the target is reported, not hidden',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(() => _Fake(_data(target: 1))));
      await tester.pumpAndSettle();

      expect(find.text('1 book past the target'), findsOne);
    });

    testWidgets('an empty year explains how to start',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          () => _Fake(
            _data(finished: const <Book>[], readingNow: const <Book>[]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No books in this challenge yet'), findsOne);
      expect(
        find.text(
          'Mark a book as Reading or finish a book to start filling the challenge.',
        ),
        findsOne,
      );
      expect(
        find.byType(ListTile),
        findsNothing,
      );
    });
  });

  group('the page', () {
    testWidgets('moves to a past year and back', (WidgetTester tester) async {
      await tester.pumpWidget(_host(_YearAware.new));
      await tester.pumpAndSettle();

      expect(find.text('2026'), findsOne);
      await tester.tap(
        find.byKey(const ValueKey<String>('challenge-previous-year')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOne);

      await tester.tap(
        find.byKey(const ValueKey<String>('challenge-next-year')),
      );
      await tester.pumpAndSettle();
      expect(find.text('2026'), findsOne);
    });

    testWidgets('a failed load offers a retry', (WidgetTester tester) async {
      final _Broken broken = _Broken();
      await tester.pumpWidget(_host(() => broken));
      await tester.pumpAndSettle();

      expect(find.text('This could not be loaded.'), findsOne);

      final int before = broken.loads;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(broken.loads, greaterThan(before));
    });

    testWidgets('progress and target editing fit a narrow screen at 2x text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(_host(() => _Fake(_data())));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final target = find.byIcon(Icons.flag_outlined).hitTestable();
      await tester.scrollUntilVisible(
        target,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(target, findsOneWidget);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
