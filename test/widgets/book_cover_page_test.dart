import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/shelf.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/book_cover_page.dart';
import 'package:paperfold/widgets/bookshelf/book_status_control.dart';
import 'package:shared_preferences/shared_preferences.dart';

Book _book({
  BookStatus status = BookStatus.notStarted,
  double percentage = 0,
}) {
  return Book(
    id: 1,
    title: 'The Left Hand of Darkness',
    coverPath: '',
    filePath: 'left-hand.epub',
    lastReadPosition: '',
    readingPercentage: percentage,
    author: 'Ursula Le Guin',
    isDeleted: false,
    rating: 0,
    status: status,
    createTime: DateTime.utc(2026),
    updateTime: DateTime.utc(2026),
  );
}

/// Fakes rather than an in-memory database.
///
/// A widget test runs in a fake async zone, and sqflite's real I/O never
/// completes inside it. That does not fail - the DAO's future simply never
/// resolves and the test hangs until the suite's own timeout, which reads as
/// the harness being broken rather than the test being wrong. Everything here
/// is about what the screen shows and writes, so nothing needs a database.
class _FakeShelfDao extends ShelfDao {
  _FakeShelfDao({this.favourite = false});

  bool favourite;

  @override
  Future<bool> containsBook({required int shelfId, required int bookId}) async =>
      favourite;

  @override
  Future<void> addBookToShelf({
    required int shelfId,
    required int bookId,
    int? sortOrder,
  }) async =>
      favourite = true;

  @override
  Future<void> removeBookFromShelf({
    required int shelfId,
    required int bookId,
  }) async =>
      favourite = false;
}

class _FakeBookDao extends BookDao {
  final List<Book> written = [];

  @override
  Future<void> updateBook(Book book) async => written.add(book);

  @override
  Future<Book> selectBookById(int id) async => _book();
}

Widget _host(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
      ),
      home: child,
    ),
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  testWidgets('the cover screen offers every way of handling a book',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(BookCoverPage(
      book: _book(),
      bookDao: _FakeBookDao(),
      shelfDao: _FakeShelfDao(),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The title, and the one filled control that opens the book.
    expect(find.text('The Left Hand of Darkness'), findsWidgets);
    // Twice: once under the title, once on the generated cover.
    expect(find.text('Ursula Le Guin'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Open'), findsOneWidget);

    // Everything a reader does with a book that is not reading it.
    for (final label in <String>[
      'Favourite',
      'Notes',
      'Journal',
      'Review',
      'Share',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label is missing');
    }

    // And the status control, which is the only way the reader can set a value
    // three of the five shelves sort on.
    expect(find.byType(BookStatusControl), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);
  });

  testWidgets('a book that has never been opened says so rather than 0%',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(BookCoverPage(
      book: _book(),
      bookDao: _FakeBookDao(),
      shelfDao: _FakeShelfDao(),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Not started'), findsOneWidget);

    await tester.pumpWidget(_host(BookCoverPage(
      key: const ValueKey('read'),
      book: _book(percentage: 0.42),
      bookDao: _FakeBookDao(),
      shelfDao: _FakeShelfDao(),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('42% read'), findsOneWidget);
  });

  testWidgets('editing reveals the fields and hides them again',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(BookCoverPage(
      book: _book(),
      bookDao: _FakeBookDao(),
      shelfDao: _FakeShelfDao(),
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump();

    // Title and author, both editable.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  // Marking a book has to write the dates the trackers count, not just the
  // status: a book can reach "finished" by being marked as much as by being
  // read to the end, and the reading challenge counts by `finished_on`.
  testWidgets('marking a book carries its dates with it', (tester) async {
    final book = _book();
    final dao = _FakeBookDao();

    await tester.pumpWidget(_host(
      Scaffold(body: BookStatusControl(book: book, dao: dao)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(book.startedOn, isNull);
    expect(book.finishedOn, isNull);

    await tester.tap(find.text('Reading'));
    await tester.pump();
    expect(book.status, BookStatus.reading);
    expect(book.startedOn, isNotNull, reason: 'reading did not stamp a start');
    expect(book.finishedOn, isNull);

    final started = book.startedOn;
    await tester.tap(find.text('Finished'));
    await tester.pump();
    expect(book.status, BookStatus.finished);
    expect(book.startedOn, started, reason: 'the original start was lost');
    expect(book.finishedOn, isNotNull);

    // Going back to unread clears both, or the book would sit in a past year
    // of the reading challenge for ever.
    await tester.tap(find.text('To be read'));
    await tester.pump();
    expect(book.status, BookStatus.notStarted);
    expect(book.startedOn, isNull);
    expect(book.finishedOn, isNull);

    // Each mark is written, not just held in the widget.
    expect(dao.written.length, 3);
  });
}
