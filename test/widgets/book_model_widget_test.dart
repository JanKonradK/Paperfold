import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/widgets/book_model/book_model.dart';
import 'package:paperfold/widgets/book_model/book_model_builder.dart';
import 'package:paperfold/widgets/book_model/book_model_scene.dart';

void main() {
  Widget host(
    Widget child, {
    bool reduceMotion = false,
    TextDirection direction = TextDirection.ltr,
  }) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Directionality(
        textDirection: direction,
        child: Theme(
          data: ThemeData(
            colorScheme: PaperfoldTokens.colorScheme(Brightness.light),
          ),
          child: Center(
            child: SizedBox(width: 200, height: 260, child: child),
          ),
        ),
      ),
    );
  }

  BookModel book({
    BookModelController? controller,
    double? open,
    VoidCallback? onTap,
    BookBinding binding = BookBinding.hardback,
  }) {
    return BookModel(
      title: 'Kokoro',
      author: 'Natsume Soseki',
      binding: binding,
      stableId: 'book-7',
      controller: controller,
      open: open,
      onTap: onTap,
      semanticLabel: 'Kokoro by Natsume Soseki. Tap to open the book.',
    );
  }

  testWidgets('a tap opens the book and a second tap shuts it', (tester) async {
    final controller = BookModelController();
    await tester.pumpWidget(host(book(controller: controller)));

    expect(controller.value, 0);
    expect(controller.isOpen, isFalse);

    await tester.tap(find.byType(BookModel));
    // The first pump starts the ticker; the second is the one that moves it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.value, greaterThan(0));
    expect(controller.value, lessThan(1));
    await tester.pumpAndSettle();
    expect(controller.value, 1);
    expect(controller.isOpen, isTrue);

    await tester.tap(find.byType(BookModel));
    await tester.pumpAndSettle();
    expect(controller.value, 0);
    expect(controller.isOpen, isFalse);
  });

  testWidgets('a controller opens and shuts it from outside', (tester) async {
    final controller = BookModelController();
    await tester.pumpWidget(host(book(controller: controller)));

    // The futures these return only complete once frames are pumped, so they
    // are started and then waited for by pumping, never awaited here.
    unawaited(controller.open());
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);

    unawaited(controller.toggle());
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
  });

  testWidgets('a drag toward the spine opens it', (tester) async {
    final controller = BookModelController();
    await tester.pumpWidget(host(book(controller: controller)));

    await tester.drag(find.byType(BookModel), const Offset(-120, 0));
    await tester.pump();
    expect(controller.value, greaterThan(0));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);
  });

  testWidgets('in right to left, the drag goes the other way', (tester) async {
    final controller = BookModelController();
    await tester.pumpWidget(
      host(book(controller: controller), direction: TextDirection.rtl),
    );

    await tester.drag(find.byType(BookModel), const Offset(120, 0));
    await tester.pump();
    expect(controller.value, greaterThan(0));
  });

  testWidgets('when the system removes animations it opens at once',
      (tester) async {
    final controller = BookModelController();
    await tester.pumpWidget(
      host(book(controller: controller), reduceMotion: true),
    );

    await tester.tap(find.byType(BookModel));
    await tester.pump();
    // No frames were needed: the book is open on the frame after the tap.
    expect(controller.value, 1);

    await tester.tap(find.byType(BookModel));
    await tester.pump();
    expect(controller.value, 0);
  });

  testWidgets('a long press turns the book over and back', (tester) async {
    final controller = BookModelController();
    await tester.pumpWidget(host(book(controller: controller)));

    expect(controller.isTurnedOver, isFalse);
    await tester.longPress(find.byType(BookModel));
    await tester.pumpAndSettle();
    expect(controller.isTurnedOver, isTrue);

    await tester.longPress(find.byType(BookModel));
    await tester.pumpAndSettle();
    expect(controller.isTurnedOver, isFalse);
  });

  testWidgets('turning over shows the back board', (tester) async {
    final controller = BookModelController();
    await tester.pumpWidget(host(book(controller: controller)));

    bool showsBack(BookCamera camera) => BookModelRenderer.order(
          BookModelBuilder.build(
            BookModelSpec(
              binding: BookBinding.hardback,
              title: 'Kokoro',
              author: 'Natsume Soseki',
              camera: camera,
              palette: BookModelPalette.resolve(
                scheme: PaperfoldTokens.colorScheme(Brightness.light),
                binding: BookBinding.hardback,
                seed: 3,
              ),
              typography: const BookModelTypography(
                title: TextStyle(),
                author: TextStyle(),
                label: TextStyle(),
              ),
            ),
          ),
          camera,
        ).any((entry) => entry.face.debugName == 'back-board-outer');

    const front = BookCamera();
    expect(showsBack(front), isFalse);
    expect(showsBack(front.copyWith(yaw: front.yaw + math.pi)), isTrue);
  });

  testWidgets('a driven book ignores taps and follows the value given',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(host(book(open: 0.4, onTap: () => tapped++)));

    await tester.tap(find.byType(BookModel), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tapped, 0);

    await tester.pumpWidget(host(book(open: 0.9)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the book is one semantic button, not a pile of faces',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(book()));

    expect(
      find.bySemanticsLabel('Kokoro by Natsume Soseki. Tap to open the book.'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('both bindings paint at every size without complaint',
      (tester) async {
    for (final binding in BookBinding.values) {
      for (final size in const [Size(64, 90), Size(200, 260), Size(360, 200)]) {
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Theme(
                data: ThemeData(
                  colorScheme: PaperfoldTokens.colorScheme(Brightness.dark),
                ),
                child: Center(
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: book(binding: binding),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    }
  });
}
