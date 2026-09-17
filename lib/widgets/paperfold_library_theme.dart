import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';

/// The library is the burgundy cover; the rest of the app is its paper.
ThemeData paperfoldLibraryTheme(ThemeData base) {
  if (Prefs().eInkMode || !Prefs().useBrandTheme) return base;
  final scheme = PaperfoldTokens.colorScheme(
    Brightness.dark,
    trueBlack: false,
  ).copyWith(
    surface: PaperfoldTokens.cover.ground,
    surfaceContainerLowest: PaperfoldTokens.cover.ground,
    surfaceContainerLow: const Color(0xFF421D20),
    surfaceContainer: const Color(0xFF4B2729),
    surfaceContainerHigh: const Color(0xFF543033),
    surfaceContainerHighest: const Color(0xFF5D393B),
    primary: PaperfoldTokens.cover.foil,
    onPrimary: PaperfoldTokens.cover.ground,
    primaryContainer: PaperfoldTokens.cover.foil,
    onPrimaryContainer: PaperfoldTokens.cover.ground,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.primary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    dividerColor: scheme.primary.withValues(alpha: 0.25),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
    ),
  );
}
