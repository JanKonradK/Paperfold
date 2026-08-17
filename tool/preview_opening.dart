// Renders the cold-start opening to PNG files.
//
//   flutter test tool/preview_opening.dart
//
// It writes `tool/preview/opening-*.png`: the shut cover, the page the cover
// turns onto, and the page on its way into the application. Nothing in the
// application reads them. Delete them freely.
//
// The opening is the first thing anybody sees of Paperfold and it is three
// frames long, so it is the screen most worth being able to look at without a
// device.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/page/opening/opening_sequence.dart';

const String _outputDirectory = 'tool/preview';
const Size _screen = Size(390, 780);

void main() {
  final GlobalKey boundary = GlobalKey();

  testWidgets('renders the opening contact sheets', (tester) async {
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

    final directory = Directory(_outputDirectory);
    if (!directory.existsSync()) directory.createSync(recursive: true);

    await tester.binding.setSurfaceSize(_screen);
    tester.view.physicalSize = _screen;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: PaperfoldTokens.colorScheme(Brightness.dark),
            fontFamily: PaperfoldTypeTokens.journalFamily,
          ),
          home: const OpeningSequence(
            child: ColoredBox(color: Color(0xFF000000)),
          ),
        ),
      ),
    );
    await tester.pump();

    await _write(tester, boundary, 'opening-cover');

    // One tap turns the cover onto the page. The curl needs its own frames.
    await tester.tap(find.byType(OpeningSequence));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await _write(tester, boundary, 'opening-page');

    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _write(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) return;
    File('$_outputDirectory/$name.png')
        .writeAsBytesSync(data.buffer.asUint8List());
  });
}
