import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// A loading page that follows the active theme until the book is ready.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface;

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // The strip the mark lives in is reserved whether or not the mark
              // is in it, so the title does not move when the mark arrives.
              SizedBox(
                height: _WaitingMark.diameter,
                child:
                    showMark ? _WaitingMark(turn: turn, ink: foreground) : null,
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
