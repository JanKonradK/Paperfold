// Renders contact sheets of the 3D book model to PNG files.
//
//   flutter test tool/preview_book_model.dart
//
// It writes `tool/preview/book-model-*.png`. Nothing in the application reads
// them: they exist so the model can be looked at, and argued with, without a
// device. Delete them freely.
//
// It is a test rather than a script because the model needs a real engine to
// lay out its type and rasterise its faces, and `flutter test` is the cheapest
// way to get one.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/service/book_art.dart';
import 'package:paperfold/widgets/book_model/book_model.dart';
import 'package:paperfold/widgets/book_model/book_model_builder.dart';
import 'package:paperfold/widgets/book_model/book_model_scene.dart';

const String _outputDirectory = 'tool/preview';
const Size _cell = Size(300, 380);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders the book model contact sheets', () async {
    // A test ships no fonts, so every title would render as a row of boxes and
    // the only place that shows is the written file.
    await (FontLoader(PaperfoldTypeTokens.journalFamily)
          ..addFont(rootBundle.load('assets/fonts/Philosopher-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Philosopher-Bold.ttf')))
        .load();
    await (FontLoader(PaperfoldTypeTokens.chromeFamily)
          ..addFont(rootBundle.load('assets/fonts/SourceSans3-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/SourceSans3-SemiBold.ttf')))
        .load();

    final directory = Directory(_outputDirectory);
    if (!directory.existsSync()) directory.createSync(recursive: true);

    final jacket = await _bands(360, 240, const [
      _Band(0, 0.46, 0xFF7A2233),
      _Band(0.46, 0.54, 0xFF3B2A1E),
      _Band(0.54, 1, 0xFF1F3A4A),
    ]);
    final front = await _bands(160, 240, const [
      _Band(0, 0.34, 0xFF24404E),
      _Band(0.34, 1, 0xFF2E5468),
    ]);

    for (final brightness in Brightness.values) {
      for (final binding in BookBinding.values) {
        await _sheet(
          '${binding.code}-${brightness.name}',
          brightness: brightness,
          binding: binding,
          arts: [null, await BookArtCache.describe(front)],
        );
      }
    }

    // The angles a book is actually shown at, swept through the whole
    // opening. Anything that leaks, tears or vanishes has to do it here.
    for (final binding in BookBinding.values) {
      await _sheet(
        'shelf-angles-${binding.code}',
        brightness: Brightness.light,
        binding: binding,
        arts: [null],
        cameras: const [
          // The shelf's own camera comes first: it is the angle nearly every
          // book in the application is seen at, and a spine that does not read
          // here does not read anywhere.
          BookCamera(yaw: 1.30, pitch: -0.16, focalLength: 11),
          BookCamera(yaw: 0.92, pitch: -0.40),
          BookCamera(yaw: 1.00, pitch: -0.50),
        ],
        opens: const [0, 0.12, 0.3, 0.5, 0.7, 0.85, 1],
      );
    }

    // One row per binding and camera. Opening at the middle of the cover turn
    // exposes the underside, head and fore-edge of each split, where a missing
    // closing face would show as daylight through the paper block.
    await _openAtSheet();

    // The whole turn, which is what the long press sweeps through. Every one
    // of these has to be a solid object with no daylight in it.
    await _sheet(
      'turn-sweep',
      brightness: Brightness.light,
      binding: BookBinding.hardback,
      arts: [null],
      cameras: const [
        BookCamera(yaw: -0.40, pitch: -0.30),
        BookCamera(yaw: 0.38, pitch: -0.26),
        BookCamera(yaw: 1.20, pitch: -0.35),
        BookCamera(yaw: 1.75, pitch: -0.35),
        BookCamera(yaw: 2.40, pitch: -0.30),
        BookCamera(yaw: 3.52, pitch: -0.26),
      ],
      opens: const [0, 0.45],
    );

    await _sheet(
      'wrap-around-jacket',
      brightness: Brightness.light,
      binding: BookBinding.hardback,
      arts: [await BookArtCache.describe(jacket)],
      cameras: const [
        BookCamera(),
        BookCamera(yaw: 1.30),
        BookCamera(yaw: 2.85),
        BookCamera(yaw: -0.30),
      ],
      opens: const [0],
    );
  });
}

/// One PNG that compares every paper-block split in both working cameras.
Future<void> _openAtSheet() async {
  const openAts = [0.0, 0.25, 0.5, 0.75, 1.0];
  const cameras = [BookCamera(), BookCamera.threeQuarter];
  const opening = 0.68;
  final scheme = PaperfoldTokens.colorScheme(Brightness.light);
  final rows = BookBinding.values.length * cameras.length;
  final size = Size(_cell.width * openAts.length, _cell.height * rows);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);

  var row = 0;
  for (final binding in BookBinding.values) {
    for (final camera in cameras) {
      for (var column = 0; column < openAts.length; column++) {
        canvas.save();
        canvas.translate(_cell.width * column, _cell.height * row);
        BookModelRenderer.paint(
          canvas,
          _cell.deflate(18),
          BookModelSpec(
            binding: binding,
            title: 'The Wind in the Willows',
            author: 'Kenneth Grahame',
            blurb: 'Mole, Rat, Badger and the incorrigible Toad of Toad Hall '
                'take to the river bank, the open road and the Wild Wood.',
            open: opening,
            openAt: openAts[column],
            seed: 90210,
            camera: camera,
            palette: BookModelPalette.resolve(
              scheme: scheme,
              binding: binding,
              seed: 90210,
            ),
            typography: const BookModelTypography(
              title: TextStyle(fontFamily: PaperfoldTypeTokens.journalFamily),
              author: TextStyle(fontFamily: PaperfoldTypeTokens.chromeFamily),
              label: TextStyle(fontFamily: PaperfoldTypeTokens.chromeFamily),
            ),
          ),
        );
        canvas.restore();
      }
      row++;
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$_outputDirectory/book-model-open-at-sweep.png')
      .writeAsBytesSync(data!.buffer.asUint8List());
  picture.dispose();
  image.dispose();
}

/// One PNG: a row per opening, a column per artwork or camera.
Future<void> _sheet(
  String name, {
  required Brightness brightness,
  required BookBinding binding,
  required List<BookArt?> arts,
  List<BookCamera> cameras = const [BookCamera()],
  List<double> opens = const [0, 0.35, 0.7, 1],
}) async {
  final scheme = PaperfoldTokens.colorScheme(brightness);
  final columns = arts.length * cameras.length;
  final size = Size(_cell.width * columns, _cell.height * opens.length);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Offset.zero & size,
    Paint()..color = scheme.surface,
  );

  for (var row = 0; row < opens.length; row++) {
    var column = 0;
    for (final art in arts) {
      for (final camera in cameras) {
        canvas.save();
        canvas.translate(_cell.width * column, _cell.height * row);
        BookModelRenderer.paint(
          canvas,
          _cell.deflate(18),
          BookModelSpec(
            binding: binding,
            title: 'The Wind in the Willows',
            author: 'Kenneth Grahame',
            blurb: 'Mole, Rat, Badger and the incorrigible Toad of Toad Hall '
                'take to the river bank, the open road and the Wild Wood.',
            open: opens[row],
            art: art,
            seed: 90210,
            camera: camera,
            palette: BookModelPalette.resolve(
              scheme: scheme,
              binding: binding,
              seed: 90210,
              art: art,
            ),
            typography: const BookModelTypography(
              title: TextStyle(fontFamily: PaperfoldTypeTokens.journalFamily),
              author: TextStyle(fontFamily: PaperfoldTypeTokens.chromeFamily),
              label: TextStyle(fontFamily: PaperfoldTypeTokens.chromeFamily),
            ),
          ),
        );
        canvas.restore();
        column++;
      }
    }
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  File('$_outputDirectory/book-model-$name.png')
      .writeAsBytesSync(data!.buffer.asUint8List());
  picture.dispose();
  image.dispose();
}

class _Band {
  const _Band(this.from, this.to, this.color);
  final double from;
  final double to;
  final int color;
}

extension on Size {
  Size deflate(double amount) => Size(width - amount * 2, height - amount * 2);
}

Future<ui.Image> _bands(int width, int height, List<_Band> bands) async {
  final pixels = Uint8List(width * height * 4);
  for (final band in bands) {
    final start = (band.from * width).round();
    final end = (band.to * width).round();
    for (var y = 0; y < height; y++) {
      for (var x = start; x < end; x++) {
        final i = (y * width + x) * 4;
        pixels[i] = (band.color >> 16) & 0xFF;
        pixels[i + 1] = (band.color >> 8) & 0xFF;
        pixels[i + 2] = band.color & 0xFF;
        pixels[i + 3] = 0xFF;
      }
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: width,
    height: height,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await descriptor.instantiateCodec();
  final frame = await codec.getNextFrame();
  codec.dispose();
  descriptor.dispose();
  return frame.image;
}
