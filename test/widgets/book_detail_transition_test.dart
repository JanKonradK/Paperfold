import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/book_detail.dart';
import 'package:paperfold/widgets/book_light.dart';
import 'package:paperfold/widgets/bookshelf/book_detail_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('spine flight reaches detail and reverses on Back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    final book = Book.mock()..id = 7;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: [
            L10n.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: L10n.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: InkWell(
                  onTap: () =>
                      Navigator.of(context)
                          .push(bookDetailRoute(context, book)),
                  child: BookDetailHero(
                    id: 'book-7',
                    spine: true,
                    cover: const ColoredBox(color: Colors.red),
                    child: const SizedBox(
                      width: 48,
                      height: 180,
                      child: ColoredBox(color: Colors.blue),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.byType(BookDetail), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(BookDetail), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final remove in [false, true]) {
    testWidgets(
      'Hero uses book id with empty paths; remove animations $remove',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await Prefs().initPrefs();
        final first = Book.mock()..id = 1;
        final second = Book.mock()..id = 2;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: remove),
              child: Builder(
                builder: (context) => Column(
                  children: [
                    BookDetailHero(
                      id: 'book-${first.id}',
                      spine: true,
                      cover: const SizedBox(width: 100, height: 150),
                      child: const SizedBox(width: 48, height: 180),
                    ),
                    BookDetailHero(
                      id: 'book-${second.id}',
                      cover: const SizedBox(width: 100, height: 150),
                      child: const SizedBox(width: 48, height: 180),
                    ),
                    TextButton(
                      onPressed: () {
                        final route = bookDetailRoute(context, first);
                        expect(
                          route.transitionDuration.inMilliseconds,
                          remove ? 0 : 300,
                        );
                        expect(
                          route.reverseTransitionDuration,
                          route.transitionDuration,
                        );
                      },
                      child: const Text('Check'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Check'));
        expect(
          tester
              .widgetList<Hero>(find.byType(Hero))
              .map((h) => h.tag)
              .toSet()
              .length,
          2,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
