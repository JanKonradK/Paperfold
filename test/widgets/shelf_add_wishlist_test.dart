import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shelf_home_fixtures.dart';

/// A file of its own, for the same reason `home_navigation_test.dart` is one:
/// `Sync` is a Riverpod notifier and a hand-rolled singleton at once, so a
/// second `ProviderScope` in the same isolate hands its State to a second
/// element and the subscription inside it throws. One pump of the Library per
/// file.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Prefs().initPrefs();
  });

  testWidgets('backing out of "Add a book to buy" does not outlive its fields',
      (tester) async {
    // The controllers used to belong to the caller and were disposed in a
    // `finally` the moment `showDialog` returned. The dialog goes on being
    // built for the whole of its exit animation, so any dismissal that was not
    // a tap on one of the two buttons - the back gesture, for one - painted two
    // disposed TextEditingControllers and took the application down with it.
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
          home: const ShelfHomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a book to buy'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));

    // The back button, not Cancel: this is the path that used to crash.
    await tester.binding.handlePopRoute();
    // Part way through the exit animation, which is where the disposed fields
    // were being painted, and then all the way out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsNothing);
  });
}
