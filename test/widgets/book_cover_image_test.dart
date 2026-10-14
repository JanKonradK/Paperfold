import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';

void main() {
  testWidgets('a 120 by 180 cover at DPR 3 decodes to its pixel budget',
      (tester) async {
    final file = await _largeCover(tester);

    // The former DecorationImage/FileImage path decoded the full source.
    expect(
        await _pumpImage(tester, _frame(Image.file(file, fit: BoxFit.cover))),
        isNull);
    final full = _decodedSize(tester);
    expect(full, const Size(2000, 3000));

    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.imageCache.clear();
    expect(
      await _pumpImage(
          tester,
          _frame(BookCoverImage(
            path: file.path,
            fallback: const Text('Cover unavailable'),
          ))),
      isNull,
    );
    final resized = tester.widget<Image>(find.byType(Image)).image;
    expect(resized, isA<ResizeImage>());
    expect((resized as ResizeImage).width, 360);
    final thumbnail = _decodedSize(tester);
    expect(thumbnail, const Size(360, 540));
    expect(find.text('Cover unavailable'), findsNothing);
    expect(tester.takeException(), isNull);

    // Surface bytes use the decoded dimensions, not compressed PNG file size.
    // This does not claim process-memory, codec, or rendering-time savings.
    final fullBytes = (full.width * full.height * 4).toInt();
    final thumbnailBytes = (thumbnail.width * thumbnail.height * 4).toInt();
    expect(fullBytes, 24000000);
    expect(thumbnailBytes, 777600);
    // ignore: avoid_print
    print('Cover decode: 2000x3000 -> 360x540 pixels; '
        'RGBA surface budget $fullBytes -> $thumbnailBytes bytes');
  });

  testWidgets('large cover layouts cap decoded width at 1200 pixels',
      (tester) async {
    final file = await _largeCover(tester);
    expect(
      await _pumpImage(
          tester,
          _frame(
            BookCoverImage(
                path: file.path, fallback: const Text('Cover unavailable')),
            width: 500,
            height: 500,
          )),
      isNull,
    );

    final provider = tester.widget<Image>(find.byType(Image)).image;
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).width, 1200);
    expect(_decodedSize(tester), const Size(1200, 1800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing cover recovers after the same path is downloaded',
      (tester) async {
    final file = await _largeCover(tester);
    late List<int> bytes;
    await tester.runAsync(() async {
      bytes = await file.readAsBytes();
      await file.delete();
    });
    Widget cover() => _frame(BookCoverImage(
          path: file.path,
          fallback: const Text('Cover unavailable'),
        ));

    expect(await _pumpImage(tester, cover()), isNotNull);
    expect(find.text('Cover unavailable'), findsOneWidget);

    await tester.runAsync(() => file.writeAsBytes(bytes));
    // A sync refresh supplies the same book ID and cover path. Keep its element.
    expect(await _pumpImage(tester, cover()), isNull);
    expect(find.text('Cover unavailable'), findsNothing);
    expect(_decodedSize(tester), const Size(360, 540));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty, missing and corrupt art display the supplied fallback',
      (tester) async {
    late Directory directory;
    late File corrupt;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('paperfold-cover-');
      corrupt = File('${directory.path}/corrupt.png');
      await corrupt.writeAsBytes([0, 1, 2, 3]);
    });
    addTearDown(() async {
      await corrupt.delete();
      await directory.delete();
    });

    for (final path in [
      null,
      '',
      '${directory.path}/missing.png',
      corrupt.path
    ]) {
      final error = await _pumpImage(
          tester,
          _frame(BookCoverImage(
            key: ValueKey(path),
            path: path,
            fallback: const Text('Cover unavailable'),
          )));
      if (path != null && path.isNotEmpty) {
        expect(error, isNotNull);
      }
      expect(find.text('Cover unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

Widget _frame(Widget child, {double width = 120, double height = 180}) =>
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 3),
        child:
            Center(child: SizedBox(width: width, height: height, child: child)),
      ),
    );

Size _decodedSize(WidgetTester tester) {
  final image = tester.widget<RawImage>(find.byType(RawImage)).image!;
  return Size(image.width.toDouble(), image.height.toDouble());
}

Future<Object?> _pumpImage(WidgetTester tester, Widget widget) async {
  Object? failure;
  // Start the file read and codec in this real async zone too. Awaiting a
  // stream first started by pumpWidget in FakeAsync can leave it pending.
  await tester.runAsync(() async {
    await tester.pumpWidget(widget);
    final image = find.byType(Image);
    if (image.evaluate().isEmpty) return;
    final provider = tester.widget<Image>(image).image;
    await precacheImage(
      provider,
      tester.element(image),
      onError: (error, stack) => failure = error,
    ).timeout(const Duration(seconds: 10));
  });
  await tester.pump();
  return failure;
}

Future<File> _largeCover(WidgetTester tester) async {
  final file = await tester.runAsync(() async {
    final directory = await Directory.systemTemp.createTemp('paperfold-cover-');
    final file = File('${directory.path}/cover.png');
    addTearDown(() async {
      await file.delete();
      await directory.delete();
    });
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 2000, 3000),
      Paint()..color = const Color(0xFF391214),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(2000, 3000);
    picture.dispose();
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.writeAsBytes(png!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
    return file;
  });
  return file!;
}
