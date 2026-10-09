import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/ornament.dart';

void main() {
  // A wrong asset path in the enum only shows up as a blank shape at runtime,
  // and the owner replaces these placeholders with their own artwork later, so
  // the mapping is worth guarding rather than trusting.
  testWidgets('every ornament resolves to a real asset', (tester) async {
    for (final ornament in PaperfoldOrnament.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Ornament(ornament: ornament, width: 40, height: 40),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '${ornament.name} must load its SVG',
      );
    }
  });

  for (final Brightness brightness in Brightness.values) {
    testWidgets(
      'ornament renders with the ${brightness.name} theme accent',
      (WidgetTester tester) async {
        final ColorScheme colorScheme = PaperfoldTokens.colorScheme(brightness);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: colorScheme,
            ),
            home: const Scaffold(
              body: Center(
                child: Ornament(
                  ornament: PaperfoldOrnament.circularWreath,
                  width: 120,
                  height: 120,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(SvgPicture), findsOneWidget);
        final SvgPicture picture = tester.widget(find.byType(SvgPicture));
        expect(
          picture.colorFilter,
          ColorFilter.mode(colorScheme.primary, BlendMode.srcIn),
        );
      },
    );
  }

  testWidgets('shelf dressing placeholders remain decorative and tintable',
      (tester) async {
    final colorScheme = PaperfoldTokens.colorScheme(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, colorScheme: colorScheme),
        home: Scaffold(
          body: Row(
            children: [
              for (final ornament in const [
                PaperfoldOrnament.pottedPlant,
                PaperfoldOrnament.bookend,
                PaperfoldOrnament.smallUrn,
              ])
                Ornament(
                  ornament: ornament,
                  width: 48,
                  height: 72,
                  tint: colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsNWidgets(3));
    final semantics = tester.ensureSemantics();
    expect(find.semantics.byLabel(RegExp('.+')), findsNothing);
    semantics.dispose();
  });
}
