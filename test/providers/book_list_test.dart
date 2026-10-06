import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/enums/sort_field.dart';
import 'package:paperfold/enums/sort_order.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });

  test('grouping keeps first-seen groups, book order and separate standalones',
      () {
    final books = [
      Book.mock().copyWith(id: 1, groupId: 8),
      Book.mock().copyWith(id: 2),
      Book.mock().copyWith(id: 3, groupId: -2),
      Book.mock().copyWith(id: 4, groupId: 8),
      Book.mock().copyWith(id: 5),
      Book.mock().copyWith(id: 6, groupId: -2),
    ];
    final grouped = BookList().groupBooks(books);

    expect(grouped.map((group) => group.map((book) => book.id)), [
      [1, 4],
      [2],
      [3, 6],
      [5],
    ]);
    expect(grouped.first.first, same(books.first));
    expect(books.map((book) => book.id), [1, 2, 3, 4, 5, 6]);
    expect(BookList().groupBooks([]), isEmpty);
  });

  test('grouping work stays linear as the library grows', () {
    for (final size in [500, 2000]) {
      final books = List.generate(size, _CountedGroupBook.new);
      final groups = BookList().groupBooks(books);

      expect(groups, hasLength(size));
      expect(books.fold(0, (sum, book) => sum + book.groupIdReads),
          lessThanOrEqualTo(size * 3));
    }
  });

  test('all sort fields retain their order in both directions', () {
    final books = [
      Book.mock().copyWith(
        id: 1,
        title: '世界',
        author: '张伟',
        updateTime: DateTime.utc(2026, 1, 4),
        createTime: DateTime.utc(2026, 1, 3),
        readingPercentage: .25,
      ),
      Book.mock().copyWith(
        id: 2,
        title: 'Alpha',
        author: '王伟',
        updateTime: DateTime.utc(2026, 1, 2),
        createTime: DateTime.utc(2026, 1, 4),
        readingPercentage: 1,
      ),
      Book.mock().copyWith(
        id: 3,
        title: '你好',
        author: 'Alice',
        updateTime: DateTime.utc(2026, 1, 1),
        createTime: DateTime.utc(2026, 1, 2),
        readingPercentage: 0,
      ),
      Book.mock().copyWith(
        id: 4,
        title: 'Zebra',
        author: '李伟',
        updateTime: DateTime.utc(2026, 1, 3),
        createTime: DateTime.utc(2026, 1, 1),
        readingPercentage: .5,
      ),
    ];
    const expected = {
      SortFieldEnum.title: [2, 4, 3, 1],
      SortFieldEnum.author: [3, 4, 2, 1],
      SortFieldEnum.lastReadTime: [3, 2, 4, 1],
      SortFieldEnum.progress: [3, 1, 4, 2],
      SortFieldEnum.importTime: [4, 3, 1, 2],
    };
    final controller = BookList();
    for (final field in SortFieldEnum.values) {
      for (final order in SortOrderEnum.values) {
        Prefs().sortField = field;
        Prefs().sortOrder = order;
        final input = books.toList();
        final sorted = controller.sortBooks(input);
        expect(sorted, same(input));
        expect(
          sorted.map((book) => book.id),
          order == SortOrderEnum.ascending
              ? expected[field]
              : expected[field]!.reversed,
          reason: '${field.name}, ${order.name}',
        );
      }
    }
  });

  test('text keys are refreshed after edits and a change of sort field', () {
    final controller = BookList();
    final first = Book.mock().copyWith(id: 1, title: 'Zebra', author: 'Amy');
    final second = Book.mock().copyWith(id: 2, title: 'Apple', author: 'Zoe');
    final books = [first, second];
    Prefs().sortField = SortFieldEnum.title;
    Prefs().sortOrder = SortOrderEnum.ascending;
    expect(controller.sortBooks(books).map((book) => book.id), [2, 1]);

    first.title = 'Aardvark';
    expect(controller.sortBooks(books).map((book) => book.id), [1, 2]);
    Prefs().sortField = SortFieldEnum.author;
    second.author = 'Aaron';
    expect(controller.sortBooks(books).map((book) => book.id), [2, 1]);
    Prefs().sortOrder = SortOrderEnum.descending;
    expect(controller.sortBooks(books).map((book) => book.id), [1, 2]);
    expect(controller.sortBooks([]), isEmpty);
  });
}

class _CountedGroupBook extends Book {
  _CountedGroupBook(int index)
      : super(
          id: index,
          title: '',
          author: '',
          coverPath: '',
          filePath: '',
          lastReadPosition: '',
          readingPercentage: 0,
          isDeleted: false,
          rating: 0,
          groupId: index + 1,
          status: BookStatus.notStarted,
          createTime: DateTime.utc(2026),
          updateTime: DateTime.utc(2026),
        );

  int groupIdReads = 0;

  @override
  int get groupId {
    groupIdReads++;
    return super.groupId;
  }
}
