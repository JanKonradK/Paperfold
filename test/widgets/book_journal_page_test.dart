import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/book_review.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/page/journal/book_journal_page.dart';
import 'package:paperfold/page/journal/book_review_page.dart';
import 'package:paperfold/utils/color_scheme.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _JournalDao extends JournalDao {
  BookReview? review;
  List<JournalPage> pages = [];
  bool failLoad = false;
  int reviewLoads = 0;

  @override
  Future<BookReview?> findReview(int bookId) async {
    reviewLoads++;
    if (failLoad) throw StateError('Private database details');
    return review;
  }

  @override
  Future<BookReview> reviewOrEmpty(int bookId) async =>
      review ?? BookReview(bookId: bookId);

  @override
  Future<List<JournalPage>> listPages(int bookId) async => pages;

  @override
  Future<int?> saveReview(BookReview value) async {
    review = value.isEmpty ? null : value.copyWith(id: value.id ?? 1);
    return review?.id;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });

  Future<void> openHub(
    WidgetTester tester,
    _JournalDao dao, {
    Book? book,
    Size size = const Size(412, 915),
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: L10n.localizationsDelegates,
          supportedLocales: L10n.supportedLocales,
          locale: const Locale('en'),
          theme: paperfoldComponentTheme(ThemeData(
            useMaterial3: true,
            colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
          )),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: BookJournalPage(book: book ?? Book.mock(), dao: dao),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('load failure gives a working retry without raw errors',
      (tester) async {
    final dao = _JournalDao()..failLoad = true;
    await openHub(tester, dao);
    expect(find.text('Your journal could not be loaded.'), findsOneWidget);
    expect(find.textContaining('Private database details'), findsNothing);

    dao
      ..failLoad = false
      ..review = const BookReview(bookId: 1, thoughts: 'Found my writing');
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(dao.reviewLoads, 2);
    expect(find.text('Found my writing'), findsOneWidget);
    expect(find.text('Your journal could not be loaded.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty export explains the next step without a save picker',
      (tester) async {
    final dao = _JournalDao()
      ..review = const BookReview(bookId: 1)
      ..pages = [const JournalPage(bookId: 1, pageIndex: 0)];
    await openHub(tester, dao);
    expect(find.text('Record your rating, favourite moments, and thoughts.'),
        findsOneWidget);

    await tester.tap(find.byTooltip('Export journal'));
    await tester.pumpAndSettle();

    expect(find.text('Add a review or a page before exporting your journal.'),
        findsOneWidget);
    expect(find.text('Your journal could not be exported. Try again.'),
        findsNothing);
    expect(dao.reviewLoads, 2,
        reason: 'Export must read the latest saved text.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning from the editor refreshes the saved writing',
      (tester) async {
    final dao = _JournalDao();
    await openHub(tester, dao);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.byType(BookReviewPage), findsOneWidget);

    final thoughts = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Thoughts');
    await tester.ensureVisible(thoughts);
    await tester.enterText(thoughts, 'A thought saved on return.');
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(BookJournalPage), findsOneWidget);
    expect(find.text('A thought saved on return.'), findsOneWidget);
    expect(dao.review?.thoughts, 'A thought saved on return.');
    expect(dao.reviewLoads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow large text and invalid progress stay readable',
      (tester) async {
    final book = Book.mock().copyWith(
      title: 'A very long book title about a journey across the winter world',
      author: 'A long author name and another author',
      readingPercentage: double.nan,
    );
    final dao = _JournalDao()
      ..review = const BookReview(
        bookId: 1,
        thoughts:
            'A longer reflection that must fit without clipping controls.',
      );
    await openHub(tester, dao,
        book: book, size: const Size(320, 640), textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('0% read'), findsOneWidget);
    expect(MediaQuery.textScalerOf(tester.element(find.byType(BookCover))),
        TextScaler.noScaling);
    final title = find.text(book.title).last;
    expect(MediaQuery.textScalerOf(tester.element(title)).scale(16), 32);
    await tester.scrollUntilVisible(find.text('Review'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Journal pages'), 250,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });
}
