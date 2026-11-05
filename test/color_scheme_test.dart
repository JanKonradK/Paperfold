import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/utils/color_scheme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('brand typography preserves theme and reading preferences',
      (tester) async {
    Future<ThemeData> themeFor(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      await Prefs().initPrefs();
      late ThemeData theme;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          theme = colorSchema(Prefs(), context, Brightness.light);
          return const SizedBox.shrink();
        }),
      ));
      return theme;
    }

    final paper = await themeFor({'themeMode': 'light'});
    expect(paper.scaffoldBackgroundColor, PaperfoldTokens.light.ground);
    expect(paper.textTheme.headlineLarge?.fontFamily,
        PaperfoldTypeTokens.journalFamily);
    expect(paper.textTheme.headlineLarge?.fontStyle, FontStyle.normal);
    expect(paper.textTheme.bodyMedium?.fontFamily,
        PaperfoldTypeTokens.chromeFamily);
    expect(paper.textTheme.labelLarge?.fontFamily,
        PaperfoldTypeTokens.chromeFamily);

    for (final trueBlack in [false, true]) {
      final dark = await themeFor({
        'themeMode': 'dark',
        'trueDarkMode': trueBlack,
      });
      expect(
        dark.scaffoldBackgroundColor,
        PaperfoldTokens.pagePalette(Brightness.dark, trueBlack: trueBlack)
            .ground,
      );
    }

    final custom = await themeFor({
      'themeMode': 'light',
      'useBrandTheme': false,
      'themeColor': Colors.blue.toARGB32(),
    });
    expect(custom.colorScheme.primary,
        ColorScheme.fromSeed(seedColor: Colors.blue).primary);

    final eInk = await themeFor({
      'themeMode': 'dark',
      'useBrandTheme': false,
      'themeColor': Colors.blue.toARGB32(),
      'eInkMode': true,
    });
    expect(eInk.brightness, Brightness.light);
    expect(eInk.scaffoldBackgroundColor, Colors.white);
    expect(eInk.colorScheme.primary, Colors.black);
    expect(eInk.cardTheme.color, Colors.white);
  });
}
