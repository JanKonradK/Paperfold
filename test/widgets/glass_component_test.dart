import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/paperfold_glass_slider.dart';
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
  };

  test(
    'glass material maintains 4.5:1 over black and white in all brand themes',
    () {
      for (final MapEntry(key: name, value: scheme) in schemes.entries) {
        final style = PaperfoldGlassStyle.fromScheme(scheme);
        expect(
          style.worstCaseContrast,
          greaterThanOrEqualTo(PaperfoldGlassStyle.minimumContrast),
          reason: '$name translucent path',
        );
        expect(
          style.solidContrast,
          greaterThanOrEqualTo(PaperfoldGlassStyle.minimumContrast),
          reason: '$name solid fallback',
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
    'glass disables blur for high contrast and reduced motion',
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
                  child: PaperfoldGlassSurface(child: Text('Glass')),
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

  testWidgets(
    'glass slider has slider semantics, keyboard input, a 48 dp target, and RTL',
    (tester) async {
      double value = 170;
      var direction = TextDirection.ltr;

      Future<void> pumpSlider() {
        return tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: Center(
                  child: StatefulBuilder(
                    builder: (context, setState) => SizedBox(
                      width: 300,
                      child: PaperfoldGlassSlider(
                        value: value,
                        min: 80,
                        max: 260,
                        divisions: 18,
                        semanticLabel: 'Book cover width',
                        semanticFormatterCallback: (value) =>
                            value.toStringAsFixed(0),
                        onChanged: (nextValue) {
                          setState(() => value = nextValue);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      await pumpSlider();
      expect(
        tester.getSize(find.byType(PaperfoldGlassSlider)).height,
        greaterThanOrEqualTo(48),
      );

      final semantics = tester.ensureSemantics();
      final node = tester.getSemantics(find.byType(PaperfoldGlassSlider));
      final data = node.getSemanticsData();
      expect(data.label, 'Book cover width');
      expect(data.value, '170');
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, 180);

      direction = TextDirection.rtl;
      value = 170;
      await pumpSlider();
      await tester.drag(find.byType(Slider), const Offset(80, 0));
      await tester.pump();
      expect(value, lessThan(170));
      semantics.dispose();
    },
  );
}
