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
  static const String monogram = 'HJ';

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
    final double fontSize = side *
        (wordmark ? _fontSizeFactorWithWordmark : _fontSizeFactor);
    final TextPainter initials = _painter(
      PaperfoldLogoMark.monogram,
      fontSize: fontSize,
      weight: FontWeight.w700,
      // Two initials sit better apart than kerned together.
      tracking: fontSize * 0.06,
    );

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
    final double gap = name == null ? 0 : side * 0.045;
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
          child: PaperfoldLogoMark(
            size: size * markFactor,
            tint: tint,
            showWordmark: true,
          ),
        ),
      ),
    );
  }
}
