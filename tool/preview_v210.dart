// Demo data only. Run: flutter test tool/preview_v210.dart --concurrency=1
// Operate: choose a binding, understand the book, and reach Read without a hunt.
// Preserve Paperfold's reference palette and lettering. Cream is warm daylight;
// Burgundy is the signature evening surface; Dark is warm raspberry-black.
// The selected book has a compact summary, labeled actions, and a fixed Read
// control. Real covers, text scaling, RTL, and native Back remain first-class.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart' show navigatorKey;
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/providers/random_highlight_provider.dart';
import 'package:paperfold/providers/reading_completion_provider.dart';
import 'package:paperfold/providers/reading_duration_trend_provider.dart';
import 'package:paperfold/providers/reading_streak_provider.dart';
import 'package:paperfold/providers/statictics_summary_value.dart';
import 'package:paperfold/utils/color_scheme.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';
import 'package:paperfold/widgets/paperfold_library_theme.dart';
import 'package:paperfold/widgets/settings/theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/widgets/shelf_home_fixtures.dart';

class PreviewSummary extends StaticticsSummaryValue {
  @override
  Future<int> build(StatisticType type) async => switch (type) {
    StatisticType.totalBooks => 7,
    StatisticType.totalDates => 18,
    StatisticType.totalNotes => 4,
  };
}

class PreviewStreak extends ReadingStreak {
  @override
  Future<ReadingStreakData> build() async => ReadingStreakData(
    currentStreak: 4,
    longestStreak: 12,
    lastReadingDay: DateTime.now(),
  );
}

class PreviewHighlight extends RandomHighlight {
  @override
  Future<RandomHighlightData?> build() async => null;
}

class PreviewCompletion extends ReadingCompletion {
  @override
  Future<List<Book>> build() async => const [];
}

class PreviewDuration extends ReadingDurationTrend {
  @override
  Future<ReadingDurationTrendData> build() async =>
      ReadingDurationTrendData.mock();
}

void main() {
  testWidgets('capture all three themes and book selection', (tester) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({'trueDarkMode': false});
    await Prefs().initPrefs();
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    var previewFallback = <String>[];
    await tester.runAsync(() async {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      for (final (family, files) in [
        (
          PaperfoldTypeTokens.journalFamily,
          ['Philosopher-Regular', 'Philosopher-Bold'],
        ),
        (
          PaperfoldTypeTokens.chromeFamily,
          ['SourceSans3-Regular', 'SourceSans3-SemiBold'],
        ),
      ]) {
        final loader = FontLoader(family);
        for (final name in files) {
          loader.addFont(rootBundle.load('assets/fonts/$name.ttf'));
        }
        await loader.load();
      }
      // Flutter tests have no Android system fonts. Use an installed Arabic
      // font for capture only; this file is not part of the shipped app.
      final arabicFont = File('C:/Windows/Fonts/tahoma.ttf');
      if (await arabicFont.exists()) {
        await (FontLoader('ArabicPreview')..addFont(
              Future.value(
                ByteData.sublistView(await arabicFont.readAsBytes()),
              ),
            ))
            .load();
        previewFallback = ['ArabicPreview'];
      }
    });
    ThemeData captureTheme(ThemeData theme) => theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamilyFallback: previewFallback),
    );
    fakeData = populatedData();
    fakeData.readingNow[0].readingPercentage = 0.42;
    final boundary = GlobalKey();
    final navigator = navigatorKey;
    final overrides = [
      ...newTestOverrides(),
      for (final type in StatisticType.values)
        staticticsSummaryValueProvider(type).overrideWith(PreviewSummary.new),
      readingStreakProvider.overrideWith(PreviewStreak.new),
      randomHighlightProvider.overrideWith(PreviewHighlight.new),
      readingCompletionProvider.overrideWith(PreviewCompletion.new),
      readingDurationTrendProvider.overrideWith(PreviewDuration.new),
    ];
    final scale = ValueNotifier(1.0);
    final locale = ValueNotifier(const Locale('en'));
    final home = HomePage(databaseReady: Completer<void>().future);
    addTearDown(scale.dispose);
    addTearDown(locale.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 850);
    addTearDown(tester.view.reset);

    await tester.binding.setSurfaceSize(const Size(412, 850));
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: overrides,
        child: ListenableBuilder(
          listenable: Listenable.merge([Prefs(), locale]),
          builder: (context, _) => MaterialApp(
            navigatorKey: navigator,
            debugShowCheckedModeBanner: false,
            locale: locale.value,
            localizationsDelegates: [
              L10n.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: L10n.supportedLocales,
            themeMode: Prefs().themeMode,
            theme: captureTheme(
              paperfoldLibraryTheme(
                paperfoldComponentTheme(
                  ThemeData(
                    colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
                  ),
                ),
              ),
            ),
            darkTheme: captureTheme(
              paperfoldComponentTheme(
                ThemeData(
                  colorScheme: PaperfoldTokens.colorScheme(
                    Brightness.dark,
                    trueBlack: false,
                  ),
                ),
              ),
            ),
            builder: (context, child) => ValueListenableBuilder(
              valueListenable: scale,
              builder: (context, value, _) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(value)),
                child: RepaintBoundary(
                  key: boundary,
                  child: MaterialUiCompatibilityBridge(child: child!),
                ),
              ),
            ),
            home: home,
          ),
        ),
      ),
    );

    Future<void> capture(String name, Size size, {double textScale = 1}) async {
      tester.view.physicalSize = size;
      await tester.binding.setSurfaceSize(size);
      scale.value = textScale;
      await tester.pumpAndSettle();
      // The legacy localization bridge loads delegates outside the fake clock.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/images/paperfold_wordmark.png'),
          boundary.currentContext!,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        Directory('tool/preview').createSync(recursive: true);
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('tool/preview/v210-$name.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> selectDestination(int index) async {
      const labels = ['Journal', 'Library', 'Statistics', 'Settings'];
      final rail = find.byType(NavigationRail);
      await tester.tap(
        rail.evaluate().isEmpty
            ? find.byKey(ValueKey('navigation-tab-$index'))
            : find.descendant(of: rail, matching: find.text(labels[index])),
      );
      await tester.pumpAndSettle();
    }

    for (final mode in ['light', 'burgundy', 'dark']) {
      await Prefs().saveThemeModeToPrefs(mode);
      Prefs().shelfCoverView = false;
      await capture('$mode-spines', const Size(412, 850));
      final stage = tester.state<ShelfStageState>(
        find.byType(ShelfStage).first,
      );
      await stage.pickUpAt(0);
      await capture('$mode-book', const Size(412, 850));
      if (mode == 'burgundy') {
        await capture('book-wide', const Size(1100, 800));
        await capture('book-large-text', const Size(320, 720), textScale: 2);
      }
      await stage.putBack();
      Prefs().shelfCoverView = true;
      await capture('$mode-covers', const Size(412, 850));
      for (final (index, name) in [
        (0, 'journal'),
        (2, 'statistics'),
        (3, 'settings'),
      ]) {
        await selectDestination(index);
        await capture('$mode-$name', const Size(412, 850));
      }
      await selectDestination(1);
    }
    await Prefs().saveThemeModeToPrefs('light');
    Prefs().shelfCoverView = false;
    locale.value = const Locale('ar');
    await capture('arabic-library', const Size(412, 850));
    await tester
        .state<ShelfStageState>(find.byType(ShelfStage).first)
        .pickUpAt(0);
    await capture('arabic-book', const Size(412, 850));
    await tester
        .state<ShelfStageState>(find.byType(ShelfStage).first)
        .putBack();
    locale.value = const Locale('en');
    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(L10n.of(context).settingsAppearanceTheme),
            ),
            body: const Padding(
              padding: EdgeInsets.all(24),
              child: ChangeThemeMode(),
            ),
          ),
        ),
      ),
    );
    for (final mode in ['light', 'burgundy', 'dark']) {
      await Prefs().saveThemeModeToPrefs(mode);
      await capture('$mode-choices', const Size(412, 720));
    }
    locale.value = const Locale('de');
    await capture('theme-large-text', const Size(320, 720), textScale: 2);
    debugDisableShadows = true;
  });
}
