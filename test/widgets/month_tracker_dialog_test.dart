import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/journal/month_tracker_page.dart';
import 'package:paperfold/providers/month_tracker.dart';

class _Month extends MonthTrackerController {
  int? savedPages;
  DateTime? savedDay;
  bool failSave = false;
  int saveCalls = 0;
  Completer<void>? pendingSave;

  MonthTrackerData get data => MonthTrackerData(
        year: 2026,
        month: 8,
        pagesByDay: <int, int>{13: savedPages ?? 40},
        today: null,
      );

  @override
  Future<MonthTrackerData> build() async => data;

  @override
  Future<void> setPages(DateTime day, int pages) async {
    saveCalls++;
    await pendingSave?.future;
    if (failSave) throw StateError('storage unavailable');
    savedDay = day;
    savedPages = pages;
    state = AsyncData(data);
  }
}

Future<void> _openMonth(WidgetTester tester, _Month month) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [monthTrackerProvider.overrideWith(() => month)],
    child: const MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      locale: Locale('en'),
      home: MonthTrackerPage(),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _chooseDay13(WidgetTester tester) async {
  await tester.tap(find.text('Record pages'));
  await tester.pumpAndSettle();
  expect(find.byType(DatePickerDialog), findsOneWidget);
  await tester.tap(find.text('13'));
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  for (final action in <String>['Cancel', 'Save', 'Back']) {
    testWidgets('monthly pages can close with $action while keyboard hides',
        (tester) async {
      final semantics = tester.ensureSemantics();
      addTearDown(tester.view.resetViewInsets);
      final month = _Month();
      await tester.pumpWidget(ProviderScope(
        overrides: <Override>[monthTrackerProvider.overrideWith(() => month)],
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: const MonthTrackerPage(),
        ),
      ));
      await tester.pumpAndSettle();
      tester.semantics.tap(find.semantics.byLabel('Day 13: 40 pages'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '72');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      if (action == 'Back') {
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      } else {
        await tester.tap(find.text(action));
      }
      await tester.pump();
      // Android changes the insets while the popped dialog is still mounted.
      tester.view.viewInsets = const FakeViewPadding(bottom: 150);
      await tester.pump(const Duration(milliseconds: 30));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(month.savedPages, action == 'Save' ? 72 : isNull);
      expect(month.savedDay, action == 'Save' ? DateTime(2026, 8, 13) : isNull);
      semantics.dispose();
    });
  }

  testWidgets('record pages offers a date picker and rejects an empty total',
      (tester) async {
    final month = _Month();
    await _openMonth(tester, month);
    await _chooseDay13(tester);
    expect(find.text('Thursday, August 13, 2026'), findsOneWidget);
    final field = find.byKey(const ValueKey<String>('month-page-total-field'));
    await tester.enterText(field, '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
        find.text('Enter a whole number of pages, 0 or more.'), findsOneWidget);
    expect(month.saveCalls, 0);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(field, '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(month.savedDay, DateTime(2026, 8, 13));
    expect(month.savedPages, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page totals stay editable after a failed save', (tester) async {
    final month = _Month()
      ..failSave = true
      ..pendingSave = Completer<void>();
    await _openMonth(tester, month);
    await _chooseDay13(tester);
    await tester.enterText(find.byType(EditableText), '72');
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    final save = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(month.saveCalls, 1);
    month.pendingSave!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Your page total could not be saved. Try again.'),
        findsOneWidget);
    expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '72');

    month.failSave = false;
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(month.savedPages, 72);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tracker and date entry fit a narrow screen at 2x text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openMonth(tester, _Month());
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Record pages'));
    await _chooseDay13(tester);
    expect(find.byType(EditableText), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
