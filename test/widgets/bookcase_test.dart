import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';

const List<ShelfRow> _shelves = [
  ShelfRow(name: 'Reading now', books: [ShelfBook(
    id: 'r1',
    title: 'The Moonstone',
    author: 'Wilkie Collins',
    binding: BookBinding.hardback,
  )]),
  ShelfRow(name: 'To be read', books: [ShelfBook(
    id: 't1',
    title: 'Dune',
    author: 'Frank Herbert',
    binding: BookBinding.softback,
  )]),
  ShelfRow(name: 'Finished', books: [ShelfBook(
    id: 'f1',
    title: 'The Great Gatsby',
    author: 'F. Scott Fitzgerald',
    binding: BookBinding.softback,
    progress: 1,
    finished: true,
  )]),
];

void main() {
  final key = GlobalKey<BookcaseState>();

  Future<void> pumpCase(
    WidgetTester tester, {
    List<ShelfRow> shelves = _shelves,
    ValueChanged<int>? onShelfChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 780,
            child: Bookcase(
              key: key,
              shelves: shelves,
              onShelfChanged: onShelfChanged,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the bookcase opens on its first shelf', (tester) async {
    await pumpCase(tester);

    expect(key.currentState!.shelf, 0);
    // The shelf below is named, so the reader knows what climbing gets them.
    expect(find.text('TO BE READ'), findsOneWidget);
  });

  testWidgets('the reader climbs to the shelf below', (tester) async {
    int? landed;
    await pumpCase(tester, onShelfChanged: (index) => landed = index);

    await tester.fling(find.byType(Bookcase), const Offset(0, -400), 1200);
    await tester.pumpAndSettle();

    expect(landed, 1);
    expect(key.currentState!.shelf, 1);
  });

  testWidgets('the shelf above is named once there is one', (tester) async {
    await pumpCase(tester);

    await tester.fling(find.byType(Bookcase), const Offset(0, -400), 1200);
    await tester.pumpAndSettle();

    expect(find.text('READING NOW'), findsOneWidget);
    expect(find.text('FINISHED'), findsOneWidget);
  });

  testWidgets('tapping a signpost climbs to that shelf', (tester) async {
    await pumpCase(tester);

    await tester.tap(find.text('TO BE READ'));
    await tester.pumpAndSettle();

    expect(key.currentState!.shelf, 1);
  });

  testWidgets('climbTo moves the bookcase from outside', (tester) async {
    await pumpCase(tester);

    unawaited(key.currentState!.climbTo(2));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(key.currentState!.shelf, 2);
  });

  testWidgets('the reader cannot climb while holding a book off the shelf',
      (tester) async {
    await pumpCase(tester);

    key.currentState!.activeStage!.pickUp();
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.fling(find.byType(Bookcase), const Offset(0, -400), 1200);
    await tester.pumpAndSettle();

    // Still on the first shelf: the book in their hands came off this one, and
    // moving the furniture under it would strand them.
    expect(key.currentState!.shelf, 0);
  });

  testWidgets('an empty shelf falls back to its builder', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 780,
            child: Bookcase(
              shelves: const [
                ShelfRow(name: 'Books to buy', books: []),
              ],
              emptyBuilder: (context, shelf) => Text('nothing on ${shelf.name}'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('nothing on Books to buy'), findsOneWidget);
  });
}
