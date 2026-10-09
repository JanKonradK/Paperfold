import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/widgets/book_model/book_model.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';

const _books = [
  ShelfBook(
    id: 'a',
    title: 'The Wind in the Willows',
    author: 'Kenneth Grahame',
    pageCount: 200,
    binding: BookBinding.hardback,
  ),
  ShelfBook(
    id: 'b',
    title: 'The Moonstone',
    author: 'Wilkie Collins',
    pageCount: 450,
    binding: BookBinding.hardback,
    progress: 0.5,
  ),
  ShelfBook(
    id: 'c',
    title: 'Dune',
    author: 'Frank Herbert',
    pageCount: 600,
    binding: BookBinding.softback,
    progress: 1,
    finished: true,
  ),
];

void main() {
  late GlobalKey<ShelfStageState> key;
  setUp(() => key = GlobalKey<ShelfStageState>());

  Future<void> pumpStage(
    WidgetTester tester, {
    List<ShelfBook> books = _books,
    ValueChanged<ShelfBook>? onOpen,
    ValueChanged<ShelfPhase>? onPhaseChanged,
    Widget Function(BuildContext, ShelfBook)? optionsBuilder,
    Size size = const Size(412, 715),
    double textScale = 1,
    bool reduceMotion = false,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: ShelfStage(
                key: key,
                books: books,
                onOpen: onOpen,
                onPhaseChanged: onPhaseChanged,
                optionsBuilder: optionsBuilder,
                pickUpHint: 'Select a book',
                openHint: 'Open book',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder spine(String id) => find.byKey(ValueKey('shelf-spine-$id'));

  testWidgets('page counts set thickness and books share a straight shelf', (
    tester,
  ) async {
    await pumpStage(tester);
    expect(find.byType(BookModel), findsNothing);
    expect(key.currentState!.phase, ShelfPhase.shelved);
    final books = [for (final book in _books) tester.getRect(spine(book.id))];
    expect(books.map((rect) => rect.width).toSet().length, greaterThan(1));
    expect(books[0].width, lessThan(books[1].width));
    expect(books[1].width, lessThan(books[2].width));
    expect(books.map((rect) => rect.height).toSet().length, greaterThan(1));
    final board = tester.getRect(find.byKey(const ValueKey('shelf-board')));
    for (final rect in books) {
      expect(rect.bottom, closeTo(board.top, 0.01));
      expect(rect.width, greaterThanOrEqualTo(48));
    }
    await tester.tapAt(const Offset(8, 8));
    expect(key.currentState!.phase, ShelfPhase.shelved);
  });

  testWidgets('a series shares height and colour while page counts set width', (
    tester,
  ) async {
    await pumpStage(
      tester,
      books: const [
        ShelfBook(
          id: 's1',
          title: 'First, Vol. 1',
          author: 'A Writer',
          binding: BookBinding.softback,
          series: 'A series',
          volume: '1',
          pageCount: 200,
        ),
        ShelfBook(
          id: 's2',
          title: 'Second, Vol. 2',
          author: 'A Writer',
          binding: BookBinding.hardback,
          series: 'A series',
          volume: '2',
          pageCount: 300,
        ),
        ShelfBook(
          id: 's3',
          title: 'Third',
          author: 'A Writer',
          binding: BookBinding.softback,
          series: 'A series',
        ),
      ],
    );
    final first = tester.getSize(spine('s1'));
    final second = tester.getSize(spine('s2'));
    expect(first.height, second.height);
    expect(first.width, lessThan(second.width));
    expect(
      tester.widget<Material>(spine('s1')).color,
      tester.widget<Material>(spine('s2')).color,
    );
    expect(tester.getSize(spine('s3')).width, 60);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'any visible spine selects its own cover, full title and actions',
    (tester) async {
      var details = 0;
      await pumpStage(
        tester,
        optionsBuilder: (context, book) => TextButton(
          onPressed: () => details++,
          child: Text('Details for ${book.id}'),
        ),
      );
      await tester.tap(spine('b'));
      await tester.pumpAndSettle();
      expect(key.currentState!.current!.id, 'b');
      expect(key.currentState!.phase, ShelfPhase.held);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('held-book-title'))).data,
        'The Moonstone',
      );
      expect(find.text('Wilkie Collins'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      await tester.ensureVisible(find.text('Details for b'));
      await tester.tap(find.text('Details for b'));
      expect(details, 1);
      expect(key.currentState!.phase, ShelfPhase.held);
      await tester.ensureVisible(
        find.byKey(const ValueKey('return-shelf-book')),
      );
      await tester.tap(find.byKey(const ValueKey('return-shelf-book')));
      await tester.pumpAndSettle();
      expect(key.currentState!.phase, ShelfPhase.shelved);
      expect(key.currentState!.current!.id, 'b');
    },
  );

  testWidgets('open calls the selected book once, and reset returns it', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpStage(tester, onOpen: (book) => opened.add(book.id));
    await tester.tap(spine('c'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('open-shelf-book')));
    await tester.tap(find.byKey(const ValueKey('open-shelf-book')));
    unawaited(key.currentState!.openBook());
    await tester.pumpAndSettle();
    expect(opened, ['c']);
    expect(key.currentState!.phase, ShelfPhase.opening);
    key.currentState!.reset();
    await tester.pumpAndSettle();
    expect(key.currentState!.phase, ShelfPhase.shelved);
    expect(key.currentState!.current!.id, 'c');
  });

  testWidgets(
    'Read stays visible while long book details scroll at large text',
    (tester) async {
      final opened = <String>[];
      await pumpStage(
        tester,
        size: const Size(320, 368),
        textScale: 2,
        reduceMotion: true,
        books: const [
          ShelfBook(
            id: 'long',
            title:
                'A Long Book Title That Needs Several Lines On A Small Screen',
            author: 'An Author With A Long Name',
            blurb:
                'The full description remains available below the cover. '
                'The reader can open the book without scrolling past it.',
            binding: BookBinding.hardback,
            progress: 0.42,
          ),
        ],
        onOpen: (book) => opened.add(book.id),
      );
      await key.currentState!.pickUpAt(0);
      await tester.pumpAndSettle();
      final open = find.byKey(const ValueKey('open-shelf-book'));
      expect(open.hitTestable(), findsOneWidget);
      final position = tester.getRect(open);
      expect(position.width, greaterThan(260));
      await tester.drag(
        find.byKey(const ValueKey('held-book-details')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(open), position);
      expect(open.hitTestable(), findsOneWidget);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(opened, ['long']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wishlist entries open Books to buy without reading progress', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpStage(
      tester,
      reduceMotion: true,
      books: const [
        ShelfBook(
          id: 'wish',
          title: 'A book to buy',
          author: 'A writer',
          binding: BookBinding.hardback,
          isWishlist: true,
        ),
      ],
      onOpen: (book) => opened.add(book.id),
    );
    await key.currentState!.pickUp();
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Books to buy'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-shelf-book')));
    await tester.pumpAndSettle();
    expect(opened, ['wish']);
  });

  testWidgets('reordering keeps the held identity; removal returns safely', (
    tester,
  ) async {
    final phases = <ShelfPhase>[];
    await pumpStage(tester, onPhaseChanged: phases.add);
    await tester.tap(spine('b'));
    await tester.pumpAndSettle();
    await pumpStage(
      tester,
      books: [_books[1], _books[2], _books[0]],
      onPhaseChanged: phases.add,
    );
    expect(key.currentState!.current!.id, 'b');
    expect(key.currentState!.index, 0);
    expect(key.currentState!.phase, ShelfPhase.held);
    await pumpStage(
      tester,
      books: [_books[2], _books[0]],
      onPhaseChanged: phases.add,
    );
    expect(key.currentState!.phase, ShelfPhase.shelved);
    expect(phases.last, ShelfPhase.shelved);
    await pumpStage(tester, books: []);
    expect(key.currentState!.current, isNull);
    await key.currentState!.pickUp();
    expect(key.currentState!.phase, ShelfPhase.shelved);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removal cancels an opening callback', (tester) async {
    final opened = <String>[];
    await pumpStage(tester, onOpen: (book) => opened.add(book.id));
    await key.currentState!.pickUpAt(1);
    unawaited(key.currentState!.openBook());
    await tester.pump();
    await pumpStage(
      tester,
      books: [_books.first],
      onOpen: (book) => opened.add(book.id),
    );
    await tester.pump(ShelfStage.openDuration);
    expect(opened, isEmpty);
    expect(key.currentState!.phase, ShelfPhase.shelved);
  });

  testWidgets('the native row scrolls and keeps its position after return', (
    tester,
  ) async {
    final many = [
      for (var i = 0; i < 24; i++)
        ShelfBook(
          id: '$i',
          title: 'Book $i',
          author: 'Author $i',
          binding: BookBinding.hardback,
        ),
    ];
    await pumpStage(tester, books: many);
    final row = find.byKey(const ValueKey('shelf-spines'));
    await tester.drag(row, const Offset(-400, 0));
    await tester.pumpAndSettle();
    final scroll = tester.widget<ListView>(row).controller!;
    final offset = scroll.offset;
    expect(offset, greaterThan(0));
    await key.currentState!.pickUpAt(6);
    await tester.pumpAndSettle();
    await key.currentState!.putBack();
    await tester.pumpAndSettle();
    expect(scroll.offset, closeTo(offset, 0.1));
    await pumpStage(tester, books: many.reversed.toList());
    expect(scroll.offset, 0, reason: 'A new order starts at its first book.');
    expect(key.currentState!.current!.id, '23');
  });

  for (final direction in TextDirection.values) {
    testWidgets('keyboard selects and returns a book in $direction', (
      tester,
    ) async {
      await pumpStage(tester, direction: direction, reduceMotion: true);
      final first = tester.widget<InkWell>(
        find.descendant(of: spine('a'), matching: find.byType(InkWell)),
      );
      first.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(
        direction == TextDirection.ltr
            ? LogicalKeyboardKey.arrowRight
            : LogicalKeyboardKey.arrowLeft,
      );
      await tester.pumpAndSettle();
      expect(key.currentState!.current!.id, 'b');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(key.currentState!.phase, ShelfPhase.held);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(key.currentState!.phase, ShelfPhase.shelved);
    });
  }

  testWidgets('each spine exposes the full book label and tap action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpStage(tester);
    final node = tester.getSemantics(
      find.bySemanticsLabel('The Moonstone, Wilkie Collins'),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  for (final size in [
    const Size(320, 368),
    const Size(412, 715),
    const Size(1100, 600),
  ]) {
    testWidgets('shelf and held details fit $size with large text', (
      tester,
    ) async {
      await pumpStage(tester, size: size, textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(spine('b'));
      await tester.pumpAndSettle();
      await tester.tap(spine('b'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final title = tester.widget<Text>(
        find.byKey(const ValueKey('held-book-title')),
      );
      expect(title.maxLines, isNull);
      expect(
        find.byKey(const ValueKey('open-shelf-book')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion opens immediately', (tester) async {
    ShelfBook? opened;
    await pumpStage(
      tester,
      reduceMotion: true,
      onOpen: (book) => opened = book,
    );
    await key.currentState!.pickUpAt(1);
    await key.currentState!.openBook();
    await tester.pump();
    expect(opened?.id, 'b');
  });
}
