import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/paperfold_logo_mark.dart';

void main() {
  Widget host(Brightness brightness, Widget child) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: PaperfoldTokens.colorScheme(brightness),
      ),
      home: Scaffold(body: Center(child: child)),
    );
  }

  for (final Brightness brightness in Brightness.values) {
    testWidgets('the mark takes the ${brightness.name} accent',
        (WidgetTester tester) async {
      final ColorScheme scheme = PaperfoldTokens.colorScheme(brightness);

      await tester.pumpWidget(
        host(brightness, const PaperfoldLogoMark(size: 48)),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final SvgPicture wreath = tester.widget(find.byType(SvgPicture));
      // The accent swaps between themes, and it swaps in the theme, not here.
      expect(
        wreath.colorFilter,
        ColorFilter.mode(scheme.primary, BlendMode.srcIn),
      );
    });
  }

  testWidgets('the mark is decorative until it is given a label',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      host(Brightness.light, const PaperfoldLogoMark(size: 48)),
    );
    await tester.pumpAndSettle();

    final SemanticsHandle handle = tester.ensureSemantics();
    expect(find.semantics.byLabel(RegExp('.+')), findsNothing);
    handle.dispose();
  });

  testWidgets('the application icon keeps the cover colours',
      (WidgetTester tester) async {
    final GlobalKey boundary = GlobalKey();
    await tester.pumpWidget(
      host(
        Brightness.light,
        RepaintBoundary(
          key: boundary,
          child: const PaperfoldAppIcon(size: 108),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The ground is painted rather than filled — it is bookcloth under a foil
    // rule, not one flat colour — so the assertion is on the pixels the card
    // actually produces, not on the widget that produced them.
    final _Raster card = await _rasterise(tester, boundary);
    final Color corner = card.pixel(4, 4);
    expect(corner.a, 1.0, reason: 'the card is opaque to its own edge');
    // The cloth is lit, so the corner is a shade of the cover ground rather
    // than the token exactly. It must still read as that burgundy: red first,
    // and no channel wandering off towards another hue.
    expect(corner.r, greaterThan(corner.g));
    expect(corner.r, greaterThan(corner.b));
    expect(
      (corner.r - PaperfoldTokens.cover.ground.r).abs(),
      lessThan(0.25),
      reason: 'the lighting shades the cover colour, it does not replace it',
    );

    final SvgPicture wreath = tester.widget(find.byType(SvgPicture));
    // The icon never reads the theme. A launcher shows one icon, whatever the
    // reader has the application set to.
    expect(
      wreath.colorFilter,
      ColorFilter.mode(PaperfoldTokens.cover.foil, BlendMode.srcIn),
    );
  });

  testWidgets('the adaptive shapes carry no ground',
      (WidgetTester tester) async {
    for (final PaperfoldAppIconShape shape in <PaperfoldAppIconShape>[
      PaperfoldAppIconShape.adaptiveForeground,
      PaperfoldAppIconShape.monochrome,
    ]) {
      final GlobalKey boundary = GlobalKey();
      await tester.pumpWidget(
        host(
          Brightness.light,
          RepaintBoundary(
            key: boundary,
            child: PaperfoldAppIcon(size: 108, shape: shape),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final _Raster raster = await _rasterise(tester, boundary);
      expect(
        raster.pixel(4, 4).a,
        0.0,
        reason: '${shape.name} must leave the launcher to draw the ground',
      );
    }
  });
}

/// Rasterises whatever [PaperfoldAppIcon] is currently mounted.
///
/// Engine work, so it runs inside `runAsync`. Awaited outside it, `toImage`
/// does not fail — it stalls until the test's own ten-minute timeout.
/// The rasterised pixels of the [PaperfoldAppIcon] under [key].
///
/// Both the rasterise and the read happen inside one `runAsync`. Awaited
/// outside it, `toImage` and `toByteData` do not fail — they stall until the
/// test's own ten-minute timeout, which reads as a hang rather than an error.
Future<_Raster> _rasterise(WidgetTester tester, GlobalKey key) async {
  final RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late _Raster raster;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage();
    final ByteData data = (await image.toByteData())!;
    raster = _Raster(width: image.width, bytes: data);
    image.dispose();
  });
  return raster;
}

class _Raster {
  const _Raster({required this.width, required this.bytes});

  final int width;
  final ByteData bytes;

  Color pixel(int x, int y) {
    final int offset = (y * width + x) * 4;
    return Color.fromARGB(
      bytes.getUint8(offset + 3),
      bytes.getUint8(offset),
      bytes.getUint8(offset + 1),
      bytes.getUint8(offset + 2),
    );
  }
}
