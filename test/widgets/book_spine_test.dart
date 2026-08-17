import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';

void main() {
  test('one book keeps one colour', () {
    final scheme = PaperfoldTokens.colorScheme(Brightness.light);
    final first = BookSpine.resolveVisual('book-42', scheme);
    final second = BookSpine.resolveVisual('book-42', scheme);

    expect(first.background, second.background);
    expect(first.foreground, second.foreground);
    expect(
      identical(
        BookSpine.backgroundsFor(Brightness.light),
        BookSpine.backgroundsFor(Brightness.light),
      ),
      isTrue,
    );
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
}
