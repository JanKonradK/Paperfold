// Proves the journal data layer: the review sheet and the dot pages.
//
// tb_reviews and tb_journal were created by migration version 8 but had no
// model and no DAO, so nothing could read or write them. These tests run
// against the real schema constants, not a hand-written fixture, so a change
// to the migration that breaks the DAO fails here.
//
//   flutter test test/dao/journal_dao_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/models/book_review.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late JournalDao dao;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(createReviewSQL);
    await db.execute(createJournalSQL);
    dao = JournalDao(database: db);
  });

  tearDown(() async => db.close());

  test('a book with no review opens on a blank sheet', () async {
    expect(await dao.findReview(7), isNull);

    final blank = await dao.reviewOrEmpty(7);
    expect(blank.bookId, 7);
    expect(blank.id, isNull);
    expect(blank.isEmpty, isTrue);
  });

  test('an empty sheet is never written', () async {
    final id = await dao.saveReview(const BookReview(bookId: 7));
    expect(id, isNull, reason: 'opening a review must not create a row');
    expect(await dao.findReview(7), isNull);
  });

  test('a review round-trips every field', () async {
    const written = BookReview(
      bookId: 7,
      genre: 'Science fiction',
      format: 'Paperback',
      ratingOverall: 5,
      ratingPlot: 4,
      ratingEnding: 3,
      ratingWorld: 5,
      ratingCharacters: 4,
      ratingSpice: 1,
      favoriteCharacter: 'Estraven',
      favoriteQuote: 'Light is the left hand of darkness.',
      thoughts: 'Read it twice in a winter.',
    );

    final id = await dao.saveReview(written);
    expect(id, isNotNull);

    final read = await dao.findReview(7);
    expect(read, isNotNull);
    expect(read!.genre, 'Science fiction');
    expect(read.format, 'Paperback');
    expect(read.ratingOverall, 5);
    expect(read.ratingPlot, 4);
    expect(read.ratingEnding, 3);
    expect(read.ratingWorld, 5);
    expect(read.ratingCharacters, 4);
    expect(read.ratingSpice, 1);
    expect(read.favoriteCharacter, 'Estraven');
    expect(read.favoriteQuote, 'Light is the left hand of darkness.');
    expect(read.thoughts, 'Read it twice in a winter.');
  });

  test('saving twice updates rather than duplicating', () async {
    final id = await dao.saveReview(
      const BookReview(bookId: 7, ratingOverall: 3),
    );
    final stored = await dao.findReview(7);

    await dao.saveReview(stored!.copyWith(ratingOverall: 5));

    final rows = await db.query(JournalDao.reviewTable);
    expect(rows.length, 1, reason: 'one book keeps one review sheet');
    expect((await dao.findReview(7))!.ratingOverall, 5);
    expect((await dao.findReview(7))!.id, id);
  });

  test('clearing every field removes the sheet', () async {
    await dao.saveReview(const BookReview(bookId: 7, thoughts: 'A first go.'));
    final stored = await dao.findReview(7);

    final removed = await dao.saveReview(stored!.copyWith(thoughts: ''));

    expect(removed, isNull);
    expect(await dao.findReview(7), isNull);
  });

  test('a rating outside 0 to 5 is clamped, not thrown', () async {
    await db.insert(JournalDao.reviewTable, {
      'book_id': 7,
      'rating_overall': 9,
      'rating_plot': -2,
    });

    final read = await dao.findReview(7);
    expect(read!.ratingOverall, 5);
    expect(read.ratingPlot, 0);
  });

  test('pages keep their order as they are added', () async {
    await dao.addPage(7);
    await dao.addPage(7);
    await dao.addPage(7);

    final pages = await dao.listPages(7);
    expect(pages.map((p) => p.pageIndex), [0, 1, 2]);
  });

  test('a page emptied of text is removed', () async {
    await dao.addPage(7);
    var page = (await dao.listPages(7)).single;
    await dao.savePage(page.copyWith(body: 'Something worth keeping.'));

    page = (await dao.listPages(7)).single;
    expect(page.body, 'Something worth keeping.');

    final removed = await dao.savePage(page.copyWith(body: '   '));
    expect(removed, isNull);
    expect(await dao.listPages(7), isEmpty);
  });

  test('a page belongs to one book only', () async {
    await dao.addPage(7);
    await dao.addPage(8);

    expect((await dao.listPages(7)).length, 1);
    expect((await dao.listPages(8)).length, 1);
  });

  test('the journal lists only books with real writing', () async {
    // A blank page is not writing. A review is.
    await dao.addPage(7);
    await dao.saveReview(const BookReview(bookId: 8, ratingOverall: 4));
    await dao.addPage(9);
    final ninth = (await dao.listPages(9)).single;
    await dao.savePage(ninth.copyWith(body: 'A thought.'));

    final ids = await dao.listBookIdsWithWriting();
    expect(ids, contains(8));
    expect(ids, contains(9));
    expect(ids, isNot(contains(7)),
        reason: 'an empty page must not put a book in the journal');
  });

  test('deleting a book takes its journal with it', () async {
    await dao.saveReview(const BookReview(bookId: 7, thoughts: 'Kept.'));
    await dao.addPage(7);
    final page = (await dao.listPages(7)).single;
    await dao.savePage(page.copyWith(body: 'Also kept.'));

    await dao.deleteForBook(7);

    expect(await dao.findReview(7), isNull);
    expect(await dao.listPages(7), isEmpty);
  });

  test('a page with an unparseable date still returns its text', () async {
    await db.insert(JournalDao.pageTable, {
      'book_id': 7,
      'page_index': 0,
      'body': 'Written by an older build.',
      'update_time': 'not a date',
    });

    final page = (await dao.listPages(7)).single;
    expect(page.body, 'Written by an older build.');
    expect(page.updateTime, isNull);
  });

  test('JournalPage.toDb omits the generated id', () async {
    const page = JournalPage(bookId: 7, pageIndex: 0, body: 'x');
    expect(page.toDb().containsKey('id'), isFalse);
  });
}
