import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shelf_home_fixtures.dart';

Future<void> _pumpShelfHome(
  WidgetTester tester, {
  required ShelfHomeData data,
}) async {
  fakeData = data;
  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: newTestOverrides(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: L10n.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
        ),
        home: const ShelfHomePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Bookcase _bookcase(WidgetTester tester) =>
    tester.widget<Bookcase>(find.byType(Bookcase));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  testWidgets('Library shows one Bookcase with five shelves in order',
      (tester) async {
    await _pumpShelfHome(tester, data: populatedData());

    expect(find.byType(Bookcase), findsOneWidget);
    expect(
      _bookcase(tester).shelves.map((shelf) => shelf.name),
      [
        'Reading now',
        'All time favourites',
        'To be read',
        'Finished',
        'Books to buy',
      ],
    );
  });

  test('Book maps fractional progress and finished state', () {
    final source = book(12, 'Progress book', BookStatus.finished)
      ..readingPercentage = 0.42;

    final mapped = shelfBookFromBook(source);

    expect(mapped.id, 'book-12');
    expect(mapped.progress, 0.42);
    expect(mapped.finished, isTrue);
  });
}
