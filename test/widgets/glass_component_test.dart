import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';

void main() {
  final schemes = <String, ColorScheme>{
    'light': PaperfoldTokens.colorScheme(Brightness.light),
    'true-black dark': PaperfoldTokens.colorScheme(
      Brightness.dark,
      trueBlack: true,
    ),
    'near-black dark': PaperfoldTokens.colorScheme(
      Brightness.dark,
      trueBlack: false,
    ),
    'custom seed': ColorScheme.fromSeed(seedColor: Colors.blue),
  };

  test(
    'matte material stays opaque and readable in brand and custom themes',
    () {
      for (final MapEntry(key: name, value: scheme) in schemes.entries) {
        final style = PaperfoldGlassStyle.fromScheme(scheme);
        expect(style.tint.a, 1, reason: '$name hides the content behind it');
        expect(
          style.worstCaseContrast,
          greaterThanOrEqualTo(PaperfoldGlassStyle.minimumContrast),
          reason: '$name over any background',
        );
        expect(
          style.solidContrast,
          greaterThanOrEqualTo(PaperfoldGlassStyle.minimumContrast),
          reason: '$name matte surface',
        );
        expect(
          PaperfoldGlassStyle.contrastRatio(
            scheme.onPrimaryContainer,
            scheme.primaryContainer,
          ),
          greaterThanOrEqualTo(PaperfoldGlassStyle.minimumContrast),
          reason: '$name selected navigation pill',
        );
      }
    },
  );

  testWidgets(
    'floating glass blurs only when the visual policy allows it',
    (tester) async {
      Future<void> pumpSurface({
        bool highContrast = false,
        bool disableAnimations = false,
      }) {
        return tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                highContrast: highContrast,
                disableAnimations: disableAnimations,
              ),
              child: const Center(
                child: SizedBox(
                  width: 180,
                  height: 48,
                  child: PaperfoldGlassSurface(child: Text('Control')),
                ),
              ),
            ),
          ),
        );
      }

      await pumpSurface();
      expect(
        find.descendant(
          of: find.byType(PaperfoldGlassSurface),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(PaperfoldGlassSurface),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );

      await pumpSurface(highContrast: true);
      expect(find.byType(BackdropFilter), findsNothing);

      await pumpSurface(disableAnimations: true);
      expect(find.byType(BackdropFilter), findsNothing);
    },
  );
}
