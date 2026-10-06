import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/search_repository.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/search_journal_result.dart';
import 'package:paperfold/models/search_result_data.dart';
import 'package:paperfold/page/search/search_journal_tile.dart';
import 'package:paperfold/page/search/search_page.dart';
import 'package:paperfold/providers/search.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SearchRepository extends SearchRepository {
  final queries = <String>[];
  bool fail = false;
  SearchResultData result = SearchResultData.empty;

  @override
  Future<SearchResultData> search(
    String keyword, {
    int? bookId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    queries.add(keyword);
    if (fail) throw StateError('Search unavailable');
    return result;
  }
}

void main() {
  Future<void> pumpSearch(
    WidgetTester tester,
    _SearchRepository repository,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    await tester.pumpWidget(ProviderScope(
      overrides: [searchRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: Locale('en'),
        home: SearchPage(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('clear cancels a pending search and keeps input ready',
      (tester) async {
    final repository = _SearchRepository();
    await pumpSearch(tester, repository);
    await tester.enterText(find.byType(TextField), 'moon');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Clear text'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(repository.queries, isEmpty);
    expect(find.text('Start typing to search'), findsOneWidget);
  });

  testWidgets('a failed search can retry without losing the query',
      (tester) async {
    final repository = _SearchRepository()..fail = true;
    await pumpSearch(tester, repository);
    await tester.enterText(find.byType(TextField), 'moon');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('This could not be loaded.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repository.queries, ['moon', 'moon']);
    expect(find.text('This could not be loaded.'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'moon');
    expect(tester.takeException(), isNull);
  });

  testWidgets('journal-only matches show their book, kind and literal excerpt',
      (tester) async {
    final book = Book.mock().copyWith(title: 'The left hand of darkness');
    final repository = _SearchRepository()
      ..result = SearchResultData(
        books: [],
        noteGroups: [],
        journalResults: [
          SearchJournalResult(
            book: book,
            id: 12,
            kind: SearchJournalKind.review,
            text:
                '${List.filled(80, 'Earlier words').join(' ')} literal [a+b] kept.',
          ),
          SearchJournalResult(
            book: book,
            id: 93,
            kind: SearchJournalKind.page,
            pageIndex: 4,
            text: 'A second [a+b] thought.',
          ),
        ],
      );
    await pumpSearch(tester, repository);
    await tester.enterText(find.byType(TextField), '[a+b]');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Dot page 5'), findsOneWidget);
    expect(find.byType(SearchJournalTile), findsNWidgets(2));
    expect(find.text('The left hand of darkness'), findsNWidgets(2));
    final highlights = tester
        .widgetList<Text>(find.byType(Text))
        .where((text) => text.textSpan is TextSpan)
        .expand(
            (text) => (text.textSpan! as TextSpan).children ?? <InlineSpan>[])
        .whereType<TextSpan>()
        .where((span) => span.style?.fontWeight == FontWeight.w700);
    expect(highlights.map((span) => span.text), ['[a+b]', '[a+b]']);
    expect(find.text('Nothing here'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('journal results fit narrow screens with larger text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = _SearchRepository()
      ..result = SearchResultData(
        books: [],
        noteGroups: [],
        journalResults: [
          SearchJournalResult(
            book: Book.mock().copyWith(
              title:
                  'A very long book title with a long subtitle for a small screen',
            ),
            id: 1,
            kind: SearchJournalKind.page,
            pageIndex: 99,
            text:
                'A memory worth keeping. ${List.filled(20, 'More writing.').join(' ')}',
          ),
        ],
      );
    await pumpSearch(tester, repository);
    await tester.enterText(find.byType(TextField), 'memory');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Dot page 100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
