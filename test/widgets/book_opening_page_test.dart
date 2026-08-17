import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/widgets/book_opening_page.dart';

/// The one surface between a tap on the shelf and the first line of text. Two
/// screens draw it — the shelf raises it, the reader holds it — and the
/// handover is only invisible while both draw the same thing, so what it is
/// made of is worth pinning down.
void main() {
  Future<void> pumpPage(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    bool showMark = true,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6750A4),
            brightness: brightness,
          ),
        ),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: BookOpeningPage(
            title: 'The Moonstone',
            author: 'Wilkie Collins',
            turn: const AlwaysStoppedAnimation<double>(0.25),
            showMark: showMark,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('names the book it is opening', (tester) async {
    await pumpPage(tester);

    expect(find.text('The Moonstone'), findsOneWidget);
    expect(find.text('Wilkie Collins'), findsOneWidget);
  });

  testWidgets('takes its paper from the brightness, not from one fixed sheet',
      (tester) async {
    // The shelf is true black. Landing on cream at night is a flash in the
    // face, so the night pair exists and must actually be used.
    expect(
      BookOpeningPage.paperFor(Brightness.dark),
      BookOpeningPage.paperDark,
    );
    expect(
      BookOpeningPage.paperFor(Brightness.light),
      BookOpeningPage.paper,
    );
    expect(
      BookOpeningPage.inkFor(Brightness.dark),
      BookOpeningPage.inkDark,
    );

    await pumpPage(tester);
    final box = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(BookOpeningPage),
        matching: find.byType(ColoredBox),
      ).first,
    );
    expect(box.color, BookOpeningPage.paperDark);
  });

  testWidgets('the mark holds still when the system asks for no motion',
      (tester) async {
    await pumpPage(tester, reduceMotion: true);

    // A rotation would never let the tree settle, and a wait that cannot show
    // progress is better shown as a mark that simply sits there.
    expect(find.byType(RotationTransition), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the shelf can raise the page before there is a wait',
      (tester) async {
    await pumpPage(tester, showMark: false);

    expect(find.byType(RotationTransition), findsNothing);
    expect(find.text('The Moonstone'), findsOneWidget);
  });
}
