import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/book_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openEditor(WidgetTester tester, Book book) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [
          L10n.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: L10n.supportedLocales,
        theme: ThemeData(
          colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => BookEditPage(book: book),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  // Localizations load deferred.
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
  });

  testWidgets('leaving with unsaved edits asks before discarding them', (
    tester,
  ) async {
    final book = Book.mock();
    await _openEditor(tester, book);

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'A better title',
    );
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('A better title'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(BookEditPage), findsNothing);
    expect(book.title, 'Mock Book');
  });

  testWidgets('an empty title is refused and nothing is written', (
    tester,
  ) async {
    final book = Book.mock();
    await _openEditor(tester, book);

    await tester.enterText(find.widgetWithText(TextField, 'Title'), '  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Input cannot be empty'), findsOneWidget);
    expect(book.title, 'Mock Book');
  });

  testWidgets('a new paper book asks for pages and refuses a bad count', (
    tester,
  ) async {
    final book = Book.physical();
    await _openEditor(tester, book);

    expect(find.text('Add a paper book'), findsOneWidget);
    final pages = find.byKey(const ValueKey('book-edit-total-pages'));
    expect(pages, findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Dune');
    await tester.enterText(pages, '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a page number in the book.'), findsOneWidget);
    expect(book.id, -1);
    expect(book.totalPages, isNull);
  });

  testWidgets('an e-book has no page count field', (tester) async {
    await _openEditor(tester, Book.mock()..filePath = 'file/book.epub');
    expect(find.byKey(const ValueKey('book-edit-total-pages')), findsNothing);
  });
}
