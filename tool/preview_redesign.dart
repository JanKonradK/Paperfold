import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/utils/color_scheme.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/widgets/shelf_home_fixtures.dart';

// Local previews with demonstration books; no database or device access.
// flutter test tool/preview_redesign.dart
void main() {
  testWidgets('renders the redesign at phone and desktop sizes',
      (tester) async {
    final previousShadowSetting = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadowSetting);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
    fakeData = populatedData();
    final titles = ['Rascal Does Not Dream of Santa Claus, Vol. 13',
      'Rascal Does Not Dream of Logical Witch, Vol. 3',
      'Rascal Does Not Dream of Petite Devil Kohai, Vol. 2',
      'Rascal Does Not Dream of a Lost Singer, Vol. 10'];
    for (var i = 0; i < fakeData.readingNow.length; i++) {
      final book = fakeData.readingNow[i];
      book.title = titles[i];
      book.author = 'Hajime Kamoshida, Keji Mizoguchi';
      book.series = 'Rascal Does Not Dream';
      book.volume = ['13', '3', '2', '10'][i];
      book.pageCount = [180, 235, 242, 256][i];
    }
    final boundary = GlobalKey();
    final databaseReady = Completer<void>();
    await tester.runAsync(() async {
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
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
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    addTearDown(
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: newTestOverrides(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          home: Builder(
            builder: (context) => RepaintBoundary(
              key: boundary,
              child: Theme(
                data: colorSchema(Prefs(), context, Brightness.light),
                child: HomePage(databaseReady: databaseReady.future),
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/images/paperfold_wordmark.png'),
          boundary.currentContext!,
        );
        await precacheImage(
            const AssetImage('assets/images/paperfold_paper.jpg'),
            boundary.currentContext!);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('tool/preview/redesign-$name.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('library-phone');
    final stage =
        tester.state<BookcaseState>(find.byType(Bookcase)).activeStage!;
    unawaited(stage.pickUp());
    await capture('book-phone');
    unawaited(stage.putBack());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('navigation-tab-0')));
    await capture('journal-phone');
    await tester.tap(find.byKey(const ValueKey('navigation-tab-2')));
    await capture('more-phone');
    await tester.tap(find.byKey(const ValueKey('navigation-tab-1')));
    tester.view.physicalSize = const Size(1100, 800);
    await capture('library-desktop');
    tester.view.physicalSize = const Size(320, 568);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    await capture('library-large-text');
    debugDisableShadows = previousShadowSetting;
  });
}
