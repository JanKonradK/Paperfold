import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/journal/month_tracker_page.dart';
import 'package:paperfold/providers/month_tracker.dart';

class _Month extends MonthTrackerController {
  int? savedPages;
  DateTime? savedDay;

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
    savedDay = day;
    savedPages = pages;
    state = AsyncData(data);
  }
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
}
