import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/paperfold_logo_mark.dart';

void main() {
  Widget host(Brightness brightness, Widget child) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: PaperfoldTokens.colorScheme(brightness),
      ),
      home: Scaffold(body: Center(child: child)),
    );
  }

  for (final Brightness brightness in Brightness.values) {
    testWidgets('the mark takes the ${brightness.name} accent',
        (WidgetTester tester) async {
      final ColorScheme scheme = PaperfoldTokens.colorScheme(brightness);

      await tester.pumpWidget(
        host(brightness, const PaperfoldLogoMark(size: 48)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final SvgPicture wreath = tester.widget(find.byType(SvgPicture));
      // The accent swaps between themes, and it swaps in the theme, not here.
      expect(
        wreath.colorFilter,
        ColorFilter.mode(scheme.primary, BlendMode.srcIn),
      );
    });
  }

  testWidgets('the mark is decorative until it is given a label',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      host(Brightness.light, const PaperfoldLogoMark(size: 48)),
    );
    await tester.pumpAndSettle();

    final SemanticsHandle handle = tester.ensureSemantics();
    expect(find.semantics.byLabel(RegExp('.+')), findsNothing);
    handle.dispose();
  });

  testWidgets('the application icon keeps the cover colours',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      host(
        Brightness.light,
        const PaperfoldAppIcon(size: 108),
      ),
    );
    await tester.pumpAndSettle();

    final ColoredBox ground = tester.widget(
      find.descendant(
        of: find.byType(PaperfoldAppIcon),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(ground.color, PaperfoldTokens.cover.ground);

    final SvgPicture wreath = tester.widget(find.byType(SvgPicture));
    // The icon never reads the theme. A launcher shows one icon, whatever the
    // reader has the application set to.
    expect(
      wreath.colorFilter,
      ColorFilter.mode(PaperfoldTokens.cover.foil, BlendMode.srcIn),
    );
  });

  testWidgets('the adaptive shapes carry no ground',
      (WidgetTester tester) async {
    for (final PaperfoldAppIconShape shape in <PaperfoldAppIconShape>[
      PaperfoldAppIconShape.adaptiveForeground,
      PaperfoldAppIconShape.monochrome,
    ]) {
      await tester.pumpWidget(
        host(Brightness.light, PaperfoldAppIcon(size: 108, shape: shape)),
      );
      await tester.pumpAndSettle();

      final ColoredBox ground = tester.widget(
        find.descendant(
          of: find.byType(PaperfoldAppIcon),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(
        ground.color.a,
        0,
        reason: '${shape.name} must leave the launcher to draw the ground',
      );
    }
  });
}
