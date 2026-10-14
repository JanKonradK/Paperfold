import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PaperfoldOrnament {
  ovalFloralFrame,
  rectangularVineFrame,
  cornerSpray,
  circularWreath,
  bowAndRibbon,
  iconWreath,
  pottedPlant,
  bookend,
  smallUrn,
  teacup,
  candle,
  classicalBust,
}

extension on PaperfoldOrnament {
  String get assetPath => switch (this) {
        PaperfoldOrnament.ovalFloralFrame =>
          'assets/ornaments/oval_floral_frame.svg',
        PaperfoldOrnament.rectangularVineFrame =>
          'assets/ornaments/rectangular_vine_frame.svg',
        PaperfoldOrnament.cornerSpray => 'assets/ornaments/corner_spray.svg',
        PaperfoldOrnament.circularWreath =>
          'assets/ornaments/circular_wreath.svg',
        PaperfoldOrnament.bowAndRibbon => 'assets/ornaments/bow_and_ribbon.svg',
        PaperfoldOrnament.iconWreath => 'assets/ornaments/icon_wreath.svg',
        PaperfoldOrnament.pottedPlant => 'assets/ornaments/potted_plant.svg',
        PaperfoldOrnament.bookend => 'assets/ornaments/bookend.svg',
        PaperfoldOrnament.smallUrn => 'assets/ornaments/small_urn.svg',
        PaperfoldOrnament.teacup => 'assets/ornaments/teacup.svg',
        PaperfoldOrnament.candle => 'assets/ornaments/candle.svg',
        PaperfoldOrnament.classicalBust =>
          'assets/ornaments/classical_bust.svg',
      };
}

class Ornament extends StatelessWidget {
  const Ornament({
    super.key,
    required this.ornament,
    this.tint,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final PaperfoldOrnament ornament;
  final Color? tint;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Color resolvedTint = tint ?? Theme.of(context).colorScheme.primary;

    return SvgPicture.asset(
      ornament.assetPath,
      width: width,
      height: height,
      fit: fit,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
      colorFilter: ColorFilter.mode(resolvedTint, BlendMode.srcIn),
    );
  }
}
