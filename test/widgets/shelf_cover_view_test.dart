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
  testWidgets('covers open directly at double text size', (tester) async {
    String? opened;
    await host(
      tester,
      ShelfStage(books: books, showCovers: true, onOpen: (b) => opened = b.id),
      scale: 2,
    );
    await tester.tap(find.byKey(const ValueKey('shelf-cover-a')));
    await tester.pumpAndSettle();
    expect(opened, 'a');
    expect(tester.takeException(), isNull);
  });
  testWidgets('spines wrap and never shrink below 48', (tester) async {
    await tester.binding.setSurfaceSize(const Size(240, 500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await host(
      tester,
      ShelfStage(
        books: [
          ...books,
          ...List.generate(
            8,
            (i) => ShelfBook(
              id: 'x$i',
              title: 'Book $i',
              author: '',
              binding: BookBinding.hardback,
            ),
          ),
        ],
      ),
    );
    final first = find.byKey(const ValueKey('shelf-spine-a'));
    final third = find.byKey(const ValueKey('shelf-spine-x1'));
    expect(tester.getSize(first).width, greaterThanOrEqualTo(48));
    expect(
      tester.getTopLeft(third).dy,
      greaterThan(tester.getTopLeft(first).dy),
    );
    expect(tester.takeException(), isNull);
  });
}

