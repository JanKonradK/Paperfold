import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/settings_page/settings_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget host({double scale = 1, TextDirection direction = TextDirection.ltr}) =>
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          L10n.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: L10n.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(412, 915),
            textScaler: TextScaler.linear(scale),
          ),
          child: Directionality(
            textDirection: direction,
            child: const SettingsHomePage(),
          ),
        ),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });
  testWidgets('settings index retains its groups and switches the theme', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsWidgets);
    expect(find.text('Reading'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('theme-swatch-dark')));
    await tester.pumpAndSettle();
    expect(Prefs().appThemeMode, 'dark');
    for (final group in [
      'Library & books',
      'Journal',
      'Sync & backup',
      'Catalogs',
      'About Paperfold',
    ]) {
      await tester.scrollUntilVisible(
        find.text(group),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(group), findsOneWidget);
    }
  });
  for (final direction in TextDirection.values) {
    testWidgets('settings supports 200 percent text in $direction', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(scale: 2, direction: direction));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('About Paperfold'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('eInk theme swatches preserve the saved choice', (tester) async {
    await Prefs().saveThemeModeToPrefs('dark');
    Prefs().eInkMode = true;
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-swatch-burgundy')));
    await tester.pumpAndSettle();
    expect(Prefs().appThemeMode, 'dark');
  });
}
