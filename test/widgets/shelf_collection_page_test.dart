import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Book _book({
  required int id,
  required String title,
  required String author,
  double rating = 0,
  BookStatus status = BookStatus.notStarted,
}) {
  return Book(
    id: id,
    title: title,
    coverPath: '',
    filePath: 'book-$id.epub',
    lastReadPosition: '',
    readingPercentage: 0,
    author: author,
    isDeleted: false,
    rating: rating,
    status: status,
    createTime: DateTime.utc(2026),
    updateTime: DateTime.utc(2026),
  );
}

Future<void> _pump(WidgetTester tester, List<Book> books) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: L10n.supportedLocales,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
        ),
        home: ShelfCollectionPage(title: 'Reading now', books: books),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // The cover tile reads Prefs during layout, so the store must exist before
  // any pump.
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  final books = [
    _book(
      id: 1,
      title: 'The Left Hand of Darkness',
      author: 'Ursula Le Guin',
      rating: 4.5,
      status: BookStatus.reading,
    ),
    _book(
      id: 2,
      title: 'Piranesi',
      author: 'Susanna Clarke',
      status: BookStatus.finished,
    ),
  ];

  testWidgets('the log is the same books, read as a table', (tester) async {
    await _pump(tester, books);

    // Covers first. The log is a view of the same data, not another screen.
    // The cover tile paints the title twice, over the art and beneath it.
    expect(find.text('The Left Hand of Darkness'), findsWidgets);
    expect(find.byIcon(Icons.view_list_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();

    expect(find.text('The Left Hand of Darkness'), findsOneWidget);
    expect(find.text('Piranesi'), findsOneWidget);
    // Author and rating are the two columns on by default.
    expect(find.textContaining('Ursula Le Guin'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    // The toggle now offers the way back.
    expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);
  });

  testWidgets('columns turn on and off', (tester) async {
    await _pump(tester, books);
    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();

    // Status is off by default, so no shelf label shows in the rows.
    expect(find.textContaining('Reading now · '), findsNothing);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Status').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Reading now'), findsWidgets);

    // Turning the author column off must remove it, not merely reorder.
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Author').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Ursula Le Guin'), findsNothing);
  });

  testWidgets('a rating is announced once, not five times', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, books);
    await tester.tap(find.byIcon(Icons.view_list_outlined));
    await tester.pumpAndSettle();

    // ListTile merges its children's semantics, so the rating arrives as part
    // of the row's label rather than as a node of its own. What matters is that
    // it is announced once as a value, not as five separate star icons.
    expect(find.bySemanticsLabel(RegExp(r'4\.5 / 5')), findsOneWidget);
    semantics.dispose();
  });
}
