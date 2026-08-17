import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/page/opening/opening_sequence.dart';

/// The cold-start opening belongs to the reader, not to a timer.
///
/// The thing these tests really guard is that no clock anywhere finishes the
/// sequence. It used to run itself out in 1.15 seconds and disappear, which is
/// a splash screen, and a splash screen is the one thing the opening of a book
/// must not be.
void main() {
  var finished = 0;

  Future<void> pumpOpening(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          // Built off the real one. A hand-made MediaQueryData reports no size,
          // and a scene measured against a screen of nothing is a scene of NaN.
          data: MediaQueryData.fromView(tester.view).copyWith(
            disableAnimations: reduceMotion,
          ),
          child: OpeningSequence(
            onFinished: () => finished++,
            child: const Scaffold(body: Center(child: Text('the library'))),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Taps, and lets one whole movement of [length] run out.
  ///
  /// Four pumps, not one. A ticker started inside a frame does not tick in that
  /// frame, and its first tick is where it takes its start time from, so a tap
  /// followed by a single pump of the duration reads zero. One frame past the
  /// end is what actually stops the ticker and completes its future, and the
  /// last pump is for the work that hangs off that future.
  ///
  /// `pumpAndSettle` is no use here: the mark that asks for the next tap
  /// breathes on a repeating controller, so this screen is never settled.
  Future<void> tapThrough(WidgetTester tester, Duration length) async {
    await tester.tap(find.byType(OpeningSequence));
    await tester.pump();
    await tester.pump();
    await tester.pump(length);
    await tester.pump(const Duration(milliseconds: 32));
    await tester.pump();
  }

  testWidgets('waits on the reader instead of running itself out',
      (tester) async {
    await pumpOpening(tester);
    await tester.pump(const Duration(seconds: 8));

    expect(
      finished,
      0,
      reason: 'the shut book opened itself with nobody touching it',
    );
  });

  testWidgets('one tap turns the cover, another goes through the page',
      (tester) async {
    await pumpOpening(tester);

    await tapThrough(tester, OpeningSequence.turnDuration);
    expect(finished, 0, reason: 'the cover turn finished the whole sequence');

    await tapThrough(tester, OpeningSequence.leaveDuration);
    expect(finished, 1);

    // And the reader is let through once, not once per movement that happens
    // to be running when they arrive.
    await tester.pump(const Duration(seconds: 2));
    expect(finished, 1);
  });

  testWidgets('a tap during a movement takes the reader to the end of it',
      (tester) async {
    await pumpOpening(tester);

    // Into the cover turn, then a tap partway through it. An impatient reader
    // must not be held by the very animation that was meant to be theirs.
    await tester.tap(find.byType(OpeningSequence));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byType(OpeningSequence));
    await tester.pump();
    expect(finished, 0, reason: 'the second tap ran two movements at once');

    await tapThrough(tester, OpeningSequence.leaveDuration);
    expect(finished, 1);
  });

  testWidgets('with animations off there is no book to open', (tester) async {
    await pumpOpening(tester, reduceMotion: true);
    await tester.pump();

    // Nothing to tap through: the reader asked for no motion, so the
    // application is simply there.
    expect(finished, 1);
    expect(find.text('the library'), findsOneWidget);
  });
}
