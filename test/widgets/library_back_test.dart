import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shelf_home_fixtures.dart';

/// A file of its own, for the same reason the other Library tests are: `Sync`
/// is a Riverpod notifier and a singleton at once, so one pump of the Library
/// per isolate.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  testWidgets('back puts a held book on its shelf instead of leaving',
      (tester) async {
    final handle = LibraryBackHandle();
    addTearDown(handle.dispose);
    fakeData = populatedData();
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
          home: ShelfHomePage(backHandle: handle),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nothing off the shelf: back is not the Library's to take.
    expect(handle.canTakeBack, isFalse);
    expect(handle.takeBack(), isFalse);

    final bookcase = tester.state<BookcaseState>(find.byType(Bookcase));
    final stage = bookcase.activeStage!;
    stage.pickUp();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(stage.phase, ShelfPhase.held);

    // Now it is, and taking it puts the book back rather than popping a route.
    expect(handle.canTakeBack, isTrue);
    expect(handle.takeBack(), isTrue);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(stage.phase, ShelfPhase.shelved);
    expect(handle.canTakeBack, isFalse);
  });
}
