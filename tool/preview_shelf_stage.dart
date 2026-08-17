// Renders contact sheets of the shelf to PNG files.
//
//   flutter test tool/preview_shelf_stage.dart
//
// It writes `tool/preview/shelf-*.png`. Nothing in the application reads them:
// they exist so the shelf can be looked at, and argued with, without a device.
// Delete them freely.
//
// The book model has its own sheet next door. This one is about everything the
// model does not decide: the angle the books stand at in the row, how far each
// one is stepped back from the one in front, and what taking a book down and
// opening it looks like at rest.

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/bookshelf/shelf_controls/shelf_book_actions.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';

const String _outputDirectory = 'tool/preview';

/// A phone, near enough. The shelf is laid out against the screen it will be
/// used on, because every distance in it is a fraction of the stage.
const Size _screen = Size(390, 780);

const List<ShelfBook> _books = [
  ShelfBook(
    id: 'demo-willows',
    title: 'The Wind in the Willows',
    author: 'Kenneth Grahame',
    binding: BookBinding.hardback,
  ),
  ShelfBook(
    id: 'demo-moonstone',
    title: 'The Moonstone',
    author: 'Wilkie Collins',
    binding: BookBinding.hardback,
    progress: 0.46,
  ),
  ShelfBook(
    id: 'demo-pnp',
    title: 'Pride and Prejudice',
    author: 'Jane Austen',
    binding: BookBinding.softback,
    progress: 0.18,
  ),
  ShelfBook(
    id: 'demo-dune',
    title: 'Dune',
    author: 'Frank Herbert',
    binding: BookBinding.softback,
    progress: 0.78,
  ),
  ShelfBook(
    id: 'demo-gatsby',
    title: 'The Great Gatsby',
    author: 'F. Scott Fitzgerald',
    binding: BookBinding.hardback,
    progress: 1,
    finished: true,
  ),
  // Enough books to fill the stage. The shelf is drawn small so that a row of
  // them runs off both edges, and five books cannot show whether it does.
  ShelfBook(
    id: 'demo-mockingbird',
    title: 'To Kill a Mockingbird',
    author: 'Harper Lee',
    binding: BookBinding.softback,
  ),
  ShelfBook(
    id: 'demo-jane-eyre',
    title: 'Jane Eyre',
    author: 'Charlotte Brontë',
    binding: BookBinding.hardback,
  ),
  ShelfBook(
    id: 'demo-master',
    title: 'The Master and Margarita',
    author: 'Mikhail Bulgakov',
    binding: BookBinding.hardback,
  ),
  ShelfBook(
    id: 'demo-wolf-hall',
    title: 'Wolf Hall',
    author: 'Hilary Mantel',
    binding: BookBinding.hardback,
  ),
  ShelfBook(
    id: 'demo-left-hand',
    title: 'The Left Hand of Darkness',
    author: 'Ursula K. Le Guin',
    binding: BookBinding.softback,
  ),
  ShelfBook(
    id: 'demo-mrs-dalloway',
    title: 'Mrs Dalloway',
    author: 'Virginia Woolf',
    binding: BookBinding.softback,
  ),
  ShelfBook(
    id: 'demo-hobbit',
    title: 'The Hobbit',
    author: 'J. R. R. Tolkien',
    binding: BookBinding.hardback,
  ),
  ShelfBook(
    id: 'demo-rebecca',
    title: 'Rebecca',
    author: 'Daphne du Maurier',
    binding: BookBinding.hardback,
  ),
  ShelfBook(
    id: 'demo-solaris',
    title: 'Solaris',
    author: 'Stanisław Lem',
    binding: BookBinding.softback,
  ),
  ShelfBook(
    id: 'demo-name-wind',
    title: 'The Name of the Wind',
    author: 'Patrick Rothfuss',
    binding: BookBinding.hardback,
  ),
];

void main() {
  final GlobalKey boundary = GlobalKey();
  final GlobalKey<ShelfStageState> stage = GlobalKey<ShelfStageState>();

  testWidgets('renders the shelf contact sheets', (tester) async {
    // A test ships no fonts, so every title would render as a row of boxes and
    // the only place that shows is the written file.
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

    for (final brightness in Brightness.values) {
      final scheme = PaperfoldTokens.colorScheme(brightness);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            theme: ThemeData(
              colorScheme: scheme,
              fontFamily: PaperfoldTypeTokens.journalFamily,
            ),
            home: Scaffold(
              backgroundColor: scheme.surface,
              body: ShelfStage(
                key: stage,
                books: _books,
                shelfName: 'Completed',
                // The real row of controls, so the sheet shows what a reader
                // holding a book actually sees rather than the book alone.
                optionsBuilder: (context, book) => ShelfBookOptionBar(
                  onDetails: () {},
                  onShelves: () {},
                  onCustomise: () {},
                  onNotes: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Each frame sets the stage up, writes its own PNG and puts everything
      // back, because some of them hold a finger down and cannot be unwound
      // from outside.
      final frames = <String, Future<void> Function()>{
        // The row at rest. This is the frame that answers the question the
        // shelf is really asking: what angle does a book stand at, and how far
        // is each one stepped behind the one in front of it.
        'row': () async {
          await _write(tester, boundary, 'shelf-row-${brightness.name}');
        },
        // Mid-drag, where the book in front is on its way out and the next one
        // is turning from its spine to its cover. The finger is still down:
        // released, the physics would snap the deck back to a whole page
        // before the frame was captured, and the sheet would show the row at
        // rest twice.
        'running': () async {
          // Part way between two books. A fling and a short wait, rather than
          // a finger held down: a held drag needs several frames before the
          // deck has redrawn at the new position, and one frame of it looks
          // exactly like the row at rest.
          await tester.fling(
            find.byType(ShelfStage),
            Offset(_screen.width * 0.55, 0),
            900,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 110));
          await _write(tester, boundary, 'shelf-running-${brightness.name}');
          await tester.pumpAndSettle();
        },
        // Part way into opening: the board has swung and the page the book
        // opens onto has taken the screen, with the title and the turning mark
        // that cover the wait while the reader is got ready.
        'opening': () async {
          stage.currentState!.pickUp();
          await tester.pumpAndSettle();
          unawaited(stage.currentState!.openBook());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 1000));
          await _write(tester, boundary, 'shelf-opening-${brightness.name}');
        },
        // Half way up, which is where the pick-up used to fall apart: the row
        // was pushed nearly half a screen sideways as the book rose, so the
        // books beside it swam across the slot it had just left. The gap is
        // open in this frame and nothing but the held book has moved.
        'lifting': () async {
          unawaited(stage.currentState!.pickUp());
          await tester.pump();
          await tester.pump(ShelfStage.liftDuration ~/ 2);
          await _write(tester, boundary, 'shelf-lifting-${brightness.name}');
          await tester.pumpAndSettle();
        },
        // Off the shelf and held in the air, with nothing carrying it.
        'held': () async {
          stage.currentState!.pickUp();
          await tester.pumpAndSettle();
          await _write(tester, boundary, 'shelf-held-${brightness.name}');
        },
      };

      for (final frame in frames.values) {
        await frame();
        stage.currentState!.reset();
        await tester.pumpAndSettle();
      }
    }

    await tester.binding.setSurfaceSize(null);
  });
}

/// Writes what the boundary is showing to a PNG.
///
/// Rasterising needs a real engine frame, and the engine only runs inside
/// [WidgetTester.runAsync]. Awaited outside it, `toImage` does not fail: it
/// stalls until the test's own timeout, so a working generator looks like a ten
/// minute hang per file.
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
