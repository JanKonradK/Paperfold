import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/utils/color_scheme.dart';

/// The library is the burgundy cover; the rest of the app is its paper.
ThemeData paperfoldLibraryTheme(ThemeData base) {
  if (Prefs().eInkMode || !Prefs().useBrandTheme) return base;
  final scheme = PaperfoldTokens.colorScheme(
    Brightness.dark,
    trueBlack: false,
  ).copyWith(
    surface: PaperfoldTokens.cover.ground,
    surfaceDim: PaperfoldTokens.blackRaspberry,
    surfaceBright: PaperfoldTokens.spicedHotChocolate,
    surfaceContainerLowest: PaperfoldTokens.blackRaspberry,
    surfaceContainerLow: PaperfoldTokens.darkSienna,
    surfaceContainer: const Color(0xFF422629),
    surfaceContainerHigh: const Color(0xFF4A3431),
    surfaceContainerHighest: PaperfoldTokens.spicedHotChocolate,
    shadow: PaperfoldTokens.blackRaspberry,
    primary: PaperfoldTokens.cover.foil,
    onPrimary: PaperfoldTokens.cover.ground,
    primaryContainer: PaperfoldTokens.cover.foil,
    onPrimaryContainer: PaperfoldTokens.cover.ground,
  );
  final theme = paperfoldComponentTheme(ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
  ));
  return theme.copyWith(
    appBarTheme: theme.appBarTheme.copyWith(
      foregroundColor: scheme.primary,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    dividerColor: scheme.primary.withValues(alpha: 0.25),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
    ),
  );
}
