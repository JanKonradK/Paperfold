import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/widgets/paperfold_library_theme.dart';
import 'package:paperfold/utils/color_scheme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('library and paper components can animate between themes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final paper = colorSchema(Prefs(), context, Brightness.light);
            return Theme(
              data: paper,
              child: Builder(
                builder: (context) {
                  final library = paperfoldLibraryTheme(Theme.of(context));
                  expect(
                    () => ThemeData.lerp(library, paper, 0.5),
                    returnsNormally,
                  );
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('burgundy library keeps gold and body text readable', () async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    final theme = paperfoldLibraryTheme(ThemeData());
    final scheme = theme.colorScheme;
    expect(scheme.surface, PaperfoldTokens.burgundy.ground);
    for (final foreground in [
      scheme.primary,
      scheme.onSurface,
      scheme.onSurfaceVariant,
    ]) {
      expect(
        BookSpine.contrast(foreground, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    }
    for (final surface in [
      scheme.surfaceContainerLowest,
      scheme.surfaceContainerLow,
      scheme.surfaceContainer,
      scheme.surfaceContainerHigh,
      scheme.surfaceContainerHighest,
    ]) {
      for (final ink in [scheme.onSurface, scheme.onSurfaceVariant]) {
        expect(BookSpine.contrast(ink, surface), greaterThanOrEqualTo(4.5));
      }
    }
    final base = ThemeData();
    Prefs().eInkMode = true;
    expect(paperfoldLibraryTheme(base), same(base));
    Prefs().eInkMode = false;
    final dark = ThemeData(
      colorScheme: PaperfoldTokens.colorScheme(Brightness.dark),
    );
    expect(paperfoldLibraryTheme(dark), same(dark));
    Prefs().useBrandTheme = false;
    expect(paperfoldLibraryTheme(base), same(base));
  });

  test('brand chrome keeps saved theme and reader choices intact', () async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    expect(Prefs().themeMode, ThemeMode.light);
    expect(Prefs().appThemeMode, 'burgundy');
    expect(Prefs().readTheme.backgroundColor, 'FFF6F2EA');
    SharedPreferences.setMockInitialValues({
      'themeMode': 'dark',
      'readTheme': '{"backgroundColor":"FF000000","textColor":"FFFFFFFF","backgroundImagePath":""}',
    });
    await Prefs().initPrefs();
    expect(Prefs().themeMode, ThemeMode.dark);
    expect(Prefs().readTheme.backgroundColor, 'FF000000');
  });

  testWidgets('Cream, Burgundy, Dark and System have distinct app surfaces', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'trueDarkMode': false});
    await Prefs().initPrefs();
    Future<ThemeData> themeFor(String mode) async {
      await Prefs().saveThemeModeToPrefs(mode);
      late ThemeData result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              result = paperfoldLibraryTheme(
                colorSchema(Prefs(), context, Brightness.light),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    final cream = await themeFor('light');
    final burgundy = await themeFor('burgundy');
    final dark = await themeFor('dark');
    expect(cream.colorScheme.surface, PaperfoldTokens.light.ground);
    expect(burgundy.colorScheme.surface, PaperfoldTokens.burgundy.ground);
    expect(dark.colorScheme.surface, PaperfoldTokens.darkNearBlack.ground);
    expect(cream.brightness, Brightness.light);
    expect(burgundy.brightness, Brightness.dark);
    expect(dark.brightness, Brightness.dark);
    expect(() => ThemeData.lerp(cream, burgundy, 0.5), returnsNormally);
    expect(() => ThemeData.lerp(burgundy, dark, 0.5), returnsNormally);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    expect(
      (await themeFor('auto')).colorScheme.surface,
      PaperfoldTokens.light.ground,
    );
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    expect(
      (await themeFor('auto')).colorScheme.surface,
      PaperfoldTokens.darkNearBlack.ground,
    );
    expect(Prefs().appThemeMode, 'auto');
    expect(Prefs().readTheme.backgroundColor, 'FFF6F2EA');
    expect(tester.takeException(), isNull);
  });

  test(
    'Burgundy selects the brand palette and eInk keeps the saved choice',
    () async {
      SharedPreferences.setMockInitialValues({'useBrandTheme': false});
      await Prefs().initPrefs();
      await Prefs().saveThemeModeToPrefs('burgundy');
      expect(Prefs().useBrandTheme, isTrue);
      Prefs().eInkMode = true;
      expect(Prefs().appThemeMode, 'burgundy');
      Prefs().eInkMode = false;
      expect(Prefs().appThemeMode, 'burgundy');

      await Prefs().saveThemeToPrefs(Colors.blue.toARGB32());
      expect(Prefs().useBrandTheme, isFalse);
      expect(Prefs().appThemeMode, 'light');
    },
  );
}
