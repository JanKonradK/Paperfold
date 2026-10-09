// Demo data only. Run: flutter test tool/preview_v200.dart --concurrency=1
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
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/page/opds/opds_catalogs_page.dart';
import 'package:paperfold/providers/opds.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/models/opds_catalog.dart';
import 'package:paperfold/utils/color_scheme.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/widgets/paperfold_library_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/widgets/shelf_home_fixtures.dart';

class _Catalogs extends OpdsCatalogsController {
  @override
  Future<List<OpdsCatalog>> build() async => [];
}

void main() {
  testWidgets('render 2.0 library and online catalog states', (tester) async {
    // This renderer runs only under flutter test.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    final previousDocumentPath = documentPath;
    documentPath = Directory.current.path;
    addTearDown(() => documentPath = previousDocumentPath);
    await tester.runAsync(() async {
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
      for (final (family, files) in [
        (
          PaperfoldTypeTokens.journalFamily,
          ['Philosopher-Regular', 'Philosopher-Bold']
        ),
        (
          PaperfoldTypeTokens.chromeFamily,
          ['SourceSans3-Regular', 'SourceSans3-SemiBold']
        ),
      ]) {
        final loader = FontLoader(family);
        for (final name in files) {
          loader.addFont(rootBundle.load('assets/fonts/$name.ttf'));
        }
        await loader.load();
      }
    });
    final original = populatedData();
    // The user's supplied bitmap exercises image decoding beside missing art.
    // This fixture does not add or change a book in the user's library.
    original.readingNow[0] = original.readingNow[0].copyWith(
      title: 'Paperfold',
      author: 'Demo collection',
      coverPath: 'assets/images/paperfold_cover.jpg',
      readingPercentage: 0.42,
    );
    fakeData = ShelfHomeData(
      readingNow: original.readingNow,
      favourites: original.favourites,
      finished: original.finished,
      toBeRead: original.toBeRead,
      booksToBuy: original.booksToBuy,
    );
    final boundary = GlobalKey();
    final navigator = GlobalKey<NavigatorState>();
    final overrides = newTestOverrides()
      ..add(opdsCatalogsProvider.overrideWith(_Catalogs.new));
    final scale = ValueNotifier(1.0);
    addTearDown(scale.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.binding.setSurfaceSize(const Size(412, 850));
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        navigatorKey: navigator,
        debugShowCheckedModeBanner: false,
        locale: const Locale('en'),
        localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: L10n.supportedLocales,
        theme: paperfoldLibraryTheme(paperfoldComponentTheme(ThemeData(
          useMaterial3: true,
          colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
          fontFamily: PaperfoldTypeTokens.chromeFamily,
        ))),
        builder: (context, child) => ValueListenableBuilder(
          valueListenable: scale,
          builder: (context, value, _) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(value)),
            child: RepaintBoundary(key: boundary, child: child!),
          ),
        ),
        home: HomePage(databaseReady: Completer<void>().future),
      ),
    ));

    Future<void> capture(String name, Size size,
        {bool covers = false, double textScale = 1}) async {
      await tester.binding.setSurfaceSize(size);
      scale.value = textScale;
      Prefs().shelfCoverView = covers;
      await tester.pumpAndSettle();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        Directory('tool/preview').createSync(recursive: true);
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('tool/preview/v200-$name.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('spines-phone', const Size(412, 850));
    await capture('covers-phone', const Size(412, 850), covers: true);
    await capture('covers-wide', const Size(1100, 800), covers: true);
    await capture('covers-large-text', const Size(320, 720),
        covers: true, textScale: 2);
    scale.value = 1;
    await tester.binding.setSurfaceSize(const Size(412, 850));
    unawaited(navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => const OpdsCatalogsPage())));
    await capture('online-phone', const Size(412, 850));
    await capture('online-large-text', const Size(320, 720), textScale: 2);
    // Flutter checks this flag before addTearDown callbacks run.
    debugDisableShadows = true;
  });
}
