import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/widgets/book_model/book_model.dart';
import 'package:paperfold/widgets/bookshelf/shelf_plane.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';

const List<ShelfBook> _books = [
  ShelfBook(
    id: 'a',
    title: 'The Wind in the Willows',
    author: 'Kenneth Grahame',
    binding: BookBinding.hardback,
  ),
  ShelfBook(
    id: 'b',
    title: 'The Moonstone',
    author: 'Wilkie Collins',
    binding: BookBinding.hardback,
    progress: 0.5,
  ),
  ShelfBook(
    id: 'c',
    title: 'Dune',
    author: 'Frank Herbert',
    binding: BookBinding.softback,
    progress: 1,
    finished: true,
  ),
];

void main() {
  final key = GlobalKey<ShelfStageState>();

  Future<void> pumpStage(
    WidgetTester tester, {
    ValueChanged<ShelfBook>? onOpen,
    ValueChanged<int>? onIndexChanged,
    Widget Function(BuildContext context, ShelfBook book)? optionsBuilder,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: SizedBox(
              width: 400,
              height: 720,
              child: ShelfStage(
                key: key,
                books: _books,
                onOpen: onOpen,
                onIndexChanged: onIndexChanged,
                optionsBuilder: optionsBuilder,
                pickUpHint: 'Take it down',
                openHint: 'Open it',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the shelf starts with a row of books, none of them held',
      (tester) async {
    await pumpStage(tester);

    expect(key.currentState!.phase, ShelfPhase.shelved);
    expect(key.currentState!.current!.id, 'a');
    // The book in front and the ones standing behind it are all real objects,
    // not one object and a picture of a row.
    expect(find.byType(BookModel), findsAtLeast(2));
  });

  testWidgets('every book on the shelf stands at the one shelf angle',
      (tester) async {
    await pumpStage(tester);

    double yawOf(int index) => tester
        .widgetList<BookModel>(find.byType(BookModel))
        .firstWhere((model) => model.title == _books[index].title)
        .camera
        .yaw;

    // Nothing comes out of the row, before or after the reader runs along it.
    // The shelf is a rank of objects at one angle, and the only book that
    // leaves it is one somebody has taken down.
    for (var index = 0; index < _books.length; index++) {
      expect(yawOf(index), ShelfStage.shelfYaw, reason: 'book $index');
    }

    await tester.fling(find.byType(ShelfStage), const Offset(260, 0), 900);
    await tester.pumpAndSettle();

    expect(key.currentState!.index, 1);
    for (var index = 0; index < _books.length; index++) {
      expect(yawOf(index), ShelfStage.shelfYaw, reason: 'book $index, moved');
    }
  });

  testWidgets('every book on the shelf is drawn at the row scale',
      (tester) async {
    // The defect this guards: each book measured its own outline and centred
    // itself in the box it was given, so a thick book and a thin one sat a few
    // pixels off the slots the projection had given them and half a title
    // disappeared behind its neighbour.
    await pumpStage(tester);

    final scales = tester
        .widgetList<BookModel>(find.byType(BookModel))
        .map((model) => model.rowScale)
        .toSet();

    expect(scales, hasLength(1));
    expect(scales.single, isNotNull);
  });

  testWidgets('the row is drawn at one scale all the way along the shelf',
      (tester) async {
    // The defect this guards: the projection fitted the *front* book's outline
    // to the box and handed that scale to every book on the shelf. A cased
    // book and a thin paperback fit differently by four and a half per cent, so
    // the whole row and the board under it changed size in one frame every time
    // the pager crossed a book boundary. The fixture runs hardback, hardback,
    // softback, which is where the step was widest.
    await pumpStage(tester);

    double scale() => tester
        .widgetList<BookModel>(find.byType(BookModel))
        .map((model) => model.rowScale)
        .whereType<double>()
        .reduce((a, b) => a == b ? a : double.nan);

    final first = scale();
    expect(first, isNot(isNaN), reason: 'the row is not at one scale');

    for (var step = 0; step < 2; step++) {
      await tester.fling(find.byType(ShelfStage), const Offset(260, 0), 900);
      await tester.pumpAndSettle();
      expect(scale(), closeTo(first, 0.001), reason: 'after ${step + 1} books');
    }
  });

  testWidgets('coming back from a book puts the row back on the shelf',
      (tester) async {
    await pumpStage(tester);
    await tester.fling(find.byType(ShelfStage), const Offset(260, 0), 900);
    await tester.pumpAndSettle();

    key.currentState!.reset();
    await tester.pumpAndSettle();

    expect(key.currentState!.phase, ShelfPhase.shelved);
    for (final model in tester.widgetList<BookModel>(find.byType(BookModel))) {
      expect(model.camera.yaw, ShelfStage.shelfYaw);
    }
  });

  testWidgets('a tap takes the book in front off the shelf', (tester) async {
    await pumpStage(tester);

    await tester.tap(find.byType(ShelfStage));
    // The first pump starts the ticker; it does not advance it.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(key.currentState!.phase, ShelfPhase.held);
  });

  testWidgets('a tap on the dark beside the book takes nothing down',
      (tester) async {
    await pumpStage(tester);
    final stage = tester.getRect(find.byType(ShelfStage));

    // The head of the stage is reserved, and there is no book in it. A tap
    // there used to lift the book in front, which is what made the shelf feel
    // as though it were acting on its own.
    await tester.tapAt(Offset(stage.center.dx, stage.top + 8));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(key.currentState!.phase, ShelfPhase.shelved);
  });

  testWidgets('a tap beside a held book puts it back', (tester) async {
    await pumpStage(tester);
    final stage = tester.getRect(find.byType(ShelfStage));

    await tester.tap(find.byType(ShelfStage));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(key.currentState!.phase, ShelfPhase.held);

    await tester.tapAt(Offset(stage.center.dx, stage.bottom - 8));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(key.currentState!.phase, ShelfPhase.shelved);
  });

  testWidgets('a tap on the ghost of a cleared book still puts the held one back',
      (tester) async {
    // The defect this guards: the deck recorded where every book landed before
    // it decided whether the book was drawn at all, so the books the lift
    // clears off the screen left their rects behind. A tap on that empty black
    // read as a tap on a book and opened the held one instead of shelving it.
    await pumpStage(tester);
    final stage = tester.getRect(find.byType(ShelfStage));

    unawaited(key.currentState!.pickUp());
    await tester.pump();
    await tester.pumpAndSettle();
    expect(key.currentState!.phase, ShelfPhase.held);

    // Well off the held book, where a shelved neighbour used to stand.
    await tester.tapAt(Offset(stage.left + 12, stage.center.dy));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(key.currentState!.phase, ShelfPhase.shelved);
  });

  testWidgets('a drag toward the trailing side puts a held book back',
      (tester) async {
    await pumpStage(tester);

    unawaited(key.currentState!.pickUp());
    await tester.pump();
    await tester.pumpAndSettle();
    expect(key.currentState!.phase, ShelfPhase.held);

    await tester.fling(find.byType(ShelfStage), const Offset(220, 0), 900);
    await tester.pumpAndSettle();

    expect(key.currentState!.phase, ShelfPhase.shelved);
  });

  testWidgets('a drag toward the leading side opens a held book',
      (tester) async {
    ShelfBook? opened;
    await pumpStage(tester, onOpen: (book) => opened = book);

    unawaited(key.currentState!.pickUp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.fling(find.byType(ShelfStage), const Offset(-220, 0), 900);
    // Pumped rather than settled: the page the book opens onto carries a mark
    // that turns for as long as the reader is being got ready, so the tree
    // never comes to rest while the stage is opening.
    await tester.pump();
    await tester
        .pump(ShelfStage.openDuration + const Duration(milliseconds: 32));

    expect(key.currentState!.phase, ShelfPhase.opening);
    expect(opened?.id, 'a');
  });

  testWidgets('a tap on a held book opens it', (tester) async {
    ShelfBook? opened;
    await pumpStage(tester, onOpen: (book) => opened = book);

    unawaited(key.currentState!.pickUp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ShelfStage));
    // Pumped rather than settled, for the turning mark on the opened page.
    await tester.pump();
    await tester.pump(
      ShelfStage.openDuration + const Duration(milliseconds: 32),
    );

    expect(opened?.id, 'a');
  });

  testWidgets('dragging toward the trailing side brings the next book forward',
      (tester) async {
    int? landed;
    await pumpStage(tester, onIndexChanged: (index) => landed = index);

    // The shelf is reversed on purpose: a finger pushes along a row of spines
    // rather than scrolling a gallery of pictures past a window. This assertion
    // is the direction itself, so flipping it back cannot pass unnoticed.
    await tester.fling(find.byType(ShelfStage), const Offset(400, 0), 1200);
    await tester.pumpAndSettle();

    expect(landed, 1);
    expect(key.currentState!.current!.id, 'b');
  });

  testWidgets('dragging the other way does not run past the first book',
      (tester) async {
    await pumpStage(tester);

    await tester.fling(find.byType(ShelfStage), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();

    expect(key.currentState!.current!.id, 'a');
  });

  testWidgets('with animations off a book is taken down in one frame',
      (tester) async {
    await pumpStage(tester, reduceMotion: true);

    unawaited(key.currentState!.pickUp());
    await tester.pump();

    expect(key.currentState!.phase, ShelfPhase.held);
  });

  testWidgets('a finished book is shut rather than opened', (tester) async {
    await pumpStage(tester);

    // The third book is the finished one. Its opening runs the other way, so
    // the value the model is handed starts full and falls.
    expect(_books[2].finished, isTrue);
    expect(_books[2].openAt, 1.0);
    expect(_books[0].openAt, 0.0);
    expect(_books[1].openAt, closeTo(0.5, 0.001));
  });

  testWidgets('the opened page covers the shelf and names the book',
      (tester) async {
    await pumpStage(tester);

    unawaited(key.currentState!.pickUp());
    await tester.pump();
    await tester.pumpAndSettle();

    unawaited(key.currentState!.openBook());
    await tester.pump();
    await tester.pump(
      ShelfStage.openDuration + const Duration(milliseconds: 32),
    );

    // The reader is not there yet, and what fills the gap is the page the book
    // opened onto, carrying its title. It used to be a picture of the front
    // board magnified three and a half times.
    expect(find.text('The Wind in the Willows'), findsOneWidget);
    expect(find.text('Kenneth Grahame'), findsOneWidget);
  });

  testWidgets('the options over a held book take the tap meant for them',
      (tester) async {
    // The defect this guards: the gesture layer is a full-stage opaque hit
    // test, because the pager under it has to be able to take a drag anywhere.
    // It was also the last child of the stack, so it was on top of the options
    // as well, and every one of the four buttons over a held book was dead.
    var tapped = 0;
    await pumpStage(
      tester,
      optionsBuilder: (context, book) => FilledButton(
        key: const ValueKey('option'),
        onPressed: () => tapped++,
        child: const Text('Details'),
      ),
    );

    unawaited(key.currentState!.pickUp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('option')));
    await tester.pump();

    expect(tapped, 1);
    // And taking the tap did not also send it on to the shelf underneath.
    expect(key.currentState!.phase, ShelfPhase.held);
  });

  testWidgets('a tap on the dark beside the options still reaches the shelf',
      (tester) async {
    // The other half of the same change: the options layer must not become a
    // lid over the head of the stage. Only the buttons on it are opaque.
    await pumpStage(
      tester,
      optionsBuilder: (context, book) => FilledButton(
        key: const ValueKey('option'),
        onPressed: () {},
        child: const Text('Details'),
      ),
    );
    final stage = tester.getRect(find.byType(ShelfStage));

    unawaited(key.currentState!.pickUp());
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tapAt(Offset(stage.left + 8, stage.top + 8));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(key.currentState!.phase, ShelfPhase.shelved);
  });

  testWidgets('the row keeps its place while a book is off the shelf',
      (tester) async {
    // The defect this guards: every other book was pushed nearly half a screen
    // sideways as the held book rose, so the row swam across the slot that had
    // just been vacated and swam back on the way home. The gap stays open, and
    // nothing but the held book moves.
    Map<String, Offset> row() => {
          for (final element in tester.widgetList<BookModel>(
            find.byType(BookModel),
          ))
            element.title: tester.getCenter(
              find.byWidget(element),
            ),
        };

    await pumpStage(tester);
    final before = row();

    unawaited(key.currentState!.pickUp());
    await tester.pump();
    // Half way up, where a slide would be at its widest.
    await tester.pump(ShelfStage.liftDuration ~/ 2);
    final midway = row();

    for (final entry in before.entries) {
      if (entry.key == _books.first.title) continue;
      final now = midway[entry.key];
      if (now == null) continue;
      expect(
        now.dx,
        closeTo(entry.value.dx, 0.5),
        reason: '${entry.key} moved along the shelf',
      );
    }
  });

  testWidgets('a shelf frame costs the compositor almost no layers',
      (tester) async {
    // The defect this guards: every book carried a `ColorFiltered` for the
    // scrim that darkens the far end of the row, and an `Opacity` that sat at 1
    // for the whole time anybody was looking at a shelf. Both composite through
    // a layer whether or not they have anything to do, so a row part way along
    // a long shelf handed the compositor fourteen colour-filter render passes
    // and twenty opacity layers on every frame of a scroll. The dark is painted
    // into the book now, and the fade is only wrapped when it is fading.
    ({int filters, int opacities}) count() {
      var filters = 0;
      var opacities = 0;
      void walk(Layer? layer) {
        if (layer == null) return;
        if (layer is ColorFilterLayer) filters++;
        if (layer is OpacityLayer) opacities++;
        if (layer is ContainerLayer) {
          for (var child = layer.firstChild;
              child != null;
              child = child.nextSibling) {
            walk(child);
          }
        }
      }

      walk(tester.binding.rootElement!.renderObject!.debugLayer);
      return (filters: filters, opacities: opacities);
    }

    // What a MaterialApp and a Scaffold cost on their own, so this measures the
    // shelf rather than the framework's own chrome.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(width: 400, height: 720)),
      ),
    );
    await tester.pumpAndSettle();
    final bare = count();

    final many = [
      for (var index = 0; index < 24; index++)
        ShelfBook(
          id: 'many-$index',
          title: 'A Book With Quite a Long Title $index',
          author: 'An Author $index',
          binding: index.isEven ? BookBinding.hardback : BookBinding.softback,
          progress: index / 24,
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 720,
            child: ShelfStage(books: many),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Part way down the row, which is where the most books are dimmed.
    await tester.fling(find.byType(ShelfStage), const Offset(-900, 0), 900);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final shelf = count();

    expect(
      tester.widgetList<BookModel>(find.byType(BookModel)).length,
      greaterThan(8),
      reason: 'the fixture must actually put a crowd of books on the stage',
    );
    expect(
      shelf.filters - bare.filters,
      0,
      reason: 'the scrim is painted into the book, not composited over it',
    );
    expect(
      shelf.opacities - bare.opacities,
      0,
      reason: 'nothing on a shelf being scrolled is part way faded',
    );

    await tester.pumpAndSettle();
  });

  test('the row steps by the thickness of its books, not by a fixed amount',
      () {
    // The defect this guards: the row stepped every book back by one constant,
    // and any book thicker than that constant stood inside its neighbour.
    final places = ShelfStage.rowPlaces(_books);
    final depths = [for (final book in _books) ShelfStage.bookDepth(book)];

    expect(places.first, 0);
    for (var index = 1; index < places.length; index++) {
      final apart = places[index] - places[index - 1];
      // Two neighbours meet cover to back board. The centres must be at least
      // half of each of them apart, or the two solids share the same space.
      expect(
        apart,
        greaterThan((depths[index - 1] + depths[index]) / 2),
        reason: 'books ${index - 1} and $index stand inside one another',
      );
    }

    // And the fixture really does contain a book the old fixed step was too
    // small for, so this is a test of the fix and not of an easy case.
    expect(depths.any((depth) => depth > -ShelfProjection.step.z), isTrue);
  });
}
