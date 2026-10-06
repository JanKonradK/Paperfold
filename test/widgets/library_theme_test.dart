import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/widgets/paperfold_library_theme.dart';
import 'package:paperfold/utils/color_scheme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('library and paper components can animate between themes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      final paper = colorSchema(Prefs(), context, Brightness.light);
      return Theme(
        data: paper,
        child: Builder(builder: (context) {
          final library = paperfoldLibraryTheme(Theme.of(context));
          expect(() => ThemeData.lerp(library, paper, 0.5), returnsNormally);
          return const SizedBox.shrink();
        }),
      );
    })));
    expect(tester.takeException(), isNull);
  });

  test('burgundy library keeps gold and body text readable', () async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    final theme = paperfoldLibraryTheme(ThemeData());
    final scheme = theme.colorScheme;
    expect(scheme.surface, PaperfoldTokens.cover.ground);
    for (final foreground in [
      scheme.primary,
      scheme.onSurface,
      scheme.onSurfaceVariant
    ]) {
      expect(BookSpine.contrast(foreground, scheme.surface),
          greaterThanOrEqualTo(4.5));
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
    final dark =
        ThemeData(colorScheme: PaperfoldTokens.colorScheme(Brightness.dark));
    expect(paperfoldLibraryTheme(dark), same(dark));
    Prefs().useBrandTheme = false;
    expect(paperfoldLibraryTheme(base), same(base));
  });

  test('brand chrome keeps saved theme and reader choices intact', () async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    expect(Prefs().themeMode, ThemeMode.light);
    expect(Prefs().readTheme.backgroundColor, 'FFF6F2EA');
    SharedPreferences.setMockInitialValues({
      'themeMode': 'dark',
      'readTheme':
          '{"backgroundColor":"FF000000","textColor":"FFFFFFFF","backgroundImagePath":""}',
    });
    await Prefs().initPrefs();
    expect(Prefs().themeMode, ThemeMode.dark);
    expect(Prefs().readTheme.backgroundColor, 'FF000000');
  });
}
