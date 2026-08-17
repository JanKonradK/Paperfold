import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ShelfController extends ShelfHomeController {
  @override
  Future<ShelfHomeData> build() async => _data;

  @override
  Future<void> refresh() async => state = AsyncData(_data);
}

class _BookListController extends BookList {
  @override
  Future<List<List<Book>>> build() async => const [];
}

Book _book(int id, String title) {
  return Book(
    id: id,
    title: title,
    coverPath: '',
    filePath: 'book-$id.epub',
    lastReadPosition: '',
    readingPercentage: 0,
    author: 'Ursula Le Guin',
    isDeleted: false,
    rating: 0,
    status: BookStatus.reading,
    createTime: DateTime.utc(2026),
    updateTime: DateTime.utc(2026),
  );
}

final _data = ShelfHomeData(
  readingNow: [
    _book(1, 'The Left Hand of Darkness'),
    _book(2, 'The Tombs of Atuan'),
    _book(3, 'The Farthest Shore'),
    _book(4, 'Tehanu'),
  ],
  favourites: const [],
  toBeRead: const [],
  finished: const [],
  booksToBuy: const [],
);

/// One pumped page, and only one.
///
/// `Sync` is a Riverpod notifier and a hand-rolled singleton at once, so its
/// internal element reference can only be set by a single ProviderContainer per
/// isolate. A second `pumpWidget` of this page in this file throws
/// LateInitializationError out of a widget that has nothing to do with the
/// shelf. See the note at the top of shelf_home_fixtures.dart.
void main() {
  testWidgets('the library stands its books on one bookcase', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();

    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shelfHomeProvider.overrideWith(_ShelfController.new),
          bookListProvider.overrideWith(_BookListController.new),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
          ),
          home: const ShelfHomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // One piece of furniture, not five strips stacked down a scroll view.
    final bookcase = find.byType(Bookcase);
    expect(bookcase, findsOneWidget);

    final shelves = tester.widget<Bookcase>(bookcase).shelves;
    expect(shelves.length, 5);
    // The books arrive on the shelf they belong to, in the order given.
    expect(
      shelves.first.books.map((book) => book.title),
      [
        'The Left Hand of Darkness',
        'The Tombs of Atuan',
        'The Farthest Shore',
        'Tehanu',
      ],
    );

    // The bookcase fills the tab rather than sitting in a fixed-height band,
    // which is what let the old strips clip their own books at a raised system
    // font size.
    final rect = tester.getRect(bookcase);
    expect(rect.width, greaterThan(300));
    expect(rect.height, greaterThan(400));

    expect(tester.takeException(), isNull);
  });
}
