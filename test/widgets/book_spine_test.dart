import 'package:material_ui/material_ui.dart';
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

  test('a book keeps its binding when the theme changes', () {
    for (var index = 0; index < 200; index++) {
      final id = 'book-$index';
      final light = BookSpine.resolveVisual(
          id, PaperfoldTokens.colorScheme(Brightness.light));
      final dark = BookSpine.resolveVisual(
          id, PaperfoldTokens.colorScheme(Brightness.dark));
      expect(light.background, dark.background);
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
