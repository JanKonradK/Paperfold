import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The page a book opens onto, drawn identically by the shelf and by the
/// reader.
///
/// There used to be three covering surfaces between a tap on a shelf and the
/// first line of text: the book's own cover magnified on the shelf, a sliding
/// route, and then a second full-screen cover inside the reader fading on a
/// six-hundred-millisecond timer that had nothing to do with whether the book
/// had loaded. The reader saw the same cover twice, a slide in between, and
/// then text appearing whenever it happened to be ready.
///
/// One surface now. The shelf raises it as the board swings, the reader is
/// already drawing the same thing underneath, and it lifts when the text is
/// genuinely there. Because both sides paint the same colours and the same
/// words, the handover from one route to the other cannot be seen.
class BookOpeningPage extends StatelessWidget {
  const BookOpeningPage({
    super.key,
    required this.title,
    required this.author,
    required this.turn,
    this.showMark = true,
  });

  final String title;
  final String author;

  /// Drives the mark. Null holds it still, which is what a reduced-motion
  /// setting asks for.
  final Animation<double>? turn;

  /// The mark is for waiting. The shelf raises the page before there is
  /// anything to wait for, so it brings the title up first and the mark after.
  final bool showMark;

  /// The paper by day and by night.
  ///
  /// The light pair is what the cold-start opening lands on, so a book opened
  /// from the shelf and a book opened by starting the application arrive in
  /// the same place. The dark pair exists because the shelf is true black:
  /// landing on cream at night is a flash in the face, and the reader is on
  /// its way into a night theme anyway.
  static const Color paper = Color(0xFFFAF6EE);
  static const Color ink = Color(0xFF3A2E28);
  static const Color paperDark = Color(0xFF121110);
  static const Color inkDark = Color(0xFFE8E0D2);

  static Color paperFor(Brightness brightness) =>
      brightness == Brightness.dark ? paperDark : paper;

  static Color inkFor(Brightness brightness) =>
      brightness == Brightness.dark ? inkDark : ink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final foreground = inkFor(brightness);

    return ColoredBox(
      color: paperFor(brightness),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The strip the mark lives in is reserved whether or not the mark
              // is in it, so the title does not move when the mark arrives.
              SizedBox(
                height: _WaitingMark.diameter,
                child: showMark
                    ? _WaitingMark(turn: turn, ink: foreground)
                    : null,
              ),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: foreground,
                ),
              ),
              if (author.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  author,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground.withValues(alpha: 0.66),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The mark that turns while the book is being got ready.
///
/// One fine arc travelling round a fainter ring. It used to be the wreath
/// ornament spun on its centre, which is the one thing an ornament must never
/// do: a drawn wreath has a top and a bottom, and rotating it reads as a
/// picture on a turntable rather than as work being done. A ring is the shape
/// that has no orientation to lose, so it is the shape that can turn.
///
/// The arc lengthens and shortens as it goes, which is what keeps a wait that
/// cannot report progress from looking like a wait that has stopped.
class _WaitingMark extends StatelessWidget {
  const _WaitingMark({required this.turn, required this.ink});

  final Animation<double>? turn;
  final Color ink;

  /// Small. A wait is not the subject of the screen; the book is.
  static const double diameter = 34;

  @override
  Widget build(BuildContext context) {
    final turning = turn;
    // Still when the system asks for no animation. A wait that cannot show
    // progress is better shown as a mark that simply sits there.
    final still = turning == null || MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: diameter,
      height: diameter,
      child: CustomPaint(
        painter: _WaitingMarkPainter(
          turn: still ? const AlwaysStoppedAnimation(0.0) : turning,
          ink: ink,
          sweeping: !still,
        ),
      ),
    );
  }
}

class _WaitingMarkPainter extends CustomPainter {
  _WaitingMarkPainter({
    required this.turn,
    required this.ink,
    required this.sweeping,
  }) : super(repaint: turn);

  final Animation<double> turn;
  final Color ink;
  final bool sweeping;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 1.6;
    if (radius <= 0) return;

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = ink.withValues(alpha: 0.16),
    );
    if (!sweeping) return;

    // The arc breathes twice for every turn, so the head and the tail never
    // travel at the same speed and the mark never looks like a still picture
    // being rotated.
    final t = turn.value % 1.0;
    final breath = (math.sin(t * math.pi * 4) + 1) / 2;
    final sweep = (0.16 + 0.42 * breath) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      t * 2 * math.pi * 1.6 - math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = ink.withValues(alpha: 0.82),
    );
  }

  @override
  bool shouldRepaint(covariant _WaitingMarkPainter oldDelegate) =>
      oldDelegate.ink != ink ||
      oldDelegate.sweeping != sweeping ||
      oldDelegate.turn != turn;
}
