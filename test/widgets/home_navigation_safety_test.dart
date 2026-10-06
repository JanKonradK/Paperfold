import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';
import 'package:paperfold/widgets/paperfold_library_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shelf_home_fixtures.dart';

void main() {
  testWidgets('four tabs stay usable at 320px with large text and safe Back',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    fakeData = populatedData();
    final startup = Completer<void>();
    final direction = ValueNotifier(TextDirection.ltr);
    addTearDown(direction.dispose);
    // Real glyph widths catch clipped navigation labels at twice normal size.
    await tester.runAsync(() async {
      await (FontLoader(PaperfoldTypeTokens.chromeFamily)
            ..addFont(rootBundle.load('assets/fonts/SourceSans3-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/SourceSans3-SemiBold.ttf')))
          .load();
    });
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: newTestOverrides(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        locale: const Locale('en'),
        theme: paperfoldLibraryTheme(ThemeData(
          fontFamily: PaperfoldTypeTokens.chromeFamily,
          colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
        )),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: ValueListenableBuilder(
            valueListenable: direction,
            builder: (_, value, child) => Directionality(
              textDirection: value,
              child: child!,
            ),
            child: child!,
          ),
        ),
        home: HomePage(databaseReady: startup.future),
      ),
    ));
    await tester.pumpAndSettle();

    Finder tab(int index) => find.byKey(ValueKey('navigation-tab-$index'));
    void expectUsableTabs() {
      const labels = ['Journal', 'Library', 'Statistics', 'Settings'];
      for (var index = 0; index < labels.length; index++) {
        expect(tab(index).hitTestable(), findsOneWidget);
        expect(tester.getSize(tab(index)).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(tab(index)).height, greaterThanOrEqualTo(48));
        expect(tester.widget<Semantics>(tab(index)).properties.label,
            labels[index]);
        final label = find.descendant(
          of: find.descendant(
              of: tab(index), matching: find.text(labels[index])),
          matching: find.byType(RichText),
        );
        expect(tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
            isFalse,
            reason: '${labels[index]} must remain fully readable');
        expect(
          tester.renderObject<RenderParagraph>(label).getBoxesForSelection(
                TextSelection(
                    baseOffset: 0, extentOffset: labels[index].length),
              ),
          hasLength(1),
          reason: '${labels[index]} must not split in the middle of the word',
        );
      }
    }

    expectUsableTabs();

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

    await tester.tap(tab(0));
    await tester.pumpAndSettle();
    expectUsableTabs();
    await tester.tap(tab(2));
    await tester.pumpAndSettle();
    expectUsableTabs();
    await tester.tap(tab(3));
    await tester.pumpAndSettle();
    expectUsableTabs();
    direction.value = TextDirection.rtl;
    await tester.pumpAndSettle();
    expectUsableTabs();
    for (final index in [0, 2]) {
      expect(tester.getCenter(tab(index)).dx,
          greaterThan(tester.getCenter(tab(index + 1)).dx));
    }
    expect(
        tester.getCenter(tab(2)).dy, greaterThan(tester.getCenter(tab(0)).dy));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<Semantics>(tab(2)).properties.selected, isTrue);
    expect(stage.phase, ShelfPhase.held);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.widget<Semantics>(tab(0)).properties.selected, isTrue);
    expect(stage.phase, ShelfPhase.held);
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
    await tester.tap(tab(3));
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
