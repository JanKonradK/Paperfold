import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/settings/library_layout_control.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shelf_home_fixtures.dart';

void main() {
  testWidgets(
    'density previews real covers, persists, and adds landscape columns',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await Prefs().initPrefs();
      fakeData = populatedData();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: newTestOverrides(),
          child: MaterialApp(
            localizationsDelegates: [
              L10n.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: L10n.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: LibraryLayoutControl()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BookCover), findsNWidgets(3));
      expect(find.text('3'), findsOneWidget);
      expect(Prefs().libraryCoversPerRow, 0);
      await tester.tap(find.byTooltip('More covers'));
      await tester.pumpAndSettle();
      expect(Prefs().libraryCoversPerRow, 4);
      expect(find.byType(BookCover), findsNWidgets(4));
      tester.view.physicalSize = const Size(915, 412);
      await tester.binding.setSurfaceSize(const Size(915, 412));
      await tester.pumpAndSettle();
      expect(Prefs().libraryCoversPerRow, 4);
      expect(find.textContaining('9 covers per row now'), findsOneWidget);
      await tester.tap(find.text('Auto'));
      await tester.pumpAndSettle();
      expect(Prefs().libraryCoversPerRow, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
