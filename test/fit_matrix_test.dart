import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/page/book_detail.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/page/home_page/statistics_page.dart';
import 'package:paperfold/utils/paperfold_layout.dart';
import 'package:paperfold/widgets/bookshelf/bookcase.dart';
import 'package:paperfold/widgets/bookshelf/shelf_stage.dart';
import 'package:paperfold/widgets/paperfold_library_theme.dart';
import 'package:paperfold/widgets/reading_page/reader_chrome.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/shelf_home_fixtures.dart';

late ProviderContainer container;

Widget host(Widget child, double scale) => UncontrolledProviderScope(
  container: container,
  child: ProviderScope(
    overrides: newTestOverrides(
      journalEntries: List.generate(
        30,
        (i) => JournalPage(
          id: i,
          bookId: 1,
          pageIndex: i,
          body: 'Journal entry $i with a long line of text. ' * 4,
        ),
      ),
    ),
    child: MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('en'),
      localizationsDelegates: [
        L10n.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: L10n.supportedLocales,
      theme: paperfoldLibraryTheme(
        ThemeData(colorScheme: PaperfoldTokens.colorScheme(Brightness.light)),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: child,
    ),
  ),
);

void main() {
  setUpAll(() {
    container = ProviderContainer();
  });
  tearDownAll(() => container.dispose());
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefs().initPrefs();
    fakeData = populatedData();
  });

  for (final sample in [
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 2.0),
    (const Size(412, 915), 1.0),
    (const Size(915, 412), 1.0),
    (const Size(800, 1280), 1.0),
    (const Size(1280, 800), 1.0),
  ]) {
    final (size, scale) = sample;
    void window(WidgetTester tester) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
    }

    testWidgets('home tabs $size text $scale', (tester) async {
      window(tester);
      await tester.pumpWidget(
        host(HomePage(databaseReady: Completer<void>().future), scale),
      );
      await tester.pumpAndSettle();
      final library = tester.state(find.byType(Bookcase));
      final first = tester.getRect(
        find.byKey(const ValueKey('navigation-tab-0')),
      );
      final last = tester.getRect(
        find.byKey(const ValueKey('navigation-tab-3')),
      );
      if (size.width > size.height) {
        expect(first.left, last.left);
        expect(first.top, lessThan(last.top));
      } else {
        expect(first.left, lessThan(last.left));
      }
      expect(tester.takeException(), isNull);
      for (final tab in [0, 2, 3, 1]) {
        await tester.tap(find.byKey(ValueKey('navigation-tab-$tab')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'tab $tab');
        final scrolls = find.byType(Scrollable).hitTestable();
        if (scrolls.evaluate().isNotEmpty) {
          await tester.drag(scrolls.first, const Offset(0, -3000));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'tab $tab scrolled');
        }
        if (tab == 2 && size.width < size.height) {
          expect(
            find.descendant(
              of: find.byType(StatisticPage),
              matching: find.byType(CustomScrollView),
            ),
            findsOneWidget,
          );
        }
      }
      tester.view.physicalSize = Size(size.height, size.width);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(Bookcase)), same(library));
      expect(tester.takeException(), isNull);
    });

    testWidgets('book detail $size text $scale', (tester) async {
      window(tester);
      await tester.pumpWidget(
        host(
          BookDetail(
            book: Book.mock()
              ..id = 42
              ..title = 'A very long title for a book with no cover'
              ..description = 'A long description. ' * 40,
          ),
          scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reader tools $size text $scale', (tester) async {
      window(tester);
      final calls = <ReaderTool>[];
      await tester.pumpWidget(
        host(
          Scaffold(
            body: Stack(
              children: [
                ReaderChrome(
                  visible: true,
                  title: 'A very long book title',
                  bookmarkExists: false,
                  activeTool: ReaderTool.style,
                  panel: const SingleChildScrollView(
                    child: Text('Quick settings'),
                  ),
                  onDismiss: () {},
                  onBack: () {},
                  onBookmark: () {},
                  onCopyChapter: () {},
                  onBookDetails: () {},
                  onContents: () => calls.add(ReaderTool.contents),
                  onSearch: () => calls.add(ReaderTool.search),
                  onBookmarks: () => calls.add(ReaderTool.bookmarks),
                  onNotes: () => calls.add(ReaderTool.notes),
                  onProgress: () => calls.add(ReaderTool.progress),
                  onStyle: () => calls.add(ReaderTool.style),
                ),
              ],
            ),
          ),
          scale,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in [
        'Contents',
        'Search',
        'Bookmark',
        'Notes',
        'Progress',
        'Quick settings',
      ]) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }
      expect(calls, [
        ReaderTool.contents,
        ReaderTool.search,
        ReaderTool.bookmarks,
        ReaderTool.notes,
        ReaderTool.progress,
        ReaderTool.style,
      ]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cover density $size text $scale', (tester) async {
      window(tester);
      Prefs().shelfCoverView = true;
      final books = List.generate(
        20,
        (i) => ShelfBook(
          id: '$i',
          title: 'Long book title $i',
          author: 'An author',
          binding: BookBinding.hardback,
        ),
      );
      await tester.pumpWidget(
        host(
          Scaffold(
            body: ListenableBuilder(
              listenable: Prefs(),
              builder: (_, _) => ShelfStage(showCovers: true, books: books),
            ),
          ),
          scale,
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(ShelfStage));
      final layout = PaperfoldLayout.of(context);
      final density = layout.covers(0);
      if (!layout.landscape) expect(density.columns, layout.tablet ? 5 : 3);
      final first = find.byKey(const ValueKey('shelf-cover-0'));
      expect(tester.getSize(first).width, closeTo(density.coverWidth, .01));
      expect(
        tester
            .getTopLeft(
              find.byKey(ValueKey('shelf-cover-${density.columns - 1}')),
            )
            .dy,
        tester.getTopLeft(first).dy,
      );
      Prefs().libraryCoversPerRow = 2;
      await tester.pumpAndSettle();
      expect(tester.getSize(first).width, greaterThan(density.coverWidth));
      for (final preference in [0, 1, 2, 3, 5, 8, 99]) {
        expect(layout.covers(preference).coverWidth, greaterThanOrEqualTo(72));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
