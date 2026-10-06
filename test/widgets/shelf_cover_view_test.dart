import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shelf_home_fixtures.dart';

const _books = [
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

Finder _cover(String id) => find.byKey(ValueKey('shelf-cover-$id'));

Future<void> _pumpStage(
  WidgetTester tester,
  GlobalKey<ShelfStageState> key, {
  List<ShelfBook> books = _books,
  ValueChanged<ShelfBook>? onOpen,
  Size size = const Size(412, 715),
  double textScale = 1,
  bool reduceMotion = true,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
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
            showCovers: true,
            onOpen: onOpen,
            pickUpHint: 'Select a book',
            openHint: 'Open book',
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  test(
      'spines remain the default and cover preference preserves other settings',
      () async {
    final prefs = Prefs();
    expect(prefs.shelfCoverView, isFalse);
    await prefs.prefs.setString('shelfCoverView', 'unknown');
    expect(prefs.shelfCoverView, isFalse);
    prefs.shelfUniformSpines = true;
    final readerTheme = prefs.readTheme.toJson();
    prefs.shelfCoverView = true;
    await prefs.initPrefs();
    expect(prefs.shelfCoverView, isTrue);
    expect(prefs.shelfUniformSpines, isTrue);
    expect(prefs.readTheme.toJson(), readerTheme);
    prefs.shelfCoverView = false;
    await prefs.initPrefs();
    expect(prefs.shelfCoverView, isFalse);
  });

  testWidgets('covers preserve held identity and cancel removed opening books',
      (tester) async {
    final key = GlobalKey<ShelfStageState>();
    final opened = <String>[];
    void open(ShelfBook book) => opened.add(book.id);
    await _pumpStage(tester, key, onOpen: open, reduceMotion: false);
    await tester.tap(_cover('b'));
    await tester.pumpAndSettle();
    expect(key.currentState!.phase, ShelfPhase.held);
    expect(find.text('50%'), findsOneWidget);
    await _pumpStage(tester, key,
        books: [_books[1], _books[2], _books[0]],
        onOpen: open,
        reduceMotion: false);
    expect(key.currentState!.current!.id, 'b');
    expect(key.currentState!.phase, ShelfPhase.held);
    await _pumpStage(tester, key,
        books: [_books[2], _books[0]], onOpen: open, reduceMotion: false);
    expect(key.currentState!.phase, ShelfPhase.shelved);
    unawaited(key.currentState!.openBook());
    await tester.pump();
    await _pumpStage(tester, key,
        books: [_books[0]], onOpen: open, reduceMotion: false);
    expect(opened, isEmpty);
    expect(key.currentState!.phase, ShelfPhase.shelved);
    await key.currentState!.pickUp();
    unawaited(key.currentState!.openBook());
    unawaited(key.currentState!.openBook());
    await tester.pumpAndSettle();
    expect(opened, ['a']);
    key.currentState!.reset();
    await tester.pumpAndSettle();
    expect(_cover('a').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
        'covers support labelled keyboard selection and Back in $direction',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final key = GlobalKey<ShelfStageState>();
      await _pumpStage(tester, key, direction: direction);
      final label = tester
          .getSemantics(find.bySemanticsLabel('The Moonstone, Wilkie Collins'));
      expect(label.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(tester.getSize(_cover('b')).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(_cover('b')).height, greaterThanOrEqualTo(48));
      tester.widget<InkWell>(_cover('a')).focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(direction == TextDirection.ltr
          ? LogicalKeyboardKey.arrowRight
          : LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(key.currentState!.current!.id, 'b');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(key.currentState!.phase, ShelfPhase.held);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('held-book-title')))
              .data,
          'The Moonstone');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(key.currentState!.phase, ShelfPhase.shelved);
      expect(tester.widget<InkWell>(_cover('b')).focusNode!.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(key.currentState!.current!.id, 'c');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets(
      '500 covers build only nearby tiles and retain their scroll position',
      (tester) async {
    final books = [
      for (var index = 0; index < 500; index++)
        ShelfBook(
          id: '$index',
          title: 'Book $index',
          author: 'Author $index',
          binding: BookBinding.hardback,
        ),
    ];
    final key = GlobalKey<ShelfStageState>();
    await _pumpStage(tester, key, books: books);
    final tiles = find.byWidgetPredicate((widget) =>
        widget.key is ValueKey<String> &&
        (widget.key! as ValueKey<String>).value.startsWith('shelf-cover-'));
    expect(tiles.evaluate().length, inInclusiveRange(1, 40));
    expect(_cover('499'), findsNothing);
    final position = tester
        .state<ScrollableState>(find.descendant(
          of: find.byKey(const ValueKey('shelf-covers')),
          matching: find.byType(Scrollable),
        ))
        .position;
    position.jumpTo(1500);
    await tester.pumpAndSettle();
    final offset = position.pixels;
    expect(offset, 1500);
    expect(tiles.evaluate().length, inInclusiveRange(1, 40));
    await tester.tap(tiles.hitTestable().first);
    await tester.pumpAndSettle();
    expect(key.currentState!.phase, ShelfPhase.held);
    await tester.tap(find.byKey(const ValueKey('return-shelf-book')));
    await tester.pumpAndSettle();
    expect(position.pixels, closeTo(offset, 0.1));
    expect(tiles.evaluate().length, inInclusiveRange(1, 40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced-motion keyboard jumps focus a newly built cover',
      (tester) async {
    final books = [
      for (var index = 0; index < 500; index++)
        ShelfBook(
          id: '$index',
          title: 'Book $index',
          author: 'Author $index',
          binding: BookBinding.hardback,
        ),
    ];
    final key = GlobalKey<ShelfStageState>();
    // A short, wide window makes the next row start beyond the cache extent.
    await _pumpStage(tester, key, books: books, size: const Size(2800, 300));
    expect(_cover('8'), findsNothing);
    tester.widget<InkWell>(_cover('0')).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(key.currentState!.current!.id, '8');
    expect(_cover('8').hitTestable(), findsOneWidget);
    expect(tester.widget<InkWell>(_cover('8')).focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(key.currentState!.phase, ShelfPhase.held);
    expect(key.currentState!.current!.id, '8',
        reason: 'Enter must open the newly selected cover, not the old focus');
    expect(tester.takeException(), isNull);
  });

  for (final (size, textScale) in [
    (const Size(320, 568), 2.0),
    (const Size(568, 240), 1.0),
  ]) {
    testWidgets(
        'covers retain the readable list fallback at $size and $textScale text',
        (tester) async {
      final key = GlobalKey<ShelfStageState>();
      await _pumpStage(tester, key,
          size: size, textScale: textScale, direction: TextDirection.rtl);
      expect(find.byKey(const ValueKey('shelf-covers')), findsNothing);
      final book = find.byKey(const ValueKey('shelf-spine-b'));
      await tester.ensureVisible(book);
      await tester.pumpAndSettle();
      expect(book.hitTestable(), findsOneWidget);
      await tester.tap(book);
      await tester.pumpAndSettle();
      final open = find.byKey(const ValueKey('open-shelf-book'));
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      expect(open.hitTestable(), findsOneWidget);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('held-book-title')))
              .maxLines,
          isNull);
      expect(tester.takeException(), isNull);
    });
  }

  // One ShelfHome ProviderScope per isolate: its Sync notifier is a singleton.
  testWidgets(
      'Library view switching keeps filters, shelf, actions and progress',
      (tester) async {
    fakeData = populatedData();
    final target = fakeData.readingNow.last
      ..rating = 4
      ..readingPercentage = 0.42
      ..lastReadPosition = 'epubcfi(/6/2!/4/2/1:12)';
    fakeData.readingNow[1].rating = 5;
    fakeData.toBeRead.first.rating = 4;
    final originalPosition = target.lastReadPosition;
    final actions = <(String, int)>[];
    final handle = LibraryBackHandle();
    addTearDown(handle.dispose);
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: newTestOverrides(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        theme: ThemeData(
            colorScheme: PaperfoldTokens.colorScheme(Brightness.light)),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: ShelfHomePage(
          backHandle: handle,
          bookActions: ShelfHomeBookActions(
            open: (book) => actions.add(('open', book.id)),
            details: (book) => actions.add(('details', book.id)),
            shelves: (book) => actions.add(('shelves', book.id)),
            customise: (book) => actions.add(('customise', book.id)),
            notes: (book) => actions.add(('notes', book.id)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final bookcase = tester.state<BookcaseState>(find.byType(Bookcase));
    expect(tester.widget<Bookcase>(find.byType(Bookcase)).showCovers, isFalse);
    final controls =
        ProviderScope.containerOf(tester.element(find.byType(ShelfHomePage)))
            .read(shelfHomeControlsProvider);
    controls.setSortField(ShelfSortField.title);
    controls.setSortDirection(ShelfSortDirection.ascending);
    controls.setMinimumRating(4);
    await tester.pumpAndSettle();
    final visibleIds = tester
        .widget<Bookcase>(find.byType(Bookcase))
        .shelves
        .first
        .books
        .map((book) => book.id)
        .toList();
    expect(visibleIds, ['book-8', 'book-6']);

    Future<void> selectView(String label) async {
      final control = find.byKey(const ValueKey('shelf-view-control'));
      await tester.ensureVisible(control);
      await tester.tap(control);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckedPopupMenuItem<bool>, label));
      await tester.pumpAndSettle();
    }

    await selectView('Covers');
    expect(Prefs().shelfCoverView, isTrue);
    expect(tester.state<BookcaseState>(find.byType(Bookcase)), same(bookcase));
    expect(
        tester
            .widget<Bookcase>(find.byType(Bookcase))
            .shelves
            .first
            .books
            .map((book) => book.id),
        visibleIds);
    await tester.tap(_cover('book-8'));
    await tester.pumpAndSettle();
    for (final action in ['details', 'shelves', 'customise', 'notes']) {
      final button = find.byKey(ValueKey('shelf-book-$action'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
    expect(handle.canTakeBack, isTrue);
    expect(handle.takeBack(), isTrue);
    await tester.pumpAndSettle();
    expect(handle.canTakeBack, isFalse);
    expect(bookcase.activeStage!.phase, ShelfPhase.shelved);
    await tester.tap(_cover('book-8'));
    await tester.pumpAndSettle();
    final open = find.byKey(const ValueKey('open-shelf-book'));
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(actions, [
      ('details', 8),
      ('shelves', 8),
      ('customise', 8),
      ('notes', 8),
      ('open', 8),
    ]);
    expect(target.lastReadPosition, originalPosition);
    expect(target.readingPercentage, 0.42);
    await bookcase.climbTo(2);
    await tester.pumpAndSettle();
    await selectView('Spines');
    expect(Prefs().shelfCoverView, isFalse);
    expect(bookcase.shelf, 2);
    expect(controls.minimumRating, 4);
    expect(controls.sortField, ShelfSortField.title);
    expect(find.byKey(const ValueKey('shelf-spine-book-3')), findsOneWidget);
    await selectView('Covers');
    expect(bookcase.shelf, 2);
    expect(_cover('book-3'), findsOneWidget);
    controls.clearFilters();
    await tester.pumpAndSettle();
    await bookcase.climbTo(4);
    await tester.pumpAndSettle();
    await tester.tap(_cover('wishlist-5'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(ShelfCollectionPage), findsOneWidget);
    expect(actions.where((entry) => entry.$1 == 'open'), [('open', 8)]);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(bookcase.shelf, 4);
    expect(handle.canTakeBack, isFalse);
    expect(tester.takeException(), isNull);
  });
}
