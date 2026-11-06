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
  testWidgets(
    'paper detail, missing cover and double text retain the primary action',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().initPrefs();
      final book = Book.mock()
        ..id = 42
        ..title = 'The Left Hand of Darkness'
        ..author = 'Ursula Le Guin';
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [
              L10n.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: L10n.supportedLocales,
            locale: const Locale('en'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: BookDetail(book: book),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookLight), findsOneWidget);
      expect(find.byType(Hero), findsOneWidget);
      expect(tester.widget<Hero>(find.byType(Hero)).tag, 'book-detail-book-42');
      expect(find.text('Log progress').hitTestable(), findsOneWidget);
      expect(
        find.byKey(const ValueKey('open-shelf-book')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
