import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';

/// The shelf the books stand on.
///
/// The bookcase used to be the loudest object on the screen: a walnut carcass
/// with uprights, a grained back panel and a thick board, filling every bay
/// with brown. It buried the books it was meant to hold, and it made the whole
/// application read as antique when only the books were supposed to.
///
/// What is left is a single sheet of glass. It is almost nothing: a lit front
/// edge, a faint body, and the shadow the books drop onto it. The page ground
/// shows through, the books supply every colour on the screen, and the
/// furniture stops competing with them.
///
/// Solid colour and linear gradients only, no blur or image, and
/// [shouldRepaint] is false unless the palette changes.
class GlassShelfPainter extends CustomPainter {
  GlassShelfPainter({
    required this.sheen,
    required this.edge,
    required this.shadow,
  });

  final Color sheen;
  final Color edge;
  final Color shadow;

  /// The height the glass occupies at the foot of a shelf stage. The stage
  /// pads its books by the same amount, so the books stand on the plate rather
  /// than floating above it or sinking through it.
  static const double plateInset = 14;
  static const double plateThickness = 9;
  static const double contactHeight = 20;

  /// The top face of the glass, receding under the books at the same angle
  /// they are seen from.
  static const double deckDepth = BookSpine.topFaceDepth;

  /// The metal band along the front edge.
  static const double nosingThickness = 4;

  /// The nosing is the one thing on this shelf that does not take its colour
  /// from the scheme.
  ///
  /// Every other part of the glass is `onSurface` at a low alpha, which is
  /// correct for a tint - it goes light on a black ground and dark on a paper
  /// one. Metal does not work that way. Built from `onSurface` the nosing came
  /// out as a dark smear in the light theme and vanished, because dark-on-light
  /// is not what a lit metal edge looks like. These are warm greys, tuned to
  /// sit in the paper palette rather than against it, and they read as the same
  /// object in both themes.
  static const Color _metalShade = Color(0xFF33302B);
  static const Color _metalBody = Color(0xFF8B8279);
  static const Color _metalLight = Color(0xFFE9E1D5);

  @override
  void paint(Canvas canvas, Size size) {
    final plateTop = size.height - plateInset;
    if (plateTop <= 0) return;

    // The books darken the glass where they touch it. This band is what makes
    // them stand on the shelf rather than in front of it.
    final contact = Rect.fromLTWH(
      0,
      math.max(0, plateTop - contactHeight),
      size.width,
      math.min(contactHeight, plateTop),
    );
    canvas.drawRect(
      contact,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            shadow.withValues(alpha: 0),
            shadow.withValues(alpha: 0.34),
          ],
        ).createShader(contact),
    );

    // The plate itself: bright where the light catches its top face, fading
    // through the thickness of the glass.
    final plate = Rect.fromLTWH(0, plateTop, size.width, plateThickness);
    canvas.drawRect(
      plate,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            sheen.withValues(alpha: 0.16),
            sheen.withValues(alpha: 0.04),
          ],
        ).createShader(plate),
    );

    // The top face of the glass, receding under the books at the same angle
    // they are seen from. Without it the plate is a line and the books stand
    // on nothing; with it there is a surface for them to stand on.
    final deck = Rect.fromLTWH(0, plateTop - deckDepth, size.width, deckDepth);
    canvas.drawRect(
      deck,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            sheen.withValues(alpha: 0.03),
            sheen.withValues(alpha: 0.11),
          ],
        ).createShader(deck),
    );

    // Two hairlines carry the whole illusion: the lit top face, and the ground
    // edge underneath it.
    canvas.drawLine(
      Offset(0, plateTop),
      Offset(size.width, plateTop),
      Paint()
        ..color = sheen.withValues(alpha: 0.58)
        ..strokeWidth = 1,
    );

    // The metal nosing along the front edge of the glass.
    //
    // This is the only metal on the shelf and it stays a band rather than
    // becoming a rail: `f7e86aa3` took the furniture out because a walnut
    // carcass buried the books, and a bright bracket at every bay would repeat
    // that mistake in a different material. What makes it read as metal rather
    // than as another sheet of glass is the anisotropy - a hard bright line
    // near the top of the band and a quick fall to a dark underside, instead of
    // glass's even gradient.
    final nosing = Rect.fromLTWH(
      0,
      plateTop + plateThickness - nosingThickness,
      size.width,
      nosingThickness,
    );
    canvas.drawRect(
      nosing,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // Opaque, and anisotropic: a hard bright line high on the band and a
          // quick fall to a dark underside. Glass fades evenly; metal does not,
          // and that difference is the whole of what tells them apart at 4 dp.
          colors: [
            _metalShade,
            _metalLight,
            _metalBody,
            _metalShade,
          ],
          stops: [0, 0.28, 0.55, 1],
        ).createShader(nosing),
    );
    canvas.drawLine(
      Offset(0, plateTop + plateThickness),
      Offset(size.width, plateTop + plateThickness),
      Paint()
        ..color = edge.withValues(alpha: 0.42)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant GlassShelfPainter oldDelegate) {
    return sheen != oldDelegate.sheen ||
        edge != oldDelegate.edge ||
        shadow != oldDelegate.shadow;
  }
}

/// A sheet of shelf glass with [child] standing on it.
///
/// Wraps [GlassShelfPainter] so a caller does not have to know which colour
/// roles the glass is made of, and so the shelf can be drawn somewhere other
/// than the home screen - a preview, a test - without copying that out.
class GlassShelf extends StatelessWidget {
  const GlassShelf({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: GlassShelfPainter(
        sheen: scheme.onSurface,
        edge: scheme.outlineVariant,
        shadow: scheme.shadow,
      ),
      child: child,
    );
  }
}
