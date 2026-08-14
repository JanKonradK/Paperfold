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
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/widgets/bookshelf/leading_book.dart';
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

void main() {
  testWidgets('shelf contains upright books and supports uniform mode',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
    expect(Prefs().shelfUniformSpines, isFalse);

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

    final viewport = find.byKey(const ValueKey('shelf-spine-viewport-0'));
    final spines = find.descendant(
      of: viewport,
      matching: find.byType(BookSpine),
    );
    final leading = find.descendant(
      of: viewport,
      matching: find.byType(LeadingBook),
    );
    final viewportRect = tester.getRect(viewport);

    // Four books: the first stands face out, the other three are spine-on.
    expect(leading, findsOneWidget);
    expect(spines, findsNWidgets(3));
    expect(tester.widget<ListView>(viewport).clipBehavior, Clip.hardEdge);
    for (var index = 0; index < 3; index++) {
      final spine = tester.widget<BookSpine>(spines.at(index));
      final rect = tester.getRect(spines.at(index));
      expect(spine.uniform, isFalse);
      // The row is reversed: it rests against its RIGHT edge and lays out
      // leftward, so the right edge is the one nothing overflows and the left
      // is where the clipping happens. Checking both would be checking that
      // the shelf has nothing to scroll to.
      expect(rect.right, lessThanOrEqualTo(viewportRect.right + 0.01));
      expect(rect.height, greaterThan(rect.width * 3));
    }

    // The face-out book stands on the same line as the spines beside it, so
    // the row does not step. Its base is its box less the reflection.
    final leadingRect = tester.getRect(leading);
    final neighbourRect = tester.getRect(spines.at(0));
    expect(
      leadingRect.bottom - BookSpine.reflectionDepth,
      moreOrLessEquals(neighbourRect.bottom - BookSpine.reflectionDepth,
          epsilon: 0.5),
      reason: 'the face-out book does not stand on the shelf line',
    );
    // And it is the book at the right-hand end of the row, which is where a
    // display copy stands.
    expect(leadingRect.right, lessThanOrEqualTo(viewportRect.right + 0.01));
    expect(
      leadingRect.left,
      greaterThan(tester.getRect(spines.at(0)).left),
      reason: 'the display copy is not at the right-hand end of the row',
    );

    Prefs().shelfUniformSpines = true;
    await tester.pump();

    final uniformSizes = [
      for (var id = 1; id <= 4; id++)
        tester.getSize(find.byKey(ValueKey('book-spine-surface-book-$id'))),
    ];
    expect(
      uniformSizes.map((size) => size.width).toSet(),
      {BookSpine.uniformWidth},
    );
    expect(
      uniformSizes.map((size) => size.height).toSet(),
      {BookSpine.uniformHeight},
    );
    expect(tester.takeException(), isNull);
  });
}
