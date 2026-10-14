// Empty states and failure states must survive an unbounded height.
//
// These blocks are placed in parents that measure them with no height bound:
// `NotesTips` is a direct child of a bare `Column` in the reader's note list,
// and `StatisticsTips` sits inside a `FittedBox` on the statistics dashboard.
// Both are easy to break by adding a scroll view, so the property is pinned
// here rather than left to inspection.
//
// Note: these cases were written while chasing a "RenderFlex overflowed by
// 99564 pixels" red screen, and they do NOT reproduce it — the tests pass
// with and without the guard in MessageBlock. That defect is still open; do
// not read a green run here as evidence it is fixed.
//
//   flutter test test/widgets/unbounded_message_test.dart

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/common/load_failure.dart';
import 'package:paperfold/widgets/tips/bookshelf_tips.dart';
import 'package:paperfold/widgets/tips/notes_tips.dart';
import 'package:paperfold/widgets/tips/statistic_tips.dart';

Widget _host(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
    supportedLocales: L10n.supportedLocales,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
    ),
    home: Scaffold(body: child),
  );
}

const List<(String, Widget)> _blocks = <(String, Widget)>[
  ('NotesTips', NotesTips()),
  ('BookshelfTips', BookshelfTips()),
  ('StatisticsTips', StatisticsTips()),
  ('LoadFailure.page', LoadFailure.page()),
];

void main() {
  for (final (String name, Widget block) in _blocks) {
    testWidgets('$name lays out inside a bare Column', (tester) async {
      // Exactly the reader's note list: a Column hands its children an
      // unbounded height.
      await tester.pumpWidget(
        _host(
          SingleChildScrollView(
            child: Column(
              children: <Widget>[const Divider(), block],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'an unbounded height must not overflow');
    });

    testWidgets('$name lays out inside a FittedBox', (tester) async {
      // Exactly the statistics dashboard tile.
      await tester.pumpWidget(_host(Center(child: FittedBox(child: block))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('$name still scrolls when the height is bounded',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_host(block));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'a short window scrolls rather than overflowing');
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });
  }
}
