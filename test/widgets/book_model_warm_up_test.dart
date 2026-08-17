import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/widgets/book_model/book_model_builder.dart';
import 'package:paperfold/widgets/book_model/book_model_scene.dart';
import 'package:paperfold/widgets/book_model/book_model_warm_up.dart';

BookModelSpec _spec(int index) {
  final binding = index.isEven ? BookBinding.hardback : BookBinding.softback;
  final seed = index * 7919;
  return BookModelSpec(
    binding: binding,
    title: 'A Title Number $index',
    author: 'An Author Number $index',
    palette: BookModelPalette.resolve(
      scheme: const ColorScheme.dark(),
      binding: binding,
      seed: seed,
    ),
    typography: const BookModelTypography(
      title: TextStyle(),
      author: TextStyle(),
      label: TextStyle(),
    ),
    seed: seed,
    detail: BookDetail.reduced,
  );
}

String _keyOf(BookModelSpec spec) => '${spec.seed}|${spec.title}';

void main() {
  setUp(BookModelWarmUp.reset);

  test('a slice draws books and says when there are more', () {
    final specs = [for (var index = 0; index < 40; index++) _spec(index)];

    // A budget of nothing still draws one book, then stops: the check happens
    // after the work, so no call can be a no-op that never makes progress.
    final more = BookModelWarmUp.slice(
      specs,
      keyOf: _keyOf,
      budget: Duration.zero,
    );

    expect(BookModelWarmUp.warmed, 1);
    expect(more, isTrue);
  });

  test('slices carry on where the last one stopped, and then finish', () {
    final specs = [for (var index = 0; index < 12; index++) _spec(index)];

    var rounds = 0;
    while (BookModelWarmUp.slice(specs, keyOf: _keyOf, budget: Duration.zero)) {
      rounds++;
      expect(rounds, lessThan(40), reason: 'the warm-up is not converging');
    }

    expect(BookModelWarmUp.warmed, 12);
    // And asking again is free, because everything is already drawn.
    expect(BookModelWarmUp.slice(specs, keyOf: _keyOf), isFalse);
    expect(BookModelWarmUp.warmed, 12);
  });

  test('warming lays out the type the shelf is about to need', () {
    // The point of the whole exercise: the run cache is what costs a frame, so
    // it has to be the thing that ends up full.
    BookTextRun.debugClear();
    expect(BookTextRun.debugCount, 0);

    final specs = [for (var index = 0; index < 6; index++) _spec(index)];
    BookModelWarmUp.slice(specs, keyOf: _keyOf, budget: const Duration(hours: 1));

    expect(BookModelWarmUp.warmed, 6);
    expect(
      BookTextRun.debugCount,
      greaterThanOrEqualTo(6),
      reason: 'the titles were not laid out',
    );
  });

  test('the run cache drops its oldest entry, not all of them', () {
    // The defect this guards: the cache emptied itself the moment it went one
    // over its limit. Laying out type is the most expensive thing the model
    // does, and a shelf shows about forty runs at once, so any library past the
    // limit threw away everything it was about to need — over and over, for as
    // long as the reader kept scrolling.
    BookTextRun.debugClear();
    const style = TextStyle(fontSize: 0.02);

    BookTextRun resolve(String content) => BookTextRun.resolve(
          content: content,
          style: style,
          maxWidth: 0.5,
          maxLines: 1,
          align: TextAlign.center,
          ellipsis: false,
          scale: 1000,
        );

    final first = resolve('the oldest run');
    for (var index = 0; index < BookTextRun.debugLimit + 4; index++) {
      resolve('filler $index');
    }

    // Full, not empty.
    expect(BookTextRun.debugCount, BookTextRun.debugLimit);
    // The oldest went, so asking for it again is a fresh layout.
    expect(identical(resolve('the oldest run'), first), isFalse);
    // And the most recent filler survived, which a clear-the-world would not
    // have allowed.
    final recent = resolve('filler ${BookTextRun.debugLimit + 3}');
    expect(identical(resolve('filler ${BookTextRun.debugLimit + 3}'), recent),
        isTrue);
  });

  test('the palette cache drops its oldest entry, not all of them', () {
    BookModelPalette.debugClear();
    const scheme = ColorScheme.dark();

    BookModelPalette resolve(int seed) => BookModelPalette.resolve(
          scheme: scheme,
          binding: BookBinding.hardback,
          seed: seed,
        );

    final first = resolve(1);
    expect(identical(resolve(1), first), isTrue);

    for (var seed = 2; seed < BookModelPalette.debugLimit + 6; seed++) {
      resolve(seed);
    }

    expect(BookModelPalette.debugCount, BookModelPalette.debugLimit);
    // Everything after the overflow is still there, rather than the table
    // having been emptied and every book in view missing at once.
    final recent = resolve(BookModelPalette.debugLimit + 5);
    expect(identical(resolve(BookModelPalette.debugLimit + 5), recent), isTrue);
  });
}
