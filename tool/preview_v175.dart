import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/dao/search_repository.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/book_review.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/models/search_journal_result.dart';
import 'package:paperfold/models/search_result_data.dart';
import 'package:paperfold/page/journal/book_journal_page.dart';
import 'package:paperfold/page/journal/dot_pages_page.dart';
import 'package:paperfold/page/search/search_page.dart';
import 'package:paperfold/providers/search.dart';
import 'package:paperfold/utils/color_scheme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Demo data only. Run: flutter test tool/preview_v175.dart --concurrency=1
final _book = Book.mock().copyWith(
  title: 'The Left Hand of Darkness',
  author: 'Ursula K. Le Guin',
  readingPercentage: 0.42,
);

const _review = BookReview(
  id: 1,
  bookId: 1,
  ratingOverall: 5,
  thoughts: 'A book about trust, distance, and learning to see another '
      'person’s world. I want to return to the winter journey.',
);

const _pages = [
  JournalPage(
    id: 1,
    bookId: 1,
    pageIndex: 0,
    sourceExcerpt: 'Light is the left hand of darkness.',
    sourceChapter: 'The journey across the ice',
    sourceCfi: 'epubcfi(/6/2!/4/2/1:0)',
    body: 'This is the passage I want to keep. The contrast feels different '
        'after the winter journey.\n\n'
        'How much of understanding someone is learning to sit with uncertainty?',
  ),
  JournalPage(
    id: 2,
    bookId: 1,
    pageIndex: 1,
    body: 'Reading this slowly. Some books ask you to change your pace.',
  ),
];

class _PreviewJournalDao extends JournalDao {
  _PreviewJournalDao({this.empty = false});

  final bool empty;

  @override
  Future<BookReview?> findReview(int bookId) async => empty ? null : _review;

  @override
  Future<List<JournalPage>> listPages(int bookId) async => empty ? [] : _pages;
}

class _PreviewSearchRepository extends SearchRepository {
  @override
  Future<SearchResultData> search(
    String keyword, {
    int? bookId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async =>
      SearchResultData(
        books: [],
        noteGroups: [],
        journalResults: [
          SearchJournalResult(
            book: _book,
            id: 1,
            kind: SearchJournalKind.review,
            text: _review.thoughts,
          ),
          SearchJournalResult(
            book: _book,
            id: 1,
            kind: SearchJournalKind.page,
            pageIndex: 0,
            text: '${_pages.first.sourceExcerpt}\n${_pages.first.body}',
          ),
        ],
      );
}

void main() {
  testWidgets('renders the v1.75 journal and search surfaces', (tester) async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    final previousShadowSetting = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadowSetting);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() async {
      await (FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
          .load();
      await (FontLoader(PaperfoldTypeTokens.journalFamily)
            ..addFont(rootBundle.load('assets/fonts/Philosopher-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Philosopher-Bold.ttf')))
          .load();
      await (FontLoader(PaperfoldTypeTokens.chromeFamily)
            ..addFont(rootBundle.load('assets/fonts/SourceSans3-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/SourceSans3-SemiBold.ttf')))
          .load();
    });
    Directory('tool/preview').createSync(recursive: true);

    Future<void> capture(Widget page, String name, Size size,
        {bool search = false, double textScale = 1}) async {
      // A fresh scope prevents route and search state leaking between shots.
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.physicalSize = size;
      tester.binding.platformDispatcher.textScaleFactorTestValue = textScale;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ProviderScope(
            overrides: [
              searchRepositoryProvider
                  .overrideWithValue(_PreviewSearchRepository()),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('en'),
              localizationsDelegates: L10n.localizationsDelegates,
              supportedLocales: L10n.supportedLocales,
              builder: (context, child) => Theme(
                data: colorSchema(Prefs(), context, Brightness.light),
                child: child!,
              ),
              home: page,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (search) {
        await tester.enterText(find.byType(TextField), 'winter');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: name);
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('tool/preview/v175-$name.png')
              .writeAsBytes(data!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }

    for (final (name, size) in [
      ('phone', const Size(412, 915)),
      ('desktop', const Size(1100, 800)),
    ]) {
      await capture(
        BookJournalPage(book: _book, dao: _PreviewJournalDao()),
        'journal-$name',
        size,
      );
      await capture(
        BookJournalPage(book: _book, dao: _PreviewJournalDao(empty: true)),
        'journal-empty-$name',
        size,
      );
      await capture(
        DotPagesPage(book: _book, dao: _PreviewJournalDao()),
        'passage-$name',
        size,
      );
      await capture(const SearchPage(), 'search-$name', size, search: true);
    }
    await capture(
      BookJournalPage(book: _book, dao: _PreviewJournalDao()),
      'journal-large-text',
      const Size(320, 640),
      textScale: 2,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    debugDisableShadows = previousShadowSetting;
  });
}
