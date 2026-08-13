import 'package:flutter/material.dart';

class PaperfoldSurfacePalette {
  const PaperfoldSurfacePalette({
    required this.sageGreen,
    required this.dustyRose,
    required this.goldenTan,
    required this.warmBeige,
    required this.terracottaBrown,
  });

  final Color sageGreen;
  final Color dustyRose;
  final Color goldenTan;
  final Color warmBeige;
  final Color terracottaBrown;
}

class PaperfoldPagePalette {
  const PaperfoldPagePalette({
    required this.ground,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.surfaceLowest,
    required this.surfaceLow,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceHighest,
  });

  final Color ground;
  final Color ink;
  final Color inkSoft;
  final Color accent;
  final Color surfaceLowest;
  final Color surfaceLow;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceHighest;
}

class PaperfoldCoverPalette {
  const PaperfoldCoverPalette({
    required this.ground,
    required this.foil,
  });

  final Color ground;
  final Color foil;
}

/// The bookcase furniture. Separate from the page palette because the wood is
/// an object in the world, not a surface the interface sits on.
class PaperfoldWoodPalette {
  const PaperfoldWoodPalette({
    required this.board,
    required this.edge,
    required this.back,
    required this.onWood,
  });

  /// The face of a shelf board.
  final Color board;

  /// The front edge of a board, and the carcass uprights.
  final Color edge;

  /// The panel visible behind the books.
  final Color back;

  /// The only colour permitted for text drawn directly on [board].
  final Color onWood;
}

abstract final class PaperfoldTypeTokens {
  static const String journalFamily = 'Philosopher';
  static const String chromeFamily = 'SourceSans3';
}

abstract final class PaperfoldTokens {
  static const PaperfoldSurfacePalette surfaces = PaperfoldSurfacePalette(
    sageGreen: Color(0xFF98A086),
    dustyRose: Color(0xFFA76D5E),
    goldenTan: Color(0xFFC4A071),
    warmBeige: Color(0xFFDFCCB1),
    terracottaBrown: Color(0xFF846044),
  );

  static const PaperfoldPagePalette light = PaperfoldPagePalette(
    ground: Color(0xFFFAF6EE),
    ink: Color(0xFF3A2E28),
    inkSoft: Color(0xFF5C4A3F),
    accent: Color(0xFF846044),
    surfaceLowest: Color(0xFFFAF6EE),
    surfaceLow: Color(0xFFF3ECDF),
    surface: Color(0xFFEDE1D0),
    surfaceHigh: Color(0xFFE6D7C0),
    surfaceHighest: Color(0xFFDFCCB1),
  );

  // The warm brown "candlelight" ground was built, run on hardware and
  // rejected by the owner on 2026-08-12. plan.md Section 5.1 records the
  // decision. Both replacements are black; neither is brown.
  //
  // Black gives no tonal elevation for free, because Material's surface ramp
  // assumes a tinted ground. Both ramps below are therefore built upward in
  // near-neutral greys carrying only a faint warm cast.

  /// The default dark scheme. On an OLED phone these pixels are off, so true
  /// black is both the intended look and the lower-power one.
  static const PaperfoldPagePalette darkTrueBlack = PaperfoldPagePalette(
    ground: Color(0xFF000000),
    // 16.93:1 on the ground.
    ink: Color(0xFFEDE6DA),
    // 7.65:1 on the ground.
    inkSoft: Color(0xFFA39B90),
    // 8.61:1 on the ground.
    accent: Color(0xFFC4A071),
    surfaceLowest: Color(0xFF000000),
    surfaceLow: Color(0xFF050506),
    surface: Color(0xFF0C0C0E),
    surfaceHigh: Color(0xFF141417),
    surfaceHighest: Color(0xFF1C1C20),
  );

  /// The alternative for anyone who finds true black harsh. Neutral, not brown.
  static const PaperfoldPagePalette darkNearBlack = PaperfoldPagePalette(
    ground: Color(0xFF0E0E10),
    // 15.55:1 on the ground.
    ink: Color(0xFFEDE6DA),
    // 7.02:1 on the ground.
    inkSoft: Color(0xFFA39B90),
    // 7.91:1 on the ground.
    accent: Color(0xFFC4A071),
    surfaceLowest: Color(0xFF08080A),
    surfaceLow: Color(0xFF141417),
    surface: Color(0xFF1B1B1F),
    surfaceHigh: Color(0xFF232327),
    surfaceHighest: Color(0xFF2C2C31),
  );

  /// The default dark palette. Kept as a name so callers that do not care
  /// which variant is active keep reading the default one.
  static const PaperfoldPagePalette dark = darkTrueBlack;

  /// Walnut for the bookcase. In dark this is the only large warm field on
  /// screen: the books and shelves carry the colour, the chrome stays out of
  /// the way.
  ///
  /// The boards carry no text. Dark ink on walnut measures below 2:1, so if a
  /// label ever has to sit on wood it uses [PaperfoldWoodPalette.onWood].
  static const PaperfoldWoodPalette woodLight = PaperfoldWoodPalette(
    board: Color(0xFFB08A5E),
    edge: Color(0xFF8A6A45),
    back: Color(0xFF6B4F35),
    onWood: Color(0xFF2A1F14),
  );

  static const PaperfoldWoodPalette woodDark = PaperfoldWoodPalette(
    board: Color(0xFF6B4F35),
    edge: Color(0xFF5A4028),
    back: Color(0xFF3E2C1C),
    // 6.06:1 on the board.
    onWood: Color(0xFFEDE6DA),
  );

  // The saturated cover world stays separate from the quiet page palette.
  static const PaperfoldCoverPalette cover = PaperfoldCoverPalette(
    ground: Color(0xFF4A1528),
    foil: Color(0xFFE7C77B),
  );

  /// The page palette behind [brightness].
  ///
  /// [trueBlack] selects between the two dark variants and is ignored in
  /// light. It rides the existing `trueDarkMode` preference, whose default is
  /// on, so a new install gets [darkTrueBlack].
  static PaperfoldPagePalette pagePalette(
    Brightness brightness, {
    bool trueBlack = true,
  }) {
    if (brightness == Brightness.light) {
      return light;
    }
    return trueBlack ? darkTrueBlack : darkNearBlack;
  }

  /// The walnut behind [brightness].
  static PaperfoldWoodPalette wood(Brightness brightness) =>
      brightness == Brightness.light ? woodLight : woodDark;

  /// Returns the fixed Paperfold scheme for [brightness].
  ///
  /// Primary is the accent role in both themes. Widgets must not swap the
  /// terracotta and golden accents themselves.
  static ColorScheme colorScheme(
    Brightness brightness, {
    bool trueBlack = true,
  }) {
    final bool isLight = brightness == Brightness.light;
    final PaperfoldPagePalette page =
        pagePalette(brightness, trueBlack: trueBlack);
    final ColorScheme base =
        isLight ? const ColorScheme.light() : const ColorScheme.dark();
    final Color containerForeground = isLight ? light.ink : page.ground;
    final Color primaryContainer =
        isLight ? surfaces.warmBeige : surfaces.goldenTan;
    final Color tertiary = isLight ? surfaces.goldenTan : surfaces.warmBeige;

    return base.copyWith(
      primary: page.accent,
      onPrimary: page.ground,
      primaryContainer: primaryContainer,
      onPrimaryContainer: containerForeground,
      primaryFixed: page.accent,
      primaryFixedDim: page.accent,
      onPrimaryFixed: page.ground,
      onPrimaryFixedVariant: page.ground,
      secondary: surfaces.sageGreen,
      onSecondary: containerForeground,
      secondaryContainer: surfaces.sageGreen,
      onSecondaryContainer: containerForeground,
      secondaryFixed: surfaces.sageGreen,
      secondaryFixedDim: surfaces.sageGreen,
      onSecondaryFixed: containerForeground,
      onSecondaryFixedVariant: containerForeground,
      tertiary: tertiary,
      onTertiary: containerForeground,
      tertiaryContainer: tertiary,
      onTertiaryContainer: containerForeground,
      tertiaryFixed: tertiary,
      tertiaryFixedDim: tertiary,
      onTertiaryFixed: containerForeground,
      onTertiaryFixedVariant: containerForeground,
      surface: page.ground,
      onSurface: page.ink,
      surfaceDim: isLight ? surfaces.warmBeige : page.surfaceLowest,
      surfaceBright: isLight ? page.ground : page.surfaceHighest,
      surfaceContainerLowest: page.surfaceLowest,
      surfaceContainerLow: page.surfaceLow,
      surfaceContainer: page.surface,
      surfaceContainerHigh: page.surfaceHigh,
      surfaceContainerHighest: page.surfaceHighest,
      onSurfaceVariant: page.inkSoft,
      outline: page.inkSoft,
      outlineVariant: isLight ? surfaces.goldenTan : surfaces.dustyRose,
      inverseSurface: isLight ? page.ink : light.ground,
      onInverseSurface: isLight ? page.ground : light.ink,
      inversePrimary: isLight ? dark.accent : light.accent,
      surfaceTint: page.accent,
    );
  }
}
