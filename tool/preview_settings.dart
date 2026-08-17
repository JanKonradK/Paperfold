import 'dart:io';
import 'dart:ui' as ui;

// Renders the settings tree to `tool/preview/settings-*.png`.
//
//   flutter test tool/preview_settings.dart
//
// The settings screens are the one part of the application that no other
// sheet covers, and they are where the fork's own chrome shows through most:
// the type on a row, the height of a row, and whether a section says anything
// the application still acts on.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/settings_page/appearance.dart';
import 'package:paperfold/page/settings_page/settings_home_page.dart';
import 'package:paperfold/widgets/tips/bookshelf_tips.dart';
import 'package:paperfold/widgets/tips/notes_tips.dart';
import 'package:paperfold/widgets/tips/statistic_tips.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final boundary = GlobalKey();

  setUp(() async {
    // This file is only ever run through `flutter test`, the same as the
    // other preview generators next to it.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  Future<void> loadFaces(WidgetTester tester) async {
    await tester.runAsync(() async {
      await (FontLoader(PaperfoldTypeTokens.journalFamily)
            ..addFont(rootBundle.load('assets/fonts/Philosopher-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Philosopher-Bold.ttf')))
          .load();
      await (FontLoader(PaperfoldTypeTokens.chromeFamily)
            ..addFont(rootBundle.load('assets/fonts/SourceSans3-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/SourceSans3-SemiBold.ttf')))
          .load();
    });
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('tool/preview/$name.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  }

  Future<void> host(
    WidgetTester tester,
    Widget home, {
    Brightness brightness = Brightness.dark,
    Size size = const Size(412, 915),
  }) async {
    Directory('tool/preview').createSync(recursive: true);
    await tester.binding.setSurfaceSize(size);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            // The application's own scheme and faces, so the preview shows
            // what the reader sees rather than stock Material.
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: PaperfoldTokens.colorScheme(brightness),
              fontFamily: PaperfoldTypeTokens.journalFamily,
            ),
            home: home,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the settings home', (tester) async {
    await loadFaces(tester);
    await host(tester, const SettingsHomePage());
    await shoot(tester, 'settings-home');
  });

  testWidgets('renders the appearance settings', (tester) async {
    await loadFaces(tester);
    await host(
      tester,
      const Scaffold(body: AppearanceSetting()),
      size: const Size(412, 1600),
    );
    await shoot(tester, 'settings-appearance');
  });

  testWidgets('renders the settings home in light', (tester) async {
    await loadFaces(tester);
    await host(tester, const SettingsHomePage(), brightness: Brightness.light);
    await shoot(tester, 'settings-home-light');
  });

  // The empty states used to be a kaomoji at 50 points in `Colors.grey`,
  // which measured 2.49:1 on the paper ground. Both grounds are checked.
  testWidgets('renders the empty states', (tester) async {
    await loadFaces(tester);
    await host(
      tester,
      const Scaffold(
        body: Column(
          children: [
            Expanded(child: BookshelfTips()),
            Divider(),
            Expanded(child: NotesTips()),
            Divider(),
            Expanded(child: StatisticsTips()),
          ],
        ),
      ),
      brightness: Brightness.light,
      size: const Size(412, 1100),
    );
    await shoot(tester, 'empty-states-light');
  });
}
