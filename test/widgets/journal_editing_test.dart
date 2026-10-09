import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/book_note.dart';
import 'package:paperfold/models/book_review.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/page/journal/book_review_page.dart';
import 'package:paperfold/page/journal/dot_pages_page.dart';
import 'package:paperfold/widgets/book_notes/add_to_journal_button.dart';

final _book = Book(
  id: 7,
  title: 'A book',
  coverPath: '',
  filePath: 'book.epub',
  lastReadPosition: '',
  readingPercentage: 0,
  author: '',
  isDeleted: false,
  rating: 0,
  status: BookStatus.reading,
  createTime: DateTime(2026),
  updateTime: DateTime(2026),
);

class _JournalDao extends JournalDao {
  final reviews = <int, BookReview>{};
  final pages = <int, JournalPage>{
    1: const JournalPage(id: 1, bookId: 7, pageIndex: 0),
  };
  bool failLoad = false;
  bool failSave = false;
  bool failAdd = false;
  Completer<BookReview>? reviewLoad;
  Completer<void>? saveWait;
  int reviewWrites = 0;

  @override
  Future<BookReview> reviewOrEmpty(int bookId) async {
    if (failLoad) throw StateError('Load failed');
    if (reviewLoad case final pending?) return pending.future;
    return reviews.values.firstOrNull ?? BookReview(bookId: bookId);
  }

  @override
  Future<int?> saveReview(BookReview review) async {
    reviewWrites++;
    if (failSave) throw StateError('Save failed');
    await saveWait?.future;
    if (review.isEmpty) {
      reviews.remove(review.id);
      return null;
    }
    final id = review.id ?? reviews.length + 1;
    reviews[id] = review.copyWith(id: id);
    return id;
  }

  @override
  Future<List<JournalPage>> listPages(int bookId) async {
    if (failLoad) throw StateError('Load failed');
    return pages.values.toList();
  }

  @override
  Future<int> addPage(int bookId) async {
    final id = pages.length + 1;
    pages[id] = JournalPage(id: id, bookId: bookId, pageIndex: id - 1);
    return id;
  }

  @override
  Future<int> addPageFromNote(BookNote note) async {
    if (failAdd) throw StateError('Save failed');
    final id = pages.length + 1;
    pages[id] = JournalPage(
      id: id,
      bookId: note.bookId,
      pageIndex: id - 1,
      body: note.readerNote ?? '',
      sourceCfi: note.cfi,
      sourceExcerpt: note.content,
      sourceChapter: note.chapter,
    );
    return id;
  }

  @override
  Future<int?> savePage(JournalPage page) async {
    if (failSave) throw StateError('Save failed');
    await saveWait?.future;
    pages[page.id!] = page;
    return page.id;
  }

  @override
  Future<int> deletePage(int pageId) async {
    if (failSave) throw StateError('Delete failed');
    return pages.remove(pageId) == null ? 0 : 1;
  }
}

Future<void> _open(WidgetTester tester, Widget page,
    {double textScale = 1}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('en'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => page),
              ),
              child: const Text('Open journal'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open journal'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Finder _genre() => find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == 'Genre');

void main() {
  testWidgets('review saves before leaving and retains drafts after failure',
      (tester) async {
    final dao = _JournalDao()..failSave = true;
    await _open(tester, BookReviewPage(book: _book, dao: dao));
    await tester.ensureVisible(_genre());
    await tester.enterText(_genre(), 'Fantasy');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(BookReviewPage), findsOneWidget);
    expect(find.text('Fantasy'), findsOneWidget);
    expect(find.textContaining('could not be saved'), findsOneWidget);

    dao.failSave = false;
    dao.saveWait = Completer<void>();
    await tester.pageBack();
    await tester.pump();
    expect(find.byType(BookReviewPage), findsOneWidget);
    dao.saveWait!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open journal'), findsOneWidget);
    expect(dao.reviews.values.single.genre, 'Fantasy');
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening pages retains the review id for subsequent saves',
      (tester) async {
    final dao = _JournalDao();
    await _open(tester, BookReviewPage(book: _book, dao: dao));
    await tester.ensureVisible(_genre());
    await tester.enterText(_genre(), 'Fantasy');
    await tester.tap(find.byIcon(Icons.article_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(DotPagesPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(_genre());
    await tester.enterText(_genre(), 'Mystery');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(dao.reviews.length, 1);
    expect(dao.reviews.values.single.genre, 'Mystery');
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving a loading review never writes an empty review',
      (tester) async {
    final dao = _JournalDao()..reviewLoad = Completer<BookReview>();
    await _open(tester, BookReviewPage(book: _book, dao: dao));
    await tester.pageBack();
    await tester.pumpAndSettle();
    dao.reviewLoad!.complete(const BookReview(bookId: 7, genre: 'Existing'));
    await tester.pump();
    expect(dao.reviewWrites, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding a dot page preserves unsaved text and waits for save',
      (tester) async {
    final dao = _JournalDao();
    await _open(tester, DotPagesPage(book: _book, dao: dao));
    await tester.enterText(find.byType(TextField).first, 'Keep this draft.');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Keep this draft.'), findsOneWidget);
    expect(dao.pages.length, 2);

    dao.failSave = true;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(DotPagesPage), findsOneWidget);
    expect(find.text('Keep this draft.'), findsOneWidget);

    dao.failSave = false;
    dao.saveWait = Completer<void>();
    await tester.pageBack();
    await tester.pump();
    expect(find.byType(DotPagesPage), findsOneWidget);
    dao.saveWait!.complete();
    await tester.pumpAndSettle();
    expect(dao.pages[1]!.body, 'Keep this draft.');
    expect(find.text('Open journal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review load errors can be retried', (tester) async {
    final dao = _JournalDao()..failLoad = true;
    await _open(tester, BookReviewPage(book: _book, dao: dao));
    await tester.pumpAndSettle();
    expect(find.text('Your journal could not be loaded.'), findsOneWidget);
    dao.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(_genre());
    expect(_genre(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ratings fit a narrow screen with large text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(260, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _open(tester, BookReviewPage(book: _book, dao: _JournalDao()),
        textScale: 2);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a selected journal page opens in view and earlier pages remain reachable',
      (tester) async {
    final dao = _JournalDao();
    for (var id = 1; id <= 10; id++) {
      dao.pages[id] = JournalPage(
        id: id,
        bookId: 7,
        pageIndex: id - 1,
        body: 'Thoughts on page $id',
      );
    }
    await _open(tester, DotPagesPage(book: _book, dao: dao, initialPageId: 8));
    await tester.pumpAndSettle();
    expect(find.text('Thoughts on page 8').hitTestable(), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 650));
    await tester.pumpAndSettle();
    expect(find.text('Thoughts on page 8').hitTestable(), findsNothing);
    expect(find.byType(TextField).hitTestable(), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding a passage reports failure and keeps the source for retry',
      (tester) async {
    final dao = _JournalDao()..failAdd = true;
    final note = BookNote(
      id: 1,
      bookId: 7,
      content: 'The exact saved passage.',
      cfi: 'epubcfi(/6/2!/4/2:8)',
      chapter: 'Chapter one',
      type: 'highlight',
      color: 'ffff00',
      readerNote: 'My thought.',
      updateTime: DateTime(2026),
    );
    await _open(
        tester,
        Scaffold(
          body: AddToJournalButton(note: note, book: _book, dao: dao),
        ));
    await tester.tap(find.text('Add to journal'));
    await tester.pumpAndSettle();
    expect(find.text('The passage could not be added. Try again.'),
        findsOneWidget);
    expect(find.byType(DotPagesPage), findsNothing);
    expect(note.content, 'The exact saved passage.');
    expect(note.cfi, 'epubcfi(/6/2!/4/2:8)');
    expect(dao.pages.length, 1);

    dao.failAdd = false;
    await tester.tap(find.text('Add to journal'));
    await tester.pumpAndSettle();
    expect(find.byType(DotPagesPage), findsOneWidget);
    expect(find.text(note.content).hitTestable(), findsOneWidget);
    expect(find.text('Open passage'), findsOneWidget);
    expect(find.text('My thought.'), findsOneWidget);
    expect(dao.pages[2]!.sourceCfi, note.cfi);
    expect(tester.takeException(), isNull);
  });

  testWidgets('deleting a sourced page preserves drafts on cancel and failure',
      (tester) async {
    final dao = _JournalDao();
    dao.pages[1] = const JournalPage(
      id: 1,
      bookId: 7,
      pageIndex: 0,
      sourceCfi: 'epubcfi(/6/2!/4/2:8)',
      sourceExcerpt: 'Keep this quote.',
    );
    await _open(tester, DotPagesPage(book: _book, dao: dao));
    await tester.enterText(find.byType(TextField).first, 'Unsaved thoughts.');
    await tester.tap(find.text('Delete page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved thoughts.'), findsOneWidget);
    expect(dao.pages.length, 1);

    dao.failSave = true;
    await tester.tap(find.text('Delete page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved thoughts.'), findsOneWidget);
    expect(find.text('Keep this quote.'), findsOneWidget);
    expect(dao.pages.length, 1);

    dao.failSave = false;
    await tester.tap(find.text('Delete page'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(dao.pages, isEmpty);
    expect(find.text('No pages yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
