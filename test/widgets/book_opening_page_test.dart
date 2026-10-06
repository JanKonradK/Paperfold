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
    ColorScheme? scheme,
    bool showMark = true,
    bool reduceMotion = false,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        themeAnimationDuration: Duration.zero,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme ??
              ColorScheme.fromSeed(
                seedColor: const Color(0xFF6750A4),
                brightness: brightness,
              ),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduceMotion,
            textScaler: textScaler,
          ),
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

  testWidgets('uses the active theme for its paper and text', (tester) async {
    for (final scheme in [
      const ColorScheme.dark().copyWith(surface: Colors.black),
      const ColorScheme.light().copyWith(
        surface: const Color(0xFFDBE8DC),
        onSurface: const Color(0xFF172C20),
      ),
    ]) {
      await pumpPage(tester, scheme: scheme);
      final box = tester.widget<ColoredBox>(
        find
            .descendant(
              of: find.byType(BookOpeningPage),
              matching: find.byType(ColoredBox),
            )
            .first,
      );
      expect(box.color, scheme.surface);
      expect(tester.widget<Text>(find.text('The Moonstone')).style?.color,
          scheme.onSurface);
    }
  });

  testWidgets('large text fits a short window without overflowing',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpPage(tester, textScaler: const TextScaler.linear(2));
    await tester.ensureVisible(find.text('Wilkie Collins'));
    expect(tester.takeException(), isNull);
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
