import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paperfold/enums/shelf_material.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';

/// The shelf the books stand on.
///
/// The bookcase used to be the loudest object on the screen: a walnut carcass
/// with uprights, a grained back panel and a thick board, filling every bay
/// with brown. It buried the books it was meant to hold, and it made the whole
/// application read as antique when only the books were supposed to.
///
/// What is there now is a floating plank, and almost nothing else: a deck
/// receding toward the wall at the same angle the books are seen from, a front
/// edge with the material's own character in it, two small brackets underneath,
/// and the shadow the whole thing drops. No carcass, no uprights, no back
/// panel.
///
/// The material is the reader's choice - see [ShelfMaterial] - and changing it
/// changes only what the plank is made of. Every measurement below is shared by
/// all of them, so a book stands in exactly the same place whichever is picked.
///
/// Solid colour and linear gradients only, no blur or image, and
/// [shouldRepaint] is false unless something it draws with changes.
class GlassShelfPainter extends CustomPainter {
  GlassShelfPainter({
    required this.palette,
    required this.shadow,
  });

  final ShelfMaterialPalette palette;
  final Color shadow;

  /// The height the plank occupies at the foot of a shelf stage. The stage pads
  /// its books by the same amount, so the books stand on the deck rather than
  /// floating above it or sinking through it.
  static const double plateInset = 14;

  /// The deck: the top surface, receding toward the wall at the same angle the
  /// books are seen from, so a book and the shelf it stands on agree.
  static const double deckDepth = BookSpine.topFaceDepth;

  /// The front edge. The only part of the plank with any thickness on screen,
  /// and therefore the part that has to carry the material.
  static const double edgeThickness = 5;

  /// The brackets under the plank. Small, and inset from the ends, the way a
  /// real floating shelf is hung.
  static const double bracketWidth = 26;
  static const double bracketDepth = 7;
  static const double bracketInset = 0.18;

  @override
  void paint(Canvas canvas, Size size) {
    final deckTop = size.height - plateInset;
    if (deckTop <= 0) return;
    if (palette.opacity <= 0) {
      _paintContact(canvas, size, deckTop);
      return;
    }

    _paintContact(canvas, size, deckTop);
    _paintDeck(canvas, size, deckTop);
    _paintBrackets(canvas, size, deckTop);
    _paintFrontEdge(canvas, size, deckTop);
  }

  /// The books darken the shelf where they touch it. This band is what makes
  /// them stand on it rather than in front of it.
  void _paintContact(Canvas canvas, Size size, double deckTop) {
    const height = 20.0;
    final contact = Rect.fromLTWH(
      0,
      math.max(0, deckTop - height),
      size.width,
      math.min(height, deckTop),
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
  }

  /// The top surface, running back toward the wall.
  ///
  /// It is drawn from the far edge forward, darker at the back, which is what
  /// gives a flat band the read of a surface going away rather than a stripe.
  void _paintDeck(Canvas canvas, Size size, double deckTop) {
    final deck = Rect.fromLTWH(0, deckTop - deckDepth, size.width, deckDepth);
    canvas.drawRect(
      deck,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.deckFar, palette.deck],
        ).createShader(deck),
    );

    if (palette.grain) {
      final grain = Paint()
        ..color = palette.edgeShade.withValues(alpha: 0.16)
        ..strokeWidth = 0.8;
      for (var x = 12.0; x < size.width; x += 37) {
        canvas.drawLine(
          Offset(x, deckTop - deckDepth + 2),
          Offset(x + 18, deckTop - 1),
          grain,
        );
      }
    }
  }

  /// Two small brackets, holding the plank off the wall.
  ///
  /// They are the reason a floating shelf reads as mounted rather than as a
  /// line drawn across the screen, and they are the only part of the reference
  /// the books do not already supply.
  void _paintBrackets(Canvas canvas, Size size, double deckTop) {
    final y = deckTop + edgeThickness;
    for (final fraction in [bracketInset, 1 - bracketInset]) {
      final centre = size.width * fraction;
      final bracket = Rect.fromLTWH(
        centre - bracketWidth / 2,
        y,
        bracketWidth,
        bracketDepth,
      );
      canvas.drawRect(
        bracket,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.edgeBody,
              palette.edgeShade,
            ],
          ).createShader(bracket),
      );
      // The light that catches the top of the bracket where it meets the
      // underside of the plank.
      canvas.drawLine(
        Offset(bracket.left, y),
        Offset(bracket.right, y),
        Paint()
          ..color = palette.edgeLight.withValues(alpha: 0.5)
          ..strokeWidth = 1,
      );
    }
  }

  /// The front edge, and the shadow under it.
  void _paintFrontEdge(Canvas canvas, Size size, double deckTop) {
    final edge = Rect.fromLTWH(0, deckTop, size.width, edgeThickness);
    canvas.drawRect(
      edge,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.edgeLight,
            palette.edgeBody,
            palette.edgeShade,
          ],
          stops: const [0, 0.42, 1],
        ).createShader(edge),
    );

    // Under the plank. A floating shelf casts onto the wall below it, and
    // without this the plank sits on the page instead of in front of it.
    final under = Rect.fromLTWH(
      0,
      deckTop + edgeThickness,
      size.width,
      plateInset - edgeThickness,
    );
    canvas.drawRect(
      under,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.underside, palette.underside.withValues(alpha: 0)],
        ).createShader(under),
    );
  }

  @override
  bool shouldRepaint(covariant GlassShelfPainter oldDelegate) {
    return palette != oldDelegate.palette || shadow != oldDelegate.shadow;
  }
}

/// A shelf plank with [child] standing on it.
///
/// Wraps [GlassShelfPainter] so a caller does not have to know which colour
/// roles the shelf is made of, and so the shelf can be drawn somewhere other
/// than the home screen - a preview, a test - without copying that out.
class GlassShelf extends StatelessWidget {
  const GlassShelf({
    super.key,
    required this.child,
    this.material = ShelfMaterial.glass,
  });

  final Widget child;
  final ShelfMaterial material;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: GlassShelfPainter(
        palette: ShelfMaterialPalette.of(material, scheme),
        shadow: scheme.shadow,
      ),
      child: child,
    );
  }
}
