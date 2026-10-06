import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/search_repository.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/search_result_data.dart';
import 'package:paperfold/page/search/search_page.dart';
import 'package:paperfold/providers/search.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SearchRepository extends SearchRepository {
  final queries = <String>[];
  bool fail = false;

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
    return SearchResultData.empty;
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
}
