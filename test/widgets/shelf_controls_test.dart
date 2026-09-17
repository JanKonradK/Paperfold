import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/widgets/bookshelf/shelf_controls/shelf_book_actions.dart';
import 'package:paperfold/widgets/bookshelf/shelf_controls/shelf_controls.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sorting, filtering and the held-book controls, tested away from the page.
///
/// None of this pumps ShelfHomePage. `Sync` is a Riverpod notifier and a
/// hand-rolled singleton at once, so a second ProviderContainer in one isolate
/// throws out of a widget that has nothing to do with the shelf. Testing the
/// controller and the option bar directly avoids that entirely, and it fails on
/// the thing that broke rather than on a whole screen.

Book _book(
  int id,
  String title, {
  String author = 'A Writer',
  BookStatus status = BookStatus.reading,
  double rating = 0,
  double progress = 0,
  int day = 1,
}) {
  return Book(
    id: id,
    title: title,
    coverPath: '',
    filePath: 'book-$id.epub',
    lastReadPosition: '',
    readingPercentage: progress,
    author: author,
    isDeleted: false,
    rating: rating,
    status: status,
    createTime: DateTime.utc(2026, 1, day),
    updateTime: DateTime.utc(2026, 1, day),
  );
}

final _shelf = [
  _book(1, 'Tehanu', author: 'Le Guin', rating: 5, progress: 0.9, day: 3),
  _book(2, 'A Wizard of Earthsea',
      author: 'Anon', status: BookStatus.finished, rating: 2, day: 1),
  _book(3, 'The Farthest Shore',
      author: 'Zed', status: BookStatus.notStarted, rating: 4, day: 2),
];

List<String> _titles(List<Book> books) =>
    books.map((book) => book.title).toList();

void main() {
  late ShelfHomeControls controls;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
    controls = ShelfHomeControls();
  });

  group('sorting', () {
    test('series order is numeric, grouped, reversible, and saved', () {
      Book volume(int id, String title, String series, String? number) =>
          _book(id, title)
            ..series = series
            ..volume = number;
      final books = [
        volume(10, 'Book ten', 'First series', '10'),
        volume(20, 'Other first', 'Second series', '1'),
        volume(2, 'Book two', 'First series', '2'),
        _book(30, 'A standalone'),
        volume(3, 'Short story', 'First series', '2.5'),
        volume(11, 'Unknown volume', 'First series', null),
        volume(1, 'Book one', 'First series', '1'),
        volume(9, 'Book nine', 'First series', '9'),
      ];
      controls.setSortField(ShelfSortField.series);
      expect(controls.sortDirection, ShelfSortDirection.ascending);
      expect(controls.booksForShelf(books, {}).map((b) => b.id),
          [1, 2, 3, 9, 10, 11, 20, 30]);
      expect(books.first.id, 10, reason: 'Sorting must not mutate the source.');
      final restored = ShelfHomeControls();
      expect(restored.sortField, ShelfSortField.series);
      expect(restored.sortDirection, ShelfSortDirection.ascending);
      restored.setSortField(ShelfSortField.dateAdded);
      expect(restored.sortDirection, ShelfSortDirection.descending,
          reason:
              'Series order must preserve the existing date sort direction.');
      restored.setSortField(ShelfSortField.series);
      controls.setSortDirection(ShelfSortDirection.descending);
      expect(controls.booksForShelf(books, {}).map((b) => b.id),
          [10, 9, 3, 2, 1, 11, 20, 30]);
      expect(ShelfHomeControls().sortDirection, ShelfSortDirection.descending);
      controls.setSortField(ShelfSortField.title);
      controls.setSortDirection(ShelfSortDirection.ascending);
      controls.setSortField(ShelfSortField.series);
      expect(controls.sortDirection, ShelfSortDirection.descending);
      controls.setSortField(ShelfSortField.title);
      expect(controls.sortDirection, ShelfSortDirection.ascending);
    });

    test('by title, ascending and descending', () {
      controls
        ..setSortField(ShelfSortField.title)
        ..setSortDirection(ShelfSortDirection.ascending);
      expect(
        _titles(controls.booksForShelf(_shelf, const {})),
        ['A Wizard of Earthsea', 'Tehanu', 'The Farthest Shore'],
      );

      controls.setSortDirection(ShelfSortDirection.descending);
      expect(
        _titles(controls.booksForShelf(_shelf, const {})),
        ['The Farthest Shore', 'Tehanu', 'A Wizard of Earthsea'],
      );
    });

    test('by author', () {
      controls
        ..setSortField(ShelfSortField.author)
        ..setSortDirection(ShelfSortDirection.ascending);
      expect(
        controls
            .booksForShelf(_shelf, const {})
            .map((book) => book.author)
            .toList(),
        ['Anon', 'Le Guin', 'Zed'],
      );
    });

    test('by rating', () {
      controls
        ..setSortField(ShelfSortField.rating)
        ..setSortDirection(ShelfSortDirection.descending);
      expect(
        controls.booksForShelf(_shelf, const {}).map((b) => b.rating).toList(),
        [5.0, 4.0, 2.0],
      );
    });

    test('by progress', () {
      controls
        ..setSortField(ShelfSortField.progress)
        ..setSortDirection(ShelfSortDirection.descending);
      expect(
        _titles(controls.booksForShelf(_shelf, const {})).first,
        'Tehanu',
      );
    });
  });

  testWidgets('the sort sheet offers series order and first-to-last by default',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () => showShelfSortSheet(context, controls),
                    child: const Text('Sort'),
                  ))),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shelf-sort-series')));
    await tester.pumpAndSettle();
    expect(controls.sortField, ShelfSortField.series);
    expect(controls.sortDirection, ShelfSortDirection.ascending);
    await tester.ensureVisible(find.text('First to last'));
    await tester.pumpAndSettle();
    expect(find.text('Last to first'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('filtering', () {
    test('a status filter hides the books that do not match', () {
      controls.toggleStatus(BookStatus.finished);
      expect(
        _titles(controls.booksForShelf(_shelf, const {})),
        ['A Wizard of Earthsea'],
      );
      expect(controls.hasFilters, isTrue);
      expect(controls.filterCount, 1);
    });

    test('dismissing the status filter brings the books back', () {
      controls.toggleStatus(BookStatus.finished);
      controls.toggleStatus(BookStatus.finished);

      expect(controls.hasFilters, isFalse);
      expect(controls.booksForShelf(_shelf, const {}).length, 3);
    });

    test('a minimum rating hides anything below it', () {
      controls.setMinimumRating(4);
      expect(
        _titles(controls.booksForShelf(_shelf, const {})).toSet(),
        {'Tehanu', 'The Farthest Shore'},
      );
    });

    test('a tag filter keeps only the books carrying that tag', () {
      controls.toggleTag(7);
      final tags = <int, List<int>>{
        1: [7],
        2: [9],
      };
      expect(_titles(controls.booksForShelf(_shelf, tags)), ['Tehanu']);
    });

    test('clearing puts every filter back and leaves the shelf whole', () {
      controls
        ..toggleStatus(BookStatus.finished)
        ..setMinimumRating(5)
        ..toggleTag(7);
      expect(controls.filterCount, 3);

      controls.clearFilters();

      expect(controls.hasFilters, isFalse);
      expect(controls.filterCount, 0);
      expect(controls.booksForShelf(_shelf, const {}).length, 3);
    });

    test('a filter that matches nothing empties the shelf', () {
      controls.setMinimumRating(5);
      controls.toggleStatus(BookStatus.notStarted);

      expect(controls.booksForShelf(_shelf, const {}), isEmpty);
    });

    test('an empty filtered shelf can clear filters and restore every book',
        () {
      controls
        ..setMinimumRating(5)
        ..toggleStatus(BookStatus.notStarted);
      expect(controls.hasFilters, isTrue);
      expect(controls.booksForShelf(_shelf, const {}), isEmpty);

      controls.clearFilters();

      expect(controls.hasFilters, isFalse);
      expect(controls.filterCount, 0);
      expect(controls.booksForShelf(_shelf, const {}).length, 3);
    });
  });

  testWidgets('active rating filter shows a chip and dismissal restores books',
      (tester) async {
    controls.setMinimumRating(4);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: AnimatedBuilder(
            animation: controls,
            builder: (context, child) => ShelfFilterChips(
              controls: controls,
              tags: const [],
            ),
          ),
        ),
      ),
    );
    // The localisations load deferred, so the chips have no labels on the first
    // frame. Nothing here animates, so settling is safe.
    await tester.pumpAndSettle();

    expect(find.text('4+ stars'), findsOneWidget);
    expect(find.byKey(const ValueKey('shelf-filter-rating')), findsOneWidget);
    expect(
      _titles(controls.booksForShelf(_shelf, const {})).toSet(),
      {'Tehanu', 'The Farthest Shore'},
    );

    final chip = tester.widget<InputChip>(find.descendant(
      of: find.byKey(const ValueKey('shelf-filter-rating')),
      matching: find.byType(InputChip),
    ));
    chip.onDeleted!();
    await tester.pump();

    expect(find.text('4+ stars'), findsNothing);
    expect(controls.hasFilters, isFalse);
    expect(controls.booksForShelf(_shelf, const {}).length, 3);
  });

  test('the choice survives the reader closing the application', () async {
    controls
      ..setSortField(ShelfSortField.title)
      ..setSortDirection(ShelfSortDirection.ascending)
      ..toggleStatus(BookStatus.finished)
      ..setMinimumRating(3)
      ..toggleTag(4);

    // A second controller reads what the first one wrote, which is what a cold
    // start does.
    final restored = ShelfHomeControls();

    expect(restored.sortField, ShelfSortField.title);
    expect(restored.sortDirection, ShelfSortDirection.ascending);
    expect(restored.statusFilters, {BookStatus.finished});
    expect(restored.minimumRating, 3);
    expect(restored.tagFilters, {4});
  });

  testWidgets('each of the four held-book controls fires its own action',
      (tester) async {
    final fired = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: ShelfBookOptionBar(
            onDetails: () => fired.add('details'),
            onShelves: () => fired.add('shelves'),
            onCustomise: () => fired.add('customise'),
            onNotes: () => fired.add('notes'),
          ),
        ),
      ),
    );
    // The localisations are loaded deferred, so one frame is not enough for the
    // bar to have any labels and therefore any children.
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    for (final name in ['details', 'shelves', 'customise', 'notes']) {
      await tester.tap(find.byKey(ValueKey('shelf-book-$name')));
      await tester.pump();
    }

    expect(fired, ['details', 'shelves', 'customise', 'notes']);
  });

  testWidgets('the four plates fit the head band on a narrow phone',
      (tester) async {
    // The defect this guards: the plates were set to a constant width and a
    // constant gap, which came to 330 — ten pixels more than a 320-wide screen
    // has. A Row that does not fit does not shrink; it paints the striped
    // overflow bar over the one row of controls the reader came here for.
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: ShelfStage.headBand,
            child: Center(
              child: ShelfBookOptionBar(
                onDetails: _noop,
                onShelves: _noop,
                onCustomise: _noop,
                onNotes: _noop,
              ),
            ),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(tester.takeException(), isNull);
    final bar = tester.getRect(find.byType(ShelfBookOptionBar));
    expect(bar.width, lessThanOrEqualTo(320));
    expect(bar.height, lessThanOrEqualTo(ShelfStage.headBand));

    // And every plate is still a target a thumb can find.
    for (final name in ['details', 'shelves', 'customise', 'notes']) {
      final plate = tester.getRect(find.byKey(ValueKey('shelf-book-$name')));
      expect(plate.width, greaterThanOrEqualTo(48), reason: name);
      expect(plate.height, greaterThanOrEqualTo(48), reason: name);
    }
  });

  testWidgets('the option bar settles, because nothing on it animates',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: ShelfBookOptionBar(
              onDetails: _noop,
              onShelves: _noop,
              onCustomise: _noop,
              onNotes: _noop,
            ),
          ),
        ),
      ),
    );
    // The row used to breathe under a repeating halo, which never let the
    // tree settle. Nothing on it moves now.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
