import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shelf_home_fixtures.dart';

/// The reduce-motion, right-to-left pass for the sliding navigation bar.
///
/// It used to sit at the end of the shelf home test, where it pumped into an
/// empty tree. The cause was not the bookcase: `Sync` is a Riverpod notifier
/// and a singleton at the same time, so the second ProviderContainer in an
/// isolate throws `LateInitializationError` on the notifier's write-once
/// `_element`, and `SyncButton` in the Library app bar is what reads it.
/// `flutter test` runs each file in its own isolate, so one container per file
/// keeps the singleton happy. Do not add a second `ProviderScope` here.
void main() {
  testWidgets(
    'the navigation bar mirrors and stops animating when the system asks',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await Prefs().initPrefs();
      fakeData = populatedData();
      await tester.binding.setSurfaceSize(const Size(412, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: newTestOverrides(),
          child: MaterialApp(
            // The locale stays English so the labels stay assertable. Only the
            // direction and the animation setting change.
            locale: const Locale('en'),
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: child!,
              ),
            ),
            home: HomePage(
              databaseReady: _never,
              startupRevealReady: Future<void>.value(),
            ),
          ),
        ),
      );
      // The bar sits behind a blur surface and a LayoutBuilder, so the sliding
      // indicator arrives on the frame after the first one, not on it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Right to left, the first tab is the rightmost one.
      expect(
        tester.getCenter(find.text('Journal')).dx,
        greaterThan(tester.getCenter(find.text('Library')).dx),
      );
      expect(
        tester.getCenter(find.text('Library')).dx,
        greaterThan(tester.getCenter(find.text('More')).dx),
      );

      // skipOffstage is off for the same reason as in the shelf home test: the
      // Scaffold lays the bar out under extendBody and the default finder
      // stopped counting the pill after the taller bookcase landed.
      final indicator = find.byKey(
        const Key('sliding-navigation-indicator'),
        skipOffstage: false,
      );
      expect(indicator, findsOneWidget);
      expect(
        tester.widget<AnimatedPositionedDirectional>(indicator).duration,
        Duration.zero,
      );

      // The indicator is positioned from the start edge, which is the right
      // edge here. Library is selected first, so moving to Journal must send
      // the pill right, not left.
      final libraryTabRect = tester.getRect(indicator);
      await tester.tap(find.text('Journal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getRect(indicator).left, greaterThan(libraryTabRect.left));

      expect(tester.takeException(), isNull);
    },
  );
}

final Future<void> _never = Completer<void>().future;
