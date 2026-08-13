import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/reading_page/reader_chrome.dart';

void main() {
  Widget host(
    Widget child, {
    TextDirection direction = TextDirection.ltr,
    bool disableAnimations = false,
  }) {
    return MaterialApp(
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      locale: const Locale('en'),
      theme: ThemeData(
        colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
        useMaterial3: true,
      ),
      home: Directionality(
        textDirection: direction,
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: Stack(fit: StackFit.expand, children: [child]),
          ),
        ),
      ),
    );
  }

  ReaderChrome chrome({
    bool visible = true,
    ReaderTool activeTool = ReaderTool.none,
    Widget? panel,
  }) {
    return ReaderChrome(
      visible: visible,
      title: 'The Left Hand of Darkness',
      bookmarkExists: ValueNotifier<bool>(false),
      activeTool: activeTool,
      panel: panel,
      onDismiss: () {},
      onBack: () {},
      onBookmark: () {},
      onCopyChapter: () {},
      onBookDetails: () {},
      onContents: () {},
      onNotes: () {},
      onProgress: () {},
      onStyle: () {},
    );
  }

  testWidgets('the bars sit at the ends of the screen, not in the middle',
      (tester) async {
    await tester.pumpWidget(host(chrome()));
    await tester.pumpAndSettle();

    final screen = tester.getSize(find.byType(Scaffold));
    final title = tester.getRect(find.text('The Left Hand of Darkness'));
    final tabs = tester.getRect(find.byIcon(Icons.toc));

    expect(title.top, lessThan(screen.height * 0.2),
        reason: 'the top bar belongs at the top');
    expect(tabs.bottom, greaterThan(screen.height * 0.8),
        reason: 'the bottom shell belongs at the bottom');
  });

  testWidgets('hidden chrome takes no taps', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(host(
      ReaderChrome(
        visible: false,
        title: 'A book',
        bookmarkExists: ValueNotifier<bool>(false),
        activeTool: ReaderTool.none,
        onDismiss: () => dismissed = true,
        onBack: () {},
        onBookmark: () {},
        onCopyChapter: () {},
        onBookDetails: () {},
        onContents: () {},
        onNotes: () {},
        onProgress: () {},
        onStyle: () {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();
    expect(dismissed, isFalse);
  });

  testWidgets('every tool target is at least 48dp', (tester) async {
    await tester.pumpWidget(host(chrome()));
    await tester.pumpAndSettle();

    for (final icon in [
      Icons.toc,
      Icons.edit_outlined,
      Icons.data_usage,
      Icons.palette_outlined,
    ]) {
      final target = find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(InkWell),
      );
      final size = tester.getSize(target.first);
      expect(size.height, greaterThanOrEqualTo(48.0), reason: '$icon height');
      expect(size.width, greaterThanOrEqualTo(48.0), reason: '$icon width');
    }
  });

  testWidgets('the open tool is announced as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(chrome(activeTool: ReaderTool.progress)));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(
      find.bySemanticsLabel('Progress').first,
    );
    expect(node.hasFlag(SemanticsFlag.isSelected), isTrue);
    handle.dispose();
  });

  testWidgets('an open panel sits above the tools', (tester) async {
    await tester.pumpWidget(host(chrome(
      activeTool: ReaderTool.notes,
      panel: const SizedBox(height: 120, child: Text('panel body')),
    )));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.text('panel body')).bottom,
      lessThanOrEqualTo(tester.getRect(find.byIcon(Icons.toc)).top),
    );
  });

  testWidgets('a right-to-left reader gets the same two bars', (tester) async {
    await tester.pumpWidget(host(chrome(), direction: TextDirection.rtl));
    await tester.pumpAndSettle();

    final screen = tester.getSize(find.byType(Scaffold));
    expect(tester.getRect(find.byIcon(Icons.arrow_back)).top,
        lessThan(screen.height * 0.2));
    expect(tester.getRect(find.byIcon(Icons.toc)).bottom,
        greaterThan(screen.height * 0.8));
  });

  testWidgets('the bars are already in place when animations are off',
      (tester) async {
    await tester.pumpWidget(host(chrome(), disableAnimations: true));
    await tester.pumpAndSettle();

    for (final slide
        in tester.widgetList<AnimatedSlide>(find.byType(AnimatedSlide))) {
      expect(slide.duration, Duration.zero,
          reason: 'the bars must not travel when motion is removed');
    }
    for (final fade
        in tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))) {
      expect(fade.duration, Duration.zero);
    }
  });

  testWidgets('the bars travel when motion is allowed', (tester) async {
    await tester.pumpWidget(host(chrome()));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<AnimatedSlide>(find.byType(AnimatedSlide))
          .every((slide) => slide.duration > Duration.zero),
      isTrue,
    );
  });

  // A bookmark appearing or disappearing is a page turn, and a page turn must
  // not rebuild the chrome to say so - let alone the reading page above it,
  // which is what used to happen, WebView subtree and all, once per turn.
  testWidgets('the bookmark toggle follows its notifier without a rebuild',
      (tester) async {
    final exists = ValueNotifier<bool>(false);
    addTearDown(exists.dispose);
    var chromeBuilds = 0;

    await tester.pumpWidget(host(
      Builder(builder: (context) {
        chromeBuilds++;
        return ReaderChrome(
          visible: true,
          title: 'A book',
          bookmarkExists: exists,
          activeTool: ReaderTool.none,
          onDismiss: () {},
          onBack: () {},
          onBookmark: () {},
          onCopyChapter: () {},
          onBookDetails: () {},
          onContents: () {},
          onNotes: () {},
          onProgress: () {},
          onStyle: () {},
        );
      }),
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    final buildsBefore = chromeBuilds;

    exists.value = true;
    await tester.pump();

    expect(find.byIcon(Icons.bookmark), findsOneWidget,
        reason: 'the toggle did not follow the notifier');
    expect(chromeBuilds, buildsBefore,
        reason: 'the whole chrome rebuilt for one icon');
  });
}
