import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';
import 'package:paperfold/widgets/paperfold_library_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shelf_home_fixtures.dart';

void main() {
  testWidgets('short large-text library keeps actions reachable and back safe',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    fakeData = populatedData();
    final startup = Completer<void>();
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: newTestOverrides(),
      child: MaterialApp(
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('en'),
        theme: paperfoldLibraryTheme(ThemeData(
          colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
        )),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: HomePage(databaseReady: startup.future),
      ),
    ));
    await tester.pumpAndSettle();

    final bookcase = tester.state<BookcaseState>(find.byType(Bookcase));
    final stage = bookcase.activeStage!;
    final lastBook = find.byKey(const ValueKey('shelf-spine-book-8'));
    await tester.scrollUntilVisible(lastBook, 80,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('shelf-spines')),
          matching: find.byType(Scrollable),
        ));
    await tester.pumpAndSettle();
    expect(lastBook.hitTestable(), findsOneWidget);
    await tester.tap(lastBook);
    await tester.pumpAndSettle();
    expect(stage.phase, ShelfPhase.held);

    // The held-book pane scrolls independently below the fixed shelf controls.
    final open = find.byKey(const ValueKey('open-shelf-book'));
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    expect(open.hitTestable(), findsOneWidget);
    final notes = find.byKey(const ValueKey('shelf-book-notes'));
    await tester.ensureVisible(notes);
    await tester.pumpAndSettle();
    expect(notes.hitTestable(), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('navigation-tab-0')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(stage.phase, ShelfPhase.held,
        reason: 'an offstage library must not consume another tab\'s Back');
    expect(find.byType(Bookcase).hitTestable(), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(stage.phase, ShelfPhase.shelved);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(
        tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>)).canPop,
        isTrue);
    await tester.tap(find.byKey(const ValueKey('navigation-tab-2')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<PopScope<Object?>>(find.byType(PopScope<Object?>)).canPop,
        isFalse,
        reason: 'changing destinations cancels the armed app exit');
    expect(tester.takeException(), isNull);
    startup.completeError(StateError('Database unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Paperfold could not start.'), findsOneWidget);
    expect(find.byType(Bookcase), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
