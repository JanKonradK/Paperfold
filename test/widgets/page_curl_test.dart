import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/widgets/page_curl/page_curl.dart';

/// What a page turn is allowed to cost, and where it is allowed to end up.
///
/// Both of these are things that were wrong and are cheap to get wrong again.
/// A `setState` added to the wrong place in the curl is invisible on a desk and
/// costs the phone every frame of every turn; a threshold read before a
/// velocity turns a flick into a page springing back under the reader's hand.
void main() {
  /// A one-pixel image. The curl only ever samples these, never measures them.
  ///
  /// Made inside `runAsync` because it is engine work: awaited outside it,
  /// `toImage` does not fail, it simply never returns, and the test sits there
  /// until its own ten-minute timeout.
  Future<ui.Image> solid(WidgetTester tester, Color color) async {
    late ui.Image image;
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 1, 1),
        Paint()..color = color,
      );
      final picture = recorder.endRecording();
      image = await picture.toImage(1, 1);
      picture.dispose();
    });
    return image;
  }

  testWidgets('a turn in flight does not rebuild anything', (tester) async {
    final front = await solid(tester, const Color(0xFFFAF6EE));
    final back = await solid(tester, const Color(0xFF3A2E28));
    addTearDown(front.dispose);
    addTearDown(back.dispose);

    final controller = PageCurlController();
    // The decorator is called from the curl's own `build`, so counting it
    // counts rebuilds without reaching inside the widget for them.
    var builds = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PageCurl(
          frontImage: front,
          backImage: back,
          textDirection: TextDirection.ltr,
          controller: controller,
          interactive: false,
          decorator: (context, child, progress, phase) {
            builds++;
            return child;
          },
        ),
      ),
    );
    await tester.pump();
    final settledBuilds = builds;

    unawaited(
      controller.animate(
        duration: const Duration(milliseconds: 400),
        curve: Curves.linear,
      ),
    );

    // Twenty-four frames of a four-hundred-millisecond turn. Every one of them
    // used to be a rebuild.
    await tester.pump();
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      builds - settledBuilds,
      lessThan(6),
      reason: 'the curl rebuilt itself once per frame instead of repainting',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('a page thrown hard goes where it was thrown', (tester) async {
    final front = await solid(tester, const Color(0xFFFAF6EE));
    final back = await solid(tester, const Color(0xFF3A2E28));
    addTearDown(front.dispose);
    addTearDown(back.dispose);

    bool? completed;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PageCurl(
          frontImage: front,
          backImage: back,
          textDirection: TextDirection.ltr,
          onSettled: (value) => completed = value,
        ),
      ),
    );
    await tester.pump();

    // Let go of well before the halfway threshold, but travelling. A reader who
    // flicks a page expects the page to go, not to be told they did not drag
    // far enough.
    await tester.fling(
      find.byType(PageCurl),
      const Offset(-100, 0),
      1600,
    );
    await tester.pumpAndSettle();

    expect(
      completed,
      isTrue,
      reason: 'a flick short of the threshold sprang back',
    );
  });

  testWidgets('a page nudged and let go of goes back', (tester) async {
    final front = await solid(tester, const Color(0xFFFAF6EE));
    final back = await solid(tester, const Color(0xFF3A2E28));
    addTearDown(front.dispose);
    addTearDown(back.dispose);

    bool? completed;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PageCurl(
          frontImage: front,
          backImage: back,
          textDirection: TextDirection.ltr,
          onSettled: (value) => completed = value,
        ),
      ),
    );
    await tester.pump();

    // Slowly, and not far. Nothing about this says the reader wants the turn.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageCurl)) + const Offset(300, 0),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(-8, 0));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(completed, isFalse, reason: 'a nudge turned the page');
  });
}
