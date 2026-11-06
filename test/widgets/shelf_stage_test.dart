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
  testWidgets('tap opens directly; long press opens only quick actions', (
    tester,
  ) async {
    String? opened, options;
    final key = GlobalKey<ShelfStageState>();
    await host(
      tester,
      ShelfStage(
        key: key,
        books: books,
        onOpen: (b) => opened = b.id,
        onOptions: (b) => options = b.id,
      ),
    );
    final spine = find.byKey(const ValueKey('shelf-spine-a'));
    await tester.tap(spine);
    await tester.pumpAndSettle();
    expect(opened, 'a');
    expect(key.currentState!.phase, ShelfPhase.shelved);
    opened = null;
    await tester.longPress(spine);
    await tester.pumpAndSettle();
    expect(options, 'a');
    expect(opened, isNull);
    tester.widget<InkWell>(spine).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(key.currentState!.current!.id, 'b');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, 'b');
    expect(tester.takeException(), isNull);
  });
}
