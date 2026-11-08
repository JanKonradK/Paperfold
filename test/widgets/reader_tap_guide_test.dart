import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/reading_page/more_settings/page_turning/diagram.dart';
import 'package:paperfold/widgets/reading_page/more_settings/page_turning/types_and_icons.dart';
import 'package:paperfold/widgets/reading_page/reader_tap_guide.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });

  Future<void> pumpGuide(
    WidgetTester tester, {
    Size size = const Size(320, 640),
    double dpr = 1,
    double scale = 1,
    bool ready = true,
    bool reducedMotion = false,
    TextDirection direction = TextDirection.ltr,
    GlobalKey<ReaderTapGuideGateState>? gateKey,
    VoidCallback? onPageTap,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          L10n.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedMotion,
            ),
            child: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: ReaderTapGuideGate(
                  key: gateKey,
                  ready: ready,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onPageTap,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('first open waits for load, dismissal persists, replay works', (
    tester,
  ) async {
    final key = GlobalKey<ReaderTapGuideGateState>();
    await pumpGuide(tester, ready: false, gateKey: key);
    expect(find.byType(ReaderTapGuide), findsNothing);
    await pumpGuide(tester, gateKey: key);
    expect(find.text('Got it'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(Prefs().readerGuideSeen, isTrue);
    expect(find.byType(ReaderTapGuide), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await Prefs().initPrefs();
    await pumpGuide(tester, gateKey: key);
    expect(find.byType(ReaderTapGuide), findsNothing);
    key.currentState!.show();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderTapGuide), findsOneWidget);
  });

  testWidgets('tap anywhere dismisses without turning the page', (
    tester,
  ) async {
    var pageTaps = 0;
    await pumpGuide(tester, onPageTap: () => pageTaps++);
    await tester.tapAt(const Offset(4, 300));
    await tester.pumpAndSettle();
    expect(Prefs().readerGuideSeen, isTrue);
    expect(find.byType(ReaderTapGuide), findsNothing);
    expect(pageTaps, 0);
    await tester.tapAt(const Offset(4, 300));
    expect(pageTaps, 1);
  });

  for (final layout in [0, 1, 2, 3, 4]) {
    testWidgets('layout $layout draws three merged regions', (tester) async {
      Prefs().pageTurningType = layout;
      await pumpGuide(tester);
      final regions = readerGuideRegions(currentPageTurningActions());
      expect(regions.length, 3);
      expect(regions.expand((region) => region.cells).toSet(), {
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
      });
      for (final region in regions) {
        expect(
          find.byKey(ValueKey('guide-region-${region.cells.first}')),
          findsOneWidget,
        );
        expect(
          region.cells.every(
            (cell) => pageTurningTypes[layout][cell] == region.action,
          ),
          isTrue,
        );
      }
      expect(find.text('Previous page'), findsOneWidget);
      expect(find.text('Next page'), findsOneWidget);
      expect(find.text('Menu'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('effective actions preserve swap and custom layout', () {
    Prefs().swapPageTurnArea = true;
    expect(currentPageTurningActions()[0], PageTurningType.next);
    Prefs().pageTurnMode = 'custom';
    Prefs().customPageTurnConfig = [3, 3, 3, 2, 2, 2, 1, 1, 1];
    expect(currentPageTurningActions()[0], PageTurningType.menu);
    expect(currentPageTurningActions()[3], PageTurningType.prev);
  });

  testWidgets('RTL arrows and accessible zones; reduced motion is still', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpGuide(tester, direction: TextDirection.rtl, reducedMotion: true);
    final prev = find.byKey(const ValueKey('guide-region-0'));
    expect(
      find.descendant(of: prev, matching: find.byIcon(Icons.arrow_forward)),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Previous page'), findsOneWidget);
    expect(find.bySemanticsLabel('Next page'), findsOneWidget);
    expect(find.bySemanticsLabel('Menu'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(FilledButton)),
      matchesSemantics(
        label: 'Got it',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    expect(tester.binding.transientCallbackCount, 0);
    semantics.dispose();
  });

  for (final size in [
    const Size(320, 640),
    const Size(412, 915),
    const Size(640, 320),
    const Size(915, 412),
    const Size(2800, 1752),
    const Size(1752, 2800),
  ]) {
    testWidgets('no overflow at $size and 200% text', (tester) async {
      final dpr = size.width >= 1752 ? 2.25 : 1.0;
      for (var layout = 0; layout < pageTurningTypes.length; layout++) {
        Prefs().pageTurningType = layout;
        await pumpGuide(tester, size: size, dpr: dpr, scale: 2);
        expect(tester.takeException(), isNull, reason: 'layout $layout');
        expect(find.text('Got it').hitTestable(), findsOneWidget);
      }
    });
  }
}
