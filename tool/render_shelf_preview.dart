// Renders the shelf to PNG so it can be looked at.
//
// The owner judges the shelf on hardware, not on a description, and the shelf
// is the one screen where that matters most. This is the cheap half of that
// loop: it will not tell you how the glass feels under a fling, but it will
// tell you whether the books have depth, whether the top boards tile along the
// row, and whether the metal reads as metal.
//
//   flutter test tool/render_shelf_preview.dart
//
// Writes into tool/preview/, which is not shipped.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/widgets/bookshelf/leading_book.dart';
import 'package:paperfold/widgets/bookshelf/glass_shelf.dart';

const double _width = 400;
const double _height = 400;

/// A shelf's worth of real titles, so the spines carry believable text lengths
/// rather than lorem of one width.
const List<(String, String)> _books = <(String, String)>[
  ('The Left Hand of Darkness', 'Le Guin'),
  ('Piranesi', 'Clarke'),
  ('The Blue Flower', 'Fitzgerald'),
  ('Gilead', 'Robinson'),
  ('Stoner', 'Williams'),
  ('The Rings of Saturn', 'Sebald'),
  ('Autumn', 'Smith'),
];

/// The face-out book at the head of the row. No cover file, so it shows the
/// generated cover - which is the case worth looking at, because a shelf of
/// imported EPUBs is full of books whose art never extracted.
final _leadingBook = Book(
  id: 1,
  title: _books.first.$1,
  coverPath: '',
  filePath: 'preview.epub',
  lastReadPosition: '',
  readingPercentage: 0,
  author: _books.first.$2,
  isDeleted: false,
  rating: 4,
  status: BookStatus.reading,
  createTime: DateTime.utc(2026, 1, 1),
  updateTime: DateTime.utc(2026, 1, 1),
);

void main() {
  testWidgets('writes the shelf previews', (WidgetTester tester) async {
    // `BookCover` reads the two "show title / author on the generated cover"
    // preferences, so the face-out book needs Prefs standing up.
    // This file runs under `flutter test`, but it lives in tool/ so the
    // analyzer does not treat it as a test.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();

    // A widget test ships no fonts. Without these the spine titles render as
    // tofu and the only place that shows is the written file.
    await (FontLoader(PaperfoldTypeTokens.journalFamily)
          ..addFont(rootBundle.load('assets/fonts/Philosopher-Bold.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Philosopher-Regular.ttf')))
        .load();
    await (FontLoader(PaperfoldTypeTokens.chromeFamily)
          ..addFont(rootBundle.load('assets/fonts/SourceSans3-SemiBold.ttf')))
        .load();

    tester.view.physicalSize = const Size(_width * 2, _height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    Directory('tool/preview').createSync(recursive: true);

    for (final brightness in Brightness.values) {
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: PaperfoldTokens.colorScheme(brightness),
            useMaterial3: true,
            // The real theme builds its text theme inside `colorSchema()`,
            // which wants Prefs. Naming the family is enough to judge the
            // spines, and without it every title renders as tofu.
            fontFamily: PaperfoldTypeTokens.journalFamily,
          ),
          home: RepaintBoundary(
            key: boundaryKey,
            child: Scaffold(
              body: Center(
                child: GlassShelf(
                  child: SizedBox(
                    height: BookSpine.shelfStageHeight(TextScaler.noScaling),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        4,
                        BookSpine.stageTopInset,
                        4,
                        BookSpine.stageBottomInset,
                      ),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _books.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: BookSpine.spacing),
                        itemBuilder: (context, index) => Align(
                          alignment: Alignment.bottomCenter,
                          child: index == 0
                              ? LeadingBook(
                                  book: _leadingBook,
                                  semanticLabel: _books[0].$1,
                                  onTap: () {},
                                )
                              : BookSpine(
                                  stableId: 'preview-$index',
                                  title: _books[index].$1,
                                  author: _books[index].$2,
                                  semanticLabel: _books[index].$1,
                                  onTap: () {},
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;

      // Engine work. Awaiting any of it outside runAsync stalls the test until
      // its own timeout, which looks like a ten-minute hang rather than an
      // error.
      await tester.runAsync(() async {
        final ui.Image image = await boundary.toImage(pixelRatio: 3);
        final ByteData png =
            (await image.toByteData(format: ui.ImageByteFormat.png))!;
        File('tool/preview/shelf-${brightness.name}.png')
            .writeAsBytesSync(png.buffer.asUint8List());

        // Everything that makes the glass glass - the deck, the metal nosing,
        // the reflection - happens in about 30 dp around a book's base. At
        // page scale that is a smudge, so it gets its own crop at 4x.
        const double band = 44;
        const double zoom = 4;
        final stageHeight = BookSpine.shelfStageHeight(TextScaler.noScaling);
        // The shelf is centred, and the crop is the band ending at its foot.
        final stageBottom = (_height + stageHeight) / 2;

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.scale(zoom);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            0,
            (stageBottom - band) * 3,
            image.width.toDouble(),
            band * 3,
          ),
          Rect.fromLTWH(0, 0, image.width / 3, band),
          Paint(),
        );
        final ui.Image crop = await recorder
            .endRecording()
            .toImage((image.width / 3 * zoom).round(), (band * zoom).round());
        final ByteData cropPng =
            (await crop.toByteData(format: ui.ImageByteFormat.png))!;
        File('tool/preview/shelf-${brightness.name}-glass.png')
            .writeAsBytesSync(cropPng.buffer.asUint8List());
        crop.dispose();
        image.dispose();
      });
    }
  });
}
