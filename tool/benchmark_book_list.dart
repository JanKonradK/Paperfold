// Run with: flutter test tool/benchmark_book_list.dart --reporter expanded
// Informational local timings, not a device frame-rate or startup benchmark.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/sort_field.dart';
import 'package:paperfold/enums/sort_order.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // This benchmark runs only under flutter test.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });

  test('compare the current library CPU work with its previous algorithms', () {
    final controller = BookList();
    final books = List.generate(2000, (index) {
      const titles = ['纸鹤', '星辰', 'The Moon', 'Été', '📚', 'שלום', ''];
      return Book.mock().copyWith(
        id: index,
        title: '${titles[index % titles.length]} ${index % 700}',
        author: '作家 ${index % 40}',
        groupId: index % 7 == 0 ? 0 : index % 500 + 1,
        createTime: DateTime.utc(2026, 1, index % 28 + 1),
        updateTime: DateTime.utc(2026, 2, index % 28 + 1),
        readingPercentage: (index % 100) / 100,
      );
    })
      ..shuffle(Random(175));

    // Ties, both directions, and non-text fields must retain identical order.
    for (final field in SortFieldEnum.values) {
      for (final order in SortOrderEnum.values) {
        Prefs().sortField = field;
        Prefs().sortOrder = order;
        expect(
          controller.sortBooks(books.toList()).map((book) => book.id),
          _previousSort(books.toList()).map((book) => book.id),
          reason: '${field.name}, ${order.name}',
        );
      }
    }
    expect(
      controller.groupBooks(books).map((group) => group.map((book) => book.id)),
      _previousGroups(books).map((group) => group.map((book) => book.id)),
    );

    for (final field in [SortFieldEnum.title, SortFieldEnum.author]) {
      Prefs().sortField = field;
      Prefs().sortOrder = SortOrderEnum.ascending;
      _report('sort ${field.name}', books, _previousSort, controller.sortBooks);
    }
    _report('group', books, _previousGroups, controller.groupBooks);
  });
}

void _report(
  String name,
  List<Book> source,
  Object Function(List<Book>) previous,
  Object Function(List<Book>) current,
) {
  int time(Object Function(List<Book>) run) {
    final input = source.toList();
    final watch = Stopwatch()..start();
    run(input);
    return (watch..stop()).elapsedMicroseconds;
  }

  for (var warmup = 0; warmup < 2; warmup++) {
    time(previous);
    time(current);
  }
  final before = <int>[];
  final after = <int>[];
  for (var sample = 0; sample < 9; sample++) {
    if (sample.isEven) {
      before.add(time(previous));
      after.add(time(current));
    } else {
      after.add(time(current));
      before.add(time(previous));
    }
  }
  before.sort();
  after.sort();
  // ignore: avoid_print
  print('$name, ${source.length} books, 9 samples: '
      'previous median ${before[4]} us; current median ${after[4]} us');
}

// Baselines copied from BookList before the bounded performance change.
List<Book> _previousSort(List<Book> books) {
  String textKey(String value) {
    try {
      return PinyinHelper.getPinyin(value, format: PinyinFormat.WITHOUT_TONE);
    } catch (_) {
      return value;
    }
  }

  books.sort((a, b) {
    final compared = switch (Prefs().sortField) {
      SortFieldEnum.title => textKey(a.title).compareTo(textKey(b.title)),
      SortFieldEnum.author => textKey(a.author).compareTo(textKey(b.author)),
      SortFieldEnum.lastReadTime => a.updateTime.compareTo(b.updateTime),
      SortFieldEnum.progress =>
        a.readingPercentage.compareTo(b.readingPercentage),
      SortFieldEnum.importTime => a.createTime.compareTo(b.createTime),
    };
    return Prefs().sortOrder == SortOrderEnum.ascending ? compared : -compared;
  });
  return books;
}

List<List<Book>> _previousGroups(List<Book> books) {
  final groups = <List<Book>>[];
  for (final book in books) {
    if (book.groupId == 0) {
      groups.add([book]);
    } else {
      final group = groups.firstWhere(
        (group) => group.first.groupId == book.groupId,
        orElse: () => [],
      );
      if (group.isEmpty) {
        groups.add([book]);
      } else {
        group.add(book);
      }
    }
  }
  return groups;
}
