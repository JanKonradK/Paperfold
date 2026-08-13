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
  });

  /// The letter inside the wreath. Paperfold, so `P`.
  static const String monogram = 'P';

  /// The side of the square the mark draws into.
  final double size;

  /// The single colour of the wreath and the letter. Defaults to the accent.
  final Color? tint;

  /// Null keeps the mark decorative, which is right when a label sits beside
  /// it. Pass a label when the mark is the only content of a control.
  final String? semanticLabel;

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
            painter: _MonogramPainter(color: resolvedTint, side: size),
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
  const _MonogramPainter({required this.color, required this.side});

  /// The inner wreath circle has radius 58 of a 240 viewBox, so the letter has
  /// 48% of the side to sit in. A cap of 25% of the side leaves a clear ring.
  static const double _fontSizeFactor = 0.36;

  /// Philosopher's caps measure close to 0.70 em. The value only has to place
  /// the letter, not to describe the font, so a constant is enough.
  static const double _capHeightEm = 0.70;

  final Color color;
  final double side;

  @override
  void paint(Canvas canvas, Size size) {
    final double fontSize = side * _fontSizeFactor;
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: PaperfoldLogoMark.monogram,
        style: TextStyle(
          color: color,
          fontFamily: PaperfoldTypeTokens.journalFamily,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      // The monogram is a shape, not language. It never mirrors.
      textAlign: TextAlign.center,
    )..layout();

    final double baseline =
        painter.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final double capCentre = baseline - fontSize * _capHeightEm / 2;
    final Offset origin = Offset(
      (size.width - painter.width) / 2,
      size.height / 2 - capCentre,
    );

    painter.paint(canvas, origin);
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _MonogramPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.side != side;
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

  /// The mark fills most of the card, the way a foil stamp fills a cover.
  static const double _cardMarkFactor = 0.72;

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

    return SizedBox.square(
      dimension: size,
      child: ColoredBox(
        color: isCard ? PaperfoldTokens.cover.ground : const Color(0x00000000),
        child: Center(
          child: PaperfoldLogoMark(size: size * markFactor, tint: tint),
        ),
      ),
    );
  }
}
