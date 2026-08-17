import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/ornament.dart';

/// The Paperfold mark: the wreath ornament with a monogram inside it.
///
/// Section 5.4 of the plan describes the icon as a card, a wreath and a
/// monogram. The wreath is the owner's own artwork and it already ships as a
/// tintable SVG, so the mark is a composition of existing parts rather than a
/// new flat image. One tint, like every other ornament.
class PaperfoldLogoMark extends StatelessWidget {
  const PaperfoldLogoMark({
    super.key,
    required this.size,
    this.tint,
    this.semanticLabel,
    this.showWordmark = false,
  });

  /// The two initials inside the wreath.
  ///
  /// Set apart, not kerned into one another. `HJ` read as a single made-up
  /// word; two letters joined by a rule read as two initials, which is what a
  /// monogram is.
  static const String monogram = 'H + J';

  /// The name under the initials, on the shapes large enough to read it.
  static const String wordmark = 'Paperfold';

  /// The side of the square the mark draws into.
  final double size;

  /// The single colour of the wreath and the letters. Defaults to the accent.
  final Color? tint;

  /// Null keeps the mark decorative, which is right when a label sits beside
  /// it. Pass a label when the mark is the only content of a control.
  final String? semanticLabel;

  /// Draws [wordmark] under the initials.
  ///
  /// Off by default. At the sizes the mark takes inside the application, a
  /// nine-letter word inside the inner ring is a smudge, not a name. The
  /// application icon and the settings header turn it on.
  final bool showWordmark;

  /// Below this the wordmark cannot be read, whatever the caller asks for.
  ///
  /// The word sits inside the wreath's inner circle and measures under six
  /// percent of the mark, so at 160 dp the name is about 9 dp tall. Smaller
  /// than that it is a smear, and a smear is worse than no name.
  static const double minimumWordmarkSize = 160;

  @override
  Widget build(BuildContext context) {
    final Color resolvedTint = tint ?? Theme.of(context).colorScheme.primary;

    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Ornament(
            ornament: PaperfoldOrnament.iconWreath,
            width: size,
            height: size,
            tint: resolvedTint,
          ),
          CustomPaint(
            size: Size.square(size),
            painter: _MonogramPainter(
              color: resolvedTint,
              side: size,
              wordmark: showWordmark && size >= minimumWordmarkSize,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints the monogram centred on its cap height.
///
/// A [Text] centres on the line box, and the line box carries the descender
/// space of a letter that has no descender. Inside a wreath at icon size that
/// error is plainly visible, so the letter is painted against its baseline.
class _MonogramPainter extends CustomPainter {
  const _MonogramPainter({
    required this.color,
    required this.side,
    required this.wordmark,
  });

  /// The inner wreath circle has radius 58 of a 240 viewBox, so the letters
  /// have 48% of the side to sit in. Two caps need less height than one, or
  /// the pair runs into the ring on both sides.
  static const double _fontSizeFactor = 0.30;

  /// With the name under them the initials give up a little more height.
  static const double _fontSizeFactorWithWordmark = 0.25;

  /// Philosopher's caps measure close to 0.70 em. The value only has to place
  /// the letters, not to describe the font, so a constant is enough.
  static const double _capHeightEm = 0.70;

  /// How much of the side the letters may take across, inside the inner ring.
  ///
  /// The ring itself is 0.48 of the side. This leaves a little air between the
  /// last letter and the rule, which is what stops the monogram reading as a
  /// word wedged into a circle.
  static const double _innerRoom = 0.40;

  /// The name reads at about a fifth of the initials.
  static const double _wordmarkFactor = 0.058;

  /// Letterspacing is what stops a small word under a monogram from reading as
  /// one dark smear.
  static const double _wordmarkTracking = 0.10;

  final Color color;
  final double side;
  final bool wordmark;

  @override
  void paint(Canvas canvas, Size size) {
    var fontSize = side *
        (wordmark ? _fontSizeFactorWithWordmark : _fontSizeFactor);
    TextPainter initials = _painter(
      PaperfoldLogoMark.monogram,
      fontSize: fontSize,
      weight: FontWeight.w700,
      // Two initials sit better apart than kerned together.
      tracking: fontSize * 0.06,
    );

    // The wreath's inner circle is 48 per cent of the side, so the letters
    // have to fit inside that however many of them there are. Measured and
    // brought back rather than guessed at: the monogram is a constant one line
    // away from being changed, and a factor tuned to two glyphs runs a
    // three-glyph monogram straight through the ring.
    final double room = side * _innerRoom;
    if (initials.width > room) {
      fontSize *= room / initials.width;
      initials.dispose();
      initials = _painter(
        PaperfoldLogoMark.monogram,
        fontSize: fontSize,
        weight: FontWeight.w700,
        tracking: fontSize * 0.06,
      );
    }

    final double baseline =
        initials.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final double capHeight = fontSize * _capHeightEm;

    // With a name underneath, the pair of them centres as one block, not the
    // initials alone with the name hanging off the bottom.
    final TextPainter? name = wordmark
        ? _painter(
            PaperfoldLogoMark.wordmark,
            fontSize: side * _wordmarkFactor,
            weight: FontWeight.w600,
            tracking: side * _wordmarkFactor * _wordmarkTracking,
            family: PaperfoldTypeTokens.chromeFamily,
          )
        : null;
    final double gap = name == null ? 0 : side * 0.075;
    final double blockHeight =
        capHeight + gap + (name?.height ?? 0);
    final double blockTop = (size.height - blockHeight) / 2;

    initials.paint(
      canvas,
      Offset(
        (size.width - initials.width) / 2,
        // The glyphs start at the block top, so the baseline goes a cap below.
        blockTop + capHeight - baseline,
      ),
    );
    name?.paint(
      canvas,
      Offset(
        (size.width - name.width) / 2,
        blockTop + capHeight + gap,
      ),
    );

    initials.dispose();
    name?.dispose();
  }

  TextPainter _painter(
    String text, {
    required double fontSize,
    required FontWeight weight,
    required double tracking,
    String family = PaperfoldTypeTokens.journalFamily,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: family,
          fontWeight: weight,
          fontSize: fontSize,
          letterSpacing: tracking,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      // A monogram is a shape, not language. It never mirrors.
      textAlign: TextAlign.center,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant _MonogramPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.side != side ||
      oldDelegate.wordmark != wordmark;
}

/// How an exported application icon fills its canvas.
enum PaperfoldAppIconShape {
  /// A full-bleed burgundy card with the gold mark on it. The legacy launcher
  /// icon, and the master image every other platform is cut from.
  card,

  /// Transparent, and the mark at full bleed. The Android adaptive foreground,
  /// which the launcher masks and moves after the packager insets it.
  adaptiveForeground,

  /// Transparent, and the mark in one flat colour. The Android 13 themed icon,
  /// which the launcher recolours itself.
  monochrome,
}

/// The application icon, drawn rather than stored as flat artwork.
///
/// `tool/generate_app_icons.dart` renders this widget to the master PNG files.
/// Keeping the icon as a widget means the wreath, the letter and the cover
/// colours stay the single set the rest of the application already reads.
class PaperfoldAppIcon extends StatelessWidget {
  const PaperfoldAppIcon({
    super.key,
    required this.size,
    this.shape = PaperfoldAppIconShape.card,
  });

  /// How much of the card the mark fills.
  ///
  /// Larger than it was, because there is no longer a frame for it to sit
  /// inside. The card used to carry a double foil rule round the trim and the
  /// application's name under the initials, and at 48 px — which is the size a
  /// launcher actually draws it — the rule, the wreath, the letters and the
  /// nine-letter word all collapsed into one gold blur. One mark, drawn large.
  static const double _cardMarkFactor = 0.74;

  /// An adaptive foreground fills its master file. flutter_launcher_icons
  /// insets the drawable by 16% on every side, which is what holds the art
  /// inside the Android safe zone, so insetting here as well would shrink the
  /// mark twice and leave it swimming in its own icon.
  static const double _bleedMarkFactor = 1;

  final double size;
  final PaperfoldAppIconShape shape;

  @override
  Widget build(BuildContext context) {
    final bool isCard = shape == PaperfoldAppIconShape.card;
    final Color tint = switch (shape) {
      PaperfoldAppIconShape.card ||
      PaperfoldAppIconShape.adaptiveForeground =>
        PaperfoldTokens.cover.foil,
      // The launcher paints the themed icon itself. White keeps every pixel
      // of the shape, whatever colour it ends up.
      PaperfoldAppIconShape.monochrome => const Color(0xFFFFFFFF),
    };
    final double markFactor = isCard ? _cardMarkFactor : _bleedMarkFactor;

    final Widget mark = Center(
      child: PaperfoldLogoMark(
        size: size * markFactor,
        tint: tint,
        // No name on the icon. The launcher already prints it underneath.
        showWordmark: false,
      ),
    );

    if (!isCard) {
      // The two transparent shapes carry the mark and nothing else. The
      // launcher supplies their ground and masks their outline, so a painted
      // cover and a rectangular frame would only be clipped into rubbish.
      return SizedBox.square(dimension: size, child: mark);
    }

    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _CoverPainter(side: size),
        child: mark,
      ),
    );
  }
}

/// The card ground: bookcloth, and nothing stamped on it but the mark.
///
/// A flat fill made the icon read as a coloured square with a logo dropped on
/// it. DESIGN.md's north star is a bound book — cloth catching light — so the
/// ground is painted rather than filled.
///
/// The double foil rule that used to run round the trim has gone. It was
/// correct for a cover and wrong for an icon: a launcher draws this at 48 px
/// inside a mask of its own, where a frame a few pixels inside another frame
/// is one more ring of gold competing with the wreath. What is left is cloth
/// and one mark.
class _CoverPainter extends CustomPainter {
  const _CoverPainter({required this.side});

  final double side;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Color ground = PaperfoldTokens.cover.ground;
    final Color foil = PaperfoldTokens.cover.foil;

    // Cloth. The light falls from above the left shoulder, the same direction
    // the book model lights its boards, so the two objects agree.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.36, size.height * 0.30),
          size.width * 0.92,
          <Color>[
            Color.lerp(ground, const Color(0xFF7A2340), 0.34)!,
            ground,
            Color.lerp(ground, const Color(0xFF12060B), 0.45)!,
          ],
          <double>[0.0, 0.55, 1.0],
        ),
    );

    // The weave. Far too faint to see as lines at icon size; it stops the
    // gradient from looking like a smooth digital blur.
    final Paint weave = Paint()
      ..color = foil.withValues(alpha: 0.016)
      ..strokeWidth = side * 0.0018;
    for (double y = 0; y < size.height; y += side * 0.014) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), weave);
    }
  }

  @override
  bool shouldRepaint(covariant _CoverPainter oldDelegate) =>
      oldDelegate.side != side;
}
