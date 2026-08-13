// Proves the two tracker tables migration version 8 created but nothing read:
// tb_challenge and tb_daily_read.
//
// The tests run against the real schema constants, not a hand-written fixture,
// so a change to the migration that breaks a DAO fails here.
//
//   flutter test test/dao/tracker_dao_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/dao/challenge.dart';
import 'package:paperfold/dao/daily_read.dart';
import 'package:paperfold/dao/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute(createChallengeSQL);
    await db.execute(createDailyReadSQL);
  });

  tearDown(() async => db.close());

  group('the reading challenge', () {
    late ChallengeDao dao;

    setUp(() => dao = ChallengeDao(database: db));

    test('a year that was never set reads as the default target', () async {
      expect(await dao.targetForYear(2026), ChallengeDao.defaultTarget);
    });

    test('a target round-trips', () async {
      await dao.setTarget(2026, 42);
      expect(await dao.targetForYear(2026), 42);
    });

    test('setting the same year twice updates rather than duplicates',
        () async {
      await dao.setTarget(2026, 42);
      await dao.setTarget(2026, 60);

      expect(await dao.targetForYear(2026), 60);
      final List<Map<String, Object?>> rows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM ${ChallengeDao.table} WHERE year = 2026',
      );
      expect(
        rows.first['count'],
        1,
        reason: 'year is UNIQUE, so a second row would fail',
      );
    });

    test('years do not touch each other', () async {
      await dao.setTarget(2025, 12);
      await dao.setTarget(2026, 52);

      expect(await dao.targetForYear(2025), 12);
      expect(await dao.targetForYear(2026), 52);
    });

    test('an impossible target is clamped, not rejected', () async {
      expect(await dao.setTarget(2026, 0), ChallengeDao.minimumTarget);
      expect(await dao.setTarget(2026, 5000), ChallengeDao.maximumTarget);
      expect(await dao.targetForYear(2026), ChallengeDao.maximumTarget);
    });
  });

  group('pages read each day', () {
    late DailyReadDao dao;

    setUp(() => dao = DailyReadDao(database: db));

    test('a day that was never read is absent, not zero', () async {
      expect(await dao.pagesOn(DateTime(2026, 8, 13)), isNull);
      expect(await dao.pagesByDay(2026, 8), isEmpty);
    });

    test('a day accumulates across sittings', () async {
      final DateTime day = DateTime(2026, 8, 13);
      await dao.addPages(day, 20);
      await dao.addPages(day, 15);

      expect(await dao.pagesOn(day), 35);
    });

    test('setting a day replaces it', () async {
      final DateTime day = DateTime(2026, 8, 13);
      await dao.addPages(day, 20);
      await dao.setPages(day, 5);

      expect(await dao.pagesOn(day), 5);
    });

    test('pages below zero are stored as zero', () async {
      expect(await dao.setPages(DateTime(2026, 8, 13), -4), 0);
    });

    test('a month reads back keyed by day of the month', () async {
      await dao.setPages(DateTime(2026, 8, 1), 10);
      await dao.setPages(DateTime(2026, 8, 13), 30);
      await dao.setPages(DateTime(2026, 8, 31), 7);
      // A neighbouring month must not leak into the ring.
      await dao.setPages(DateTime(2026, 9, 1), 99);

      expect(await dao.pagesByDay(2026, 8), {1: 10, 13: 30, 31: 7});
    });

    test('a single-digit day keeps its padded key', () async {
      await dao.setPages(DateTime(2026, 8, 3), 12);
      expect(DailyReadDao.dateKey(DateTime(2026, 8, 3)), '2026-08-03');
      expect(await dao.pagesByDay(2026, 8), {3: 12});
    });
  });
}
