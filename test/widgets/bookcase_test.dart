import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const books = [
  ShelfBook(
    id: 'a',
    title: 'Dune',
    author: 'Frank Herbert',
    binding: BookBinding.hardback,
  ),
  ShelfBook(
    id: 'b',
    title: 'Earthsea',
    author: 'Ursula Le Guin',
    binding: BookBinding.softback,
  ),
];
Future<void> host(WidgetTester tester, Widget child, {double scale = 1}) async {
  SharedPreferences.setMockInitialValues({});
  await Prefs().initPrefs();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: [
        L10n.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: L10n.supportedLocales,
      locale: const Locale('en'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shelf change keeps direct activation', (tester) async {
    final key = GlobalKey<BookcaseState>();
    String? opened;
    await host(
      tester,
      Bookcase(
        key: key,
        showSignposts: false,
        shelves: const [
          ShelfRow(name: 'One', books: books),
          ShelfRow(name: 'Two', books: books),
        ],
        onOpen: (b) => opened = b.id,
      ),
    );
    key.currentState!.climbTo(1);
    await tester.pumpAndSettle();
    expect(key.currentState!.shelf, 1);
    await tester.tap(find.byKey(const ValueKey('shelf-spine-a')).hitTestable());
    expect(opened, 'a');
    expect(key.currentState!.activeStage!.phase, ShelfPhase.shelved);
  });
}
