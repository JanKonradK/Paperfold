import 'dart:io';
import 'dart:ui' as ui;

// Renders the whole Library page to `tool/preview/page-library.png`.
//
//   flutter test tool/preview_library_page.dart
//
// The shelf has its own sheet next door, and the book model one beyond that.
// This one is about what those two cannot show: the bar over the shelf, the
// signpost under it, and whether anything on the page lands on anything else.

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/widgets/shelf_home_fixtures.dart';

void main() {
  final boundary = GlobalKey();

  setUp(() async {
    // This file is only ever run through `flutter test`, the same as the
    // other preview generators next to it.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  testWidgets('renders the Library page', (tester) async {
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
    Directory('tool/preview').createSync(recursive: true);
    fakeData = populatedData();
    await tester.binding.setSurfaceSize(const Size(412, 915));
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          overrides: newTestOverrides(),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
            supportedLocales: L10n.supportedLocales,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: PaperfoldTokens.colorScheme(Brightness.dark),
              fontFamily: PaperfoldTypeTokens.journalFamily,
            ),
            home: const ShelfHomePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('tool/preview/page-library.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
