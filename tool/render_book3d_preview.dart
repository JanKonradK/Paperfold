// Renders the 3D book so it can be looked at.
//
//   flutter test tool/render_book3d_preview.dart
//
// Writes into tool/preview/, which is not shipped.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/book3d/book_3d.dart';
import 'package:paperfold/widgets/book3d/book_geometry.dart';

const BookMaterials _cloth = BookMaterials(
  cloth: Color(0xFF7B2233),
  foil: Color(0xFFE7C87A),
);

Widget _plate(String caption, Widget child) {
  return Padding(
    padding: const EdgeInsets.all(10),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 300, height: 260, child: Center(child: child)),
        const SizedBox(height: 4),
        Text(caption, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}

Future<void> _write(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.5);
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    File('tool/preview/$name.png').writeAsBytesSync(png.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _pump(
  WidgetTester tester,
  GlobalKey key,
  Brightness brightness,
  Widget body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: PaperfoldTokens.colorScheme(brightness),
        useMaterial3: true,
        fontFamily: PaperfoldTypeTokens.journalFamily,
      ),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(body: Center(child: body)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() async {
    await (FontLoader(PaperfoldTypeTokens.journalFamily)
          ..addFont(rootBundle.load('assets/fonts/Philosopher-Bold.ttf')))
        .load();
    Directory('tool/preview').createSync(recursive: true);
  });

  testWidgets('one book, closed, from several angles', (tester) async {
    tester.view.physicalSize = const Size(1600, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    await _pump(
      tester,
      key,
      Brightness.light,
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          for (final (label, camera) in <(String, BookCamera)>[
            ('spine on', BookCamera(yaw: 0.06, pitch: 0.30, scale: 0.95)),
            ('shelved, looking down', BookCamera(yaw: 0.20, pitch: 0.52, scale: 0.95)),
            ('three quarter', BookCamera(yaw: 0.72, pitch: 0.40, scale: 0.95)),
            ('cover on', BookCamera(yaw: 1.32, pitch: 0.34, scale: 0.95)),
          ])
            _plate(
              label,
              Book3D(
                camera: camera,
                materials: _cloth,
                title: 'The Left Hand of Darkness',
              ),
            ),
        ],
      ),
    );
    await _write(tester, key, 'book3d-angles');
  });

  testWidgets('one book, opening', (tester) async {
    tester.view.physicalSize = const Size(1800, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    await _pump(
      tester,
      key,
      Brightness.light,
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          for (final open in [0.0, 0.2, 0.45, 0.7, 1.0])
            _plate(
              'open ${(open * 100).round()}%',
              Book3D(
                camera: const BookCamera(yaw: 0.86, pitch: 0.50, scale: 0.85),
                materials: _cloth,
                openAmount: open,
                title: 'The Left Hand of Darkness',
              ),
            ),
        ],
      ),
    );
    await _write(tester, key, 'book3d-opening');
  });

  testWidgets('the same book, resized', (tester) async {
    tester.view.physicalSize = const Size(1700, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();

    await _pump(
      tester,
      key,
      Brightness.dark,
      Wrap(
        alignment: WrapAlignment.center,
        children: [
          for (final (label, geometry) in <(String, BookGeometry)>[
            ('thin', BookGeometry(thickness: 12)),
            ('ordinary', BookGeometry()),
            ('thick', BookGeometry(thickness: 52)),
            ('tall and thin', BookGeometry(height: 270, depth: 150, thickness: 14)),
            ('small and fat', BookGeometry(height: 170, depth: 110, thickness: 44)),
          ])
            _plate(
              label,
              Book3D(
                geometry: geometry,
                camera: const BookCamera(yaw: 0.66, pitch: 0.44, scale: 0.8),
                materials: _cloth,
                title: 'Piranesi',
              ),
            ),
        ],
      ),
    );
    await _write(tester, key, 'book3d-sizes');
  });
}
