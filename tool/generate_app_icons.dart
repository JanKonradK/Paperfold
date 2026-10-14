// Renders the master application icon files from [PaperfoldAppIcon].
//
// Run it when the mark, the monogram or the cover colours change:
//
//   flutter test tool/generate_app_icons.dart
//   dart run flutter_launcher_icons
//
// The first command writes the three master PNG files under `tool/icon/`. The
// second cuts every platform icon from them.
//
// It is a test rather than a script because the icon is a Flutter widget: it
// needs a real engine to lay out the font and to rasterise the ornament SVG,
// and `flutter test` is the cheapest way to get one without a device.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/paperfold_logo_mark.dart';

/// Every store and launcher takes its cut from a 1024 px master.
const double _masterSide = 1024;

/// The masters live beside the generator, not under `assets/`. They are build
/// input for flutter_launcher_icons, and nothing in the application loads them,
/// so shipping them in the package would be dead weight.
const Map<PaperfoldAppIconShape, String> _outputs =
    <PaperfoldAppIconShape, String>{
  PaperfoldAppIconShape.card: 'tool/icon/paperfold_icon.png',
  PaperfoldAppIconShape.adaptiveForeground:
      'tool/icon/paperfold_icon_foreground.png',
  PaperfoldAppIconShape.monochrome: 'tool/icon/paperfold_icon_monochrome.png',
};

void main() {
  // One test, not three. The engine work below has to run on the real event
  // loop, and each `runAsync` hop is far more expensive than a pump.
  testWidgets('writes the master application icons', (WidgetTester tester) async {
    // A widget test ships no fonts, so the monogram would render as boxes and
    // the failure would only show in the written file.
    await (FontLoader(PaperfoldTypeTokens.journalFamily)
          ..addFont(rootBundle.load('assets/fonts/Philosopher-Bold.ttf')))
        .load();
    // The wordmark is Source Sans 3. Without it the name renders as tofu, and
    // the only place that shows is the written file.
    await (FontLoader(PaperfoldTypeTokens.chromeFamily)
          ..addFont(rootBundle.load('assets/fonts/SourceSans3-SemiBold.ttf')))
        .load();

    tester.view.physicalSize = const Size(_masterSide, _masterSide);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Directory('tool/icon').createSync(recursive: true);

    for (final MapEntry<PaperfoldAppIconShape, String> output
        in _outputs.entries) {
      final GlobalKey boundaryKey = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: boundaryKey,
            child: PaperfoldAppIcon(size: _masterSide, shape: output.key),
          ),
        ),
      );
      // Not pumpAndSettle: the SVG decode finishes on the real event loop, so
      // let that loop turn once and then pump the picture into the tree.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);

      final RenderRepaintBoundary boundary = boundaryKey.currentContext!
          .findRenderObject()! as RenderRepaintBoundary;

      // Everything from here is engine work. Awaiting any of it outside
      // runAsync stalls the test until its own timeout, which looks like a
      // ten-minute hang per icon rather than an error.
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage();
        final ByteData pixels = (await image.toByteData())!;
        // If the SVG ever stops arriving in time the icon silently loses its
        // wreath, so count the ink rather than trust the pump.
        expect(
          _inkCoverage(
            pixels,
            transparent: output.key != PaperfoldAppIconShape.card,
          ),
          greaterThan(0.02),
          reason: 'the mark did not render into ${output.value}',
        );

        final ByteData png =
            (await image.toByteData(format: ui.ImageByteFormat.png))!;
        File(output.value).writeAsBytesSync(png.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}

/// The share of pixels the mark actually covers.
///
/// On a transparent shape that is any pixel with alpha. On the card the ground
/// is opaque everywhere, so the gold foil is what counts.
double _inkCoverage(ByteData pixels, {required bool transparent}) {
  final Uint8List bytes = pixels.buffer.asUint8List();
  final Color foil = PaperfoldTokens.cover.foil;
  final int red = (foil.r * 255).round();
  final int green = (foil.g * 255).round();
  final int blue = (foil.b * 255).round();
  int marked = 0;
  for (int i = 0; i < bytes.length; i += 4) {
    if (transparent) {
      if (bytes[i + 3] > 8) marked++;
      continue;
    }
    final bool isFoil = (bytes[i] - red).abs() < 24 &&
        (bytes[i + 1] - green).abs() < 24 &&
        (bytes[i + 2] - blue).abs() < 24;
    if (isFoil) marked++;
  }
  return marked / (bytes.length / 4);
}
