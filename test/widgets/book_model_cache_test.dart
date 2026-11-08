import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/widgets/book_model/book_model_builder.dart';
import 'package:paperfold/widgets/book_model/book_model_scene.dart';

void main() {
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
