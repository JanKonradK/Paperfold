// The settings tree, after the repair pass.
//
// Each test here stands for one defect that shipped:
//
//   * settings rows printed in the platform default face, because the tile
//     replaced the theme's text style with a bare TextStyle(fontSize: 18);
//   * a one-line row was about 46 dp high, under the 48-and-8 Rule;
//   * E-ink mode wrote 'light' over the reader's own theme mode, on the way
//     out as well as on the way in;
//   * the theme-mode control cached its value in initState and went stale;
//   * a "Bottom Navigator" section offered two switches that nothing read.
//
//   flutter test test/widgets/settings_repair_test.dart

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/settings_page/appearance.dart';
import 'package:paperfold/widgets/settings/settings_tile.dart';
import 'package:paperfold/widgets/settings/theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _face = 'Philosopher';

Widget _host(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: [
      L10n.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: L10n.supportedLocales,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
    ).copyWith(textTheme: ThemeData.light().textTheme.apply(fontFamily: _face)),
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  testWidgets('a settings row takes the theme face, not the platform default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SettingsTile.navigation(
          title: const Text('Theme colour'),
          value: const Text('Paperfold'),
          leading: const Icon(Icons.color_lens),
          onPressed: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final TextStyle title = DefaultTextStyle.of(
      tester.element(find.text('Theme colour')),
    ).style;
    expect(
      title.fontFamily,
      _face,
      reason: 'a bare TextStyle here drops the theme family entirely',
    );

    final TextStyle value = DefaultTextStyle.of(
      tester.element(find.text('Paperfold')),
    ).style;
    expect(value.fontFamily, _face);
  });

  testWidgets('a row carrying both a value and a description shows both', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SettingsTile.navigation(
          title: const Text('Proxy'),
          value: const Text('127.0.0.1:7890'),
          description: const Text('Used for every network request.'),
          onPressed: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('127.0.0.1:7890'), findsOneWidget);
    expect(find.text('Used for every network request.'), findsOneWidget);
  });

  testWidgets('a one-line row still meets the 48 dp minimum', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SettingsTile.switchTile(
          title: const Text('Uniform spines'),
          initialValue: false,
          onToggle: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(SettingsTile)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('a disabled row is disabled rather than merely unresponsive', (
    WidgetTester tester,
  ) async {
    bool toggled = false;

    await tester.pumpWidget(
      _host(
        SettingsTile.switchTile(
          title: const Text('Sync now'),
          enabled: false,
          initialValue: false,
          onToggle: (_) => toggled = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // An IgnorePointer stood here. It swallowed the tap, but the switch still
    // painted and announced itself as an enabled control.
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);

    await tester.tap(find.text('Sync now'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(toggled, isFalse);
  });

  testWidgets('turning E-ink mode on and off leaves the theme mode alone', (
    WidgetTester tester,
  ) async {
    await Prefs().saveThemeModeToPrefs('dark');

    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(const AppearanceSetting()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('E-ink Mode'));
    await tester.pumpAndSettle();
    expect(Prefs().eInkMode, isTrue);
    expect(
      Prefs().themeMode,
      ThemeMode.dark,
      reason: 'E-ink already forces a light brightness in the theme',
    );

    await tester.tap(find.text('E-ink Mode'));
    await tester.pumpAndSettle();
    expect(Prefs().eInkMode, isFalse);
    expect(
      Prefs().themeMode,
      ThemeMode.dark,
      reason: 'the reader gets their own choice back',
    );
  });

  testWidgets('the theme-mode control follows a change made elsewhere', (
    WidgetTester tester,
  ) async {
    await Prefs().saveThemeModeToPrefs('dark');

    await tester.pumpWidget(_host(const ChangeThemeMode()));
    await tester.pumpAndSettle();

    SegmentedButton<String> button() => tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );

    expect(button().selected, <String>{'dark'});

    // Nothing rebuilds this widget from above; the preference changes and the
    // control has to notice on its own.
    await Prefs().saveThemeModeToPrefs('light');
    await tester.pumpAndSettle();

    expect(button().selected, <String>{
      'light',
    }, reason: 'the mode used to be cached in initState');
  });

  testWidgets(
    'appearance no longer offers the dead bottom-navigator switches',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_host(const AppearanceSetting()));
      await tester.pumpAndSettle();

      // Nothing has read either preference since the navigation became a fixed
      // Journal / Library / More set.
      expect(find.text('Bottom Navigator'), findsNothing);
    },
  );

  testWidgets('the language picker marks the language in use', (
    WidgetTester tester,
  ) async {
    await Prefs().saveLocaleToPrefs('de');

    await tester.pumpWidget(
      _host(
        Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showLanguagePickerDialog(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final Finder marked = find.ancestor(
      of: find.text('Deutsch'),
      matching: find.byType(Semantics),
    );
    expect(marked, findsWidgets);
    expect(
      find.byIcon(Icons.check),
      findsOneWidget,
      reason: 'exactly one language is the current one',
    );
  });
}
