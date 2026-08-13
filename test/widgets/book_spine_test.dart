import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';

void main() {
  test('spine dimensions are stable and keep the minimum touch width', () {
    final scheme = PaperfoldTokens.colorScheme(Brightness.light);
    final first = BookSpine.resolveVisual('book-42', scheme);
    final second = BookSpine.resolveVisual('book-42', scheme);

    expect(first.width, second.width);
    expect(first.height, second.height);
    expect(first.background, second.background);
    expect(first.width, greaterThanOrEqualTo(BookSpine.minimumWidth));
    expect(first.width, lessThanOrEqualTo(BookSpine.maximumWidth));
    expect(first.height, greaterThanOrEqualTo(BookSpine.minimumHeight));
    expect(
        first.height, greaterThanOrEqualTo(BookSpine.fullLengthMinimumHeight));
    expect(first.height, lessThanOrEqualTo(BookSpine.maximumHeight));
    expect(first.height / first.width, inInclusiveRange(4, 6));
    expect(identical(BookSpine.backgrounds(), BookSpine.backgrounds()), isTrue);
  });

  test('stable spine craft includes square and rounded heads', () {
    final scheme = PaperfoldTokens.colorScheme(Brightness.light);
    final visuals = [
      for (var index = 0; index < 32; index++)
        BookSpine.resolveVisual('head-$index', scheme),
    ];

    expect(visuals.any((visual) => visual.hasRoundedHead), isTrue);
    expect(visuals.any((visual) => !visual.hasRoundedHead), isTrue);
  });

  test('light and dark draw from different bookcloth', () {
    final light = BookSpine.backgroundsFor(Brightness.light);
    final dark = BookSpine.backgroundsFor(Brightness.dark);

    // The light theme is the printed keepsake page: pale, near-uniform spines.
    // The dark theme is the saturated cover world, where the books are the only
    // colour on a black screen. One shared table cannot be both.
    expect(light, isNot(same(dark)));
    expect(
      identical(
        BookSpine.backgroundsFor(Brightness.light),
        BookSpine.backgroundsFor(Brightness.light),
      ),
      isTrue,
      reason: 'each table is built once, never per frame',
    );

    double meanLuminance(List<Color> colors) =>
        colors.map((c) => c.computeLuminance()).reduce((a, b) => a + b) /
        colors.length;

    expect(
      meanLuminance(light),
      greaterThan(meanLuminance(dark)),
      reason: 'light spines must be pale and dark spines saturated',
    );

    // A pale spine must still separate from the paper ground, or the shelf
    // dissolves into the page.
    for (final colour in light) {
      expect(
        BookSpine.contrast(colour, PaperfoldTokens.light.ground),
        greaterThan(1.05),
        reason: 'a light spine must be visible against paper',
      );
    }
  });

  for (final brightness in Brightness.values) {
    test('every spine color has 4.5 to 1 contrast in ${brightness.name}', () {
      final scheme = PaperfoldTokens.colorScheme(brightness);
      for (var index = 0; index < 200; index++) {
        final visual = BookSpine.resolveVisual('book-$index', scheme);
        expect(visual.contrastRatio, greaterThanOrEqualTo(4.5));
        expect(visual.background, isNot(PaperfoldTokens.light.ground));
      }
    });
  }

  testWidgets('spine survives large text and mirrors its title in RTL',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
        ),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Center(
                child: BookSpine(
                  stableId: 'lean-4',
                  title: 'A title that is deliberately much too long',
                  author: 'An author with a long name',
                  semanticLabel: 'Accessible full title and author',
                  onTap: _noop,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Accessible full title and author'),
        findsOneWidget);
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 1);
  });

  testWidgets('long title and author stay complete and wrap on the spine',
      (tester) async {
    const title =
        'Rascal Does Not Dream of a Nightingale and the Long Road Home';
    const author = 'Hajime Kamoshida';
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
        ),
        home: const Scaffold(
          body: Center(
            child: BookSpine(
              stableId: 'long-title',
              title: title,
              author: author,
              semanticLabel: '$title by $author',
              onTap: _noop,
            ),
          ),
        ),
      ),
    );

    final titleFinder =
        find.byKey(const ValueKey('book-spine-metadata-long-title'));
    final titleWidget = tester.widget<Text>(titleFinder);
    final titleParagraph = tester.renderObject<RenderParagraph>(titleFinder);
    final visibleMetadata = titleWidget.textSpan!.toPlainText();
    final titleBoxes = titleParagraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: visibleMetadata.length),
    );

    expect(visibleMetadata, '$title\n$author');
    expect(titleWidget.maxLines, isNull);
    expect(titleParagraph.didExceedMaxLines, isFalse);
    // Two title lines plus the author line prove that the title itself wraps.
    expect(titleBoxes.length, greaterThanOrEqualTo(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('uniform spines have identical width and height', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: PaperfoldTokens.colorScheme(Brightness.dark),
        ),
        home: const Scaffold(
          body: Row(
            children: [
              BookSpine(
                stableId: 'uniform-a',
                title: 'Dune',
                author: 'Frank Herbert',
                semanticLabel: 'Dune by Frank Herbert',
                onTap: _noop,
                uniform: true,
              ),
              BookSpine(
                stableId: 'uniform-b',
                title: 'The Left Hand of Darkness',
                author: 'Ursula Le Guin',
                semanticLabel: 'The Left Hand of Darkness by Ursula Le Guin',
                onTap: _noop,
                uniform: true,
              ),
              BookSpine(
                stableId: 'uniform-c',
                title: 'Piranesi',
                author: 'Susanna Clarke',
                semanticLabel: 'Piranesi by Susanna Clarke',
                onTap: _noop,
                uniform: true,
              ),
            ],
          ),
        ),
      ),
    );

    final sizes = [
      for (final id in ['uniform-a', 'uniform-b', 'uniform-c'])
        tester.getSize(find.byKey(ValueKey('book-spine-surface-$id'))),
    ];

    expect(sizes.map((size) => size.width).toSet(), {BookSpine.uniformWidth});
    expect(
      sizes.map((size) => size.height).toSet(),
      {BookSpine.uniformHeight},
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('spine semantics exposes and performs its tap action',
      (tester) async {
    var tapCount = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
        ),
        home: Scaffold(
          body: Center(
            child: BookSpine(
              stableId: 'semantic-book',
              title: 'The Dispossessed',
              author: 'Ursula Le Guin',
              semanticLabel: 'The Dispossessed by Ursula Le Guin',
              onTap: () => tapCount++,
            ),
          ),
        ),
      ),
    );

    const label = 'The Dispossessed by Ursula Le Guin';
    // getSemantics resolves an Element, so it takes a widget Finder, while
    // SemanticsController.tap resolves a node and takes a SemanticsFinder.
    // The two calls need the two different finder types.
    final node = tester.getSemantics(find.bySemanticsLabel(label));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    // Drive the action through SemanticsController rather than the deprecated
    // pipelineOwner.semanticsOwner. This is the path a screen reader takes.
    tester.semantics.tap(find.semantics.byLabel(label));
    await tester.pump();

    expect(tapCount, 1);
    semantics.dispose();
  });

  testWidgets('spine text keeps an effective 11 sp floor', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: PaperfoldTokens.colorScheme(Brightness.dark),
        ),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(0.5)),
          child: const Scaffold(
            body: BookSpine(
              stableId: 'lean-2',
              title: 'Earthsea',
              author: 'Ursula Le Guin',
              semanticLabel: 'Earthsea by Ursula Le Guin',
              onTap: _noop,
            ),
          ),
        ),
      ),
    );

    final metadata = tester.widget<Text>(
      find.byKey(const ValueKey('book-spine-metadata-lean-2')),
    );
    expect(metadata.textSpan!.toPlainText(), 'Earthsea\nUrsula Le Guin');
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final fontSize = text.style?.fontSize;
      if (fontSize != null) {
        expect(text.textScaler!.scale(fontSize), greaterThanOrEqualTo(11));
      }
    }
  });
}

void _noop() {}
