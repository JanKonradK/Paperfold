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
  // The five colours from the supplied palette.
  static const Color softDove = Color(0xFFC0BAB3);
  static const Color spicedHotChocolate = Color(0xFF52423D);
  static const Color moonRock = Color(0xFF887D77);
  static const Color darkSienna = Color(0xFF391214);
  static const Color blackRaspberry = Color(0xFF160F0C);

  // Keep the surface role names stable for book bindings and existing callers.
  static const PaperfoldSurfacePalette surfaces = PaperfoldSurfacePalette(
    sageGreen: moonRock,
    dustyRose: Color(0xFF8B625F),
    goldenTan: Color(0xFFB7A179),
    warmBeige: softDove,
    terracottaBrown: spicedHotChocolate,
  );

  static const PaperfoldPagePalette light = PaperfoldPagePalette(
    ground: Color(0xFFF6F2EA),
    ink: blackRaspberry,
    inkSoft: spicedHotChocolate,
    accent: darkSienna,
    surfaceLowest: Color(0xFFFCF9F3),
    surfaceLow: Color(0xFFF0EAE1),
    surface: Color(0xFFEAE3D9),
    surfaceHigh: Color(0xFFE3DBD0),
    surfaceHighest: Color(0xFFDBD1C5),
  );

  /// Preserve the explicit true-black option for OLED reading.
  static const PaperfoldPagePalette darkTrueBlack = PaperfoldPagePalette(
    ground: Color(0xFF000000),
    ink: Color(0xFFF6F2EA),
    inkSoft: softDove,
    accent: Color(0xFFB7A179),
    surfaceLowest: Color(0xFF000000),
    surfaceLow: Color(0xFF0C0908),
    surface: Color(0xFF17110F),
    surfaceHigh: Color(0xFF211916),
    surfaceHighest: Color(0xFF2D231F),
  );

  /// Raspberry-black paper, with a warm tonal ramp for sheets and controls.
  static const PaperfoldPagePalette darkNearBlack = PaperfoldPagePalette(
    ground: blackRaspberry,
    ink: Color(0xFFF6F2EA),
    inkSoft: softDove,
    accent: Color(0xFFB7A179),
    surfaceLowest: Color(0xFF100B09),
    surfaceLow: Color(0xFF211714),
    surface: Color(0xFF2B201C),
    surfaceHigh: Color(0xFF372924),
    surfaceHighest: Color(0xFF44332D),
  );

  /// The default dark palette. Kept as a name so callers that do not care
  /// which variant is active keep reading the default one.
  static const PaperfoldPagePalette dark = darkTrueBlack;

  /// Smoked wood and stone tones keep the books distinct from the furniture.
  static const PaperfoldWoodPalette woodLight = PaperfoldWoodPalette(
    board: Color(0xFFA99B8C),
    edge: moonRock,
    back: spicedHotChocolate,
    onWood: blackRaspberry,
  );

  static const PaperfoldWoodPalette woodDark = PaperfoldWoodPalette(
    board: spicedHotChocolate,
    edge: Color(0xFF3F302C),
    back: Color(0xFF2A1D1A),
    onWood: Color(0xFFF6F2EA),
  );

  // Match the supplied cover image; Dark Sienna is its raised surface.
  static const PaperfoldCoverPalette cover = PaperfoldCoverPalette(
    ground: Color(0xFF350D18),
    foil: Color(0xFFB7A179),
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
  /// Primary is burgundy on paper and aged gold on dark surfaces.
  static ColorScheme colorScheme(
    Brightness brightness, {
    bool trueBlack = true,
  }) {
    final bool isLight = brightness == Brightness.light;
    final PaperfoldPagePalette page =
        pagePalette(brightness, trueBlack: trueBlack);
    final ColorScheme base =
        isLight ? const ColorScheme.light() : const ColorScheme.dark();
    final Color primaryContainer =
        isLight ? const Color(0xFFE8DCD5) : surfaces.goldenTan;
    final Color secondary = isLight ? light.inkSoft : surfaces.warmBeige;
    final Color tertiary =
        isLight ? const Color(0xFF695937) : surfaces.goldenTan;
    final Color onAccent = isLight ? light.ground : light.ink;

    return base.copyWith(
      primary: page.accent,
      onPrimary: onAccent,
      primaryContainer: primaryContainer,
      onPrimaryContainer: light.ink,
      primaryFixed: surfaces.warmBeige,
      primaryFixedDim: surfaces.goldenTan,
      onPrimaryFixed: light.ink,
      onPrimaryFixedVariant: cover.ground,
      secondary: secondary,
      onSecondary: onAccent,
      secondaryContainer: surfaces.warmBeige,
      onSecondaryContainer: light.ink,
      secondaryFixed: surfaces.warmBeige,
      secondaryFixedDim: surfaces.goldenTan,
      onSecondaryFixed: light.ink,
      onSecondaryFixedVariant: cover.ground,
      tertiary: tertiary,
      onTertiary: onAccent,
      tertiaryContainer: surfaces.goldenTan,
      onTertiaryContainer: light.ink,
      tertiaryFixed: surfaces.goldenTan,
      tertiaryFixedDim: surfaces.goldenTan,
      onTertiaryFixed: light.ink,
      onTertiaryFixedVariant: cover.ground,
      surface: page.ground,
      onSurface: page.ink,
      surfaceDim: isLight ? page.surfaceHighest : page.surfaceLowest,
      surfaceBright: isLight ? page.ground : page.surfaceHighest,
      surfaceContainerLowest: page.surfaceLowest,
      surfaceContainerLow: page.surfaceLow,
      surfaceContainer: page.surface,
      surfaceContainerHigh: page.surfaceHigh,
      surfaceContainerHighest: page.surfaceHighest,
      onSurfaceVariant: page.inkSoft,
      outline: surfaces.sageGreen,
      outlineVariant: isLight ? surfaces.warmBeige : surfaces.terracottaBrown,
      inverseSurface: isLight ? page.ink : light.ground,
      onInverseSurface: isLight ? page.ground : light.ink,
      inversePrimary: isLight ? dark.accent : light.accent,
      surfaceTint: Colors.transparent,
    );
  }
}
