import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/dao/search_repository.dart';
import 'package:paperfold/models/search_journal_result.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late SearchRepository repository;
  const day = '2026-10-03T12:00:00.000Z';

  Future<void> addBook(
    int id, {
    String title = 'A book',
    String author = 'An author',
    bool deleted = false,
    String updated = day,
  }) async {
    await db.insert('tb_books', {
      'id': id,
      'title': title,
      'author': author,
      'is_deleted': deleted ? 1 : 0,
      'create_time': day,
      'update_time': updated,
    });
  }

  Future<void> addWriting(int bookId, String text,
      {String updated = day}) async {
    await db.insert('tb_notes', {
      'book_id': bookId,
      'content': text,
      'type': 'highlight',
      'update_time': updated,
    });
    await db.insert('tb_reviews', {
      'book_id': bookId,
      'thoughts': text,
      'update_time': updated,
    });
    await db.insert('tb_journal', {
      'book_id': bookId,
      'page_index': 0,
      'body': text,
      'update_time': updated,
    });
  }

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(createBookSQL);
    await db.execute(createNoteSQL);
    await db.execute('ALTER TABLE tb_notes ADD COLUMN reader_note TEXT');
    await db.execute(createReviewSQL);
    await db.execute(createJournalSQL);
    repository = SearchRepository(database: db);
  });

  tearDown(() async => db.close());

  test('blank queries and nonpositive limits do not open the database',
      () async {
    const unopened = SearchRepository();
    expect((await unopened.search('   ')).journalResults, isEmpty);
    expect((await unopened.search('word', limit: 0)).books, isEmpty);
    expect((await unopened.search('word', limit: -1)).noteGroups, isEmpty);
  });

  test('finds each review field when no book or highlight matches', () async {
    await addBook(1);
    final id = await db.insert('tb_reviews', {
      'book_id': 1,
      'thoughts': 'Winter reading',
      'favorite_quote': 'Light is the left hand of darkness.',
      'favorite_character': 'Estraven',
      'genre': 'Science fiction',
      'format': 'Paperback',
      'update_time': day,
    });

    for (final query in [
      ' winter ',
      'DARKNESS',
      'Estraven',
      'fiction',
      'Paperback'
    ]) {
      final result = await repository.search(query);
      expect(result.books, isEmpty);
      expect(result.noteGroups, isEmpty);
      expect(result.journalResults.single.id, id);
      expect(result.journalResults.single.book.id, 1);
      expect(result.journalResults.single.kind, SearchJournalKind.review);
    }
  });

  test('finds page text and source-only passages with their exact page ids',
      () async {
    await addBook(1);
    final pageId = await db.insert('tb_journal', {
      'book_id': 1,
      'page_index': 4,
      'body': 'A careful reflection',
      'update_time': day,
    });
    final sourceId = await db.insert('tb_journal', {
      'book_id': 1,
      'page_index': 8,
      'body': '',
      'source_cfi': 'epubcfi(/6/8)',
      'source_excerpt': 'The moon was bright.',
      'source_chapter': 'Arrival',
      'update_time': day,
    });

    final page = (await repository.search('reflection')).journalResults.single;
    expect(page.id, pageId);
    expect(page.kind, SearchJournalKind.page);
    expect(page.pageIndex, 4);
    for (final query in ['moon', 'Arrival']) {
      final source = (await repository.search(query)).journalResults.single;
      expect(source.id, sourceId);
      expect(source.pageIndex, 8);
      expect(source.text, contains('The moon was bright.'));
    }
  });

  test('book and inclusive date filters apply to every result category',
      () async {
    const before = '2026-10-01T12:00:00.000Z';
    const after = '2026-10-05T12:00:00.000Z';
    for (var id = 1; id <= 3; id++) {
      final date = [before, day, after][id - 1];
      await addBook(id, title: 'Needle $id', updated: date);
      await addWriting(id, 'needle $id', updated: date);
    }

    final date = DateTime.parse(day);
    final byDate = await repository.search('needle', from: date, to: date);
    expect(byDate.books.map((book) => book.id), [2]);
    expect(byDate.noteGroups.map((group) => group.book.id), [2]);
    expect(byDate.journalResults.map((entry) => entry.book.id), [2, 2]);

    final byBook = await repository.search('needle', bookId: 1);
    expect(byBook.books.map((book) => book.id), [1]);
    expect(byBook.noteGroups.map((group) => group.book.id), [1]);
    expect(byBook.journalResults.map((entry) => entry.book.id), [1, 1]);
    final excluded = await repository.search('needle', bookId: 1, from: date);
    expect(excluded.books, isEmpty);
    expect(excluded.noteGroups, isEmpty);
    expect(excluded.journalResults, isEmpty);
  });

  test('filters writing by its own edit date, not the book date', () async {
    await addBook(1, title: 'Needle', updated: '2026-01-01T00:00:00.000Z');
    await addWriting(1, 'needle');

    final result =
        await repository.search('needle', from: DateTime.utc(2026, 10));
    expect(result.books, isEmpty);
    expect(result.noteGroups.single.notes, hasLength(1));
    expect(result.journalResults, hasLength(2));
  });

  test('deleted and missing books are excluded before limits are applied',
      () async {
    await addBook(1, title: 'Needle');
    await addBook(2,
        title: 'Needle', deleted: true, updated: '2026-10-06T00:00:00.000Z');
    await addWriting(1, 'needle');
    await addWriting(2, 'needle', updated: '2026-10-06T00:00:00.000Z');
    await addWriting(99, 'needle', updated: '2026-10-07T00:00:00.000Z');

    final result = await repository.search('needle', limit: 1);
    expect(result.books.single.id, 1);
    expect(result.noteGroups.single.book.id, 1);
    expect(result.noteGroups.single.notes, hasLength(1));
    expect(result.journalResults.single.book.id, 1);
  });

  test('percent, underscore, slash and SQL-looking text are literal', () async {
    const literal = "100%_complete\\ ' OR 1=1 --";
    await addBook(1, title: literal);
    await addWriting(1, literal);
    await addBook(2, title: 'Every other word');
    await addWriting(2, 'Every other word');

    for (final query in ['%', '_', r'\', "' OR 1=1 --"]) {
      final result = await repository.search(query);
      expect(result.books.map((book) => book.id), [1], reason: query);
      expect(result.noteGroups.map((group) => group.book.id), [1],
          reason: query);
      expect(result.journalResults.map((entry) => entry.book.id), [1, 1],
          reason: query);
    }
  });

  test('author, reader note and chapter matches remain available', () async {
    await addBook(1, author: 'Le Guin');
    await db.insert('tb_notes', {
      'book_id': 1,
      'type': 'highlight',
      'content': 'An excerpt',
      'reader_note': 'A memory',
      'chapter': 'Arrival',
      'update_time': day,
    });
    await db.insert('tb_notes', {
      'book_id': 1,
      'type': 'review',
      'content': 'A memory',
      'update_time': day,
    });
    expect((await repository.search('Le Guin')).books.single.id, 1);
    expect((await repository.search('memory')).noteGroups.single.notes,
        hasLength(1));
    expect((await repository.search('arrival')).noteGroups.single.notes,
        hasLength(1));
  });
}
