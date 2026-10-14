import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/utils/color_scheme.dart';

/// Burgundy is an explicit app theme. Cream, System, and Dark keep their own
/// surfaces on every route; the reader's saved page theme stays independent.
ThemeData paperfoldLibraryTheme(ThemeData base) {
  if (Prefs().eInkMode ||
      !Prefs().useBrandTheme ||
      Prefs().appThemeMode != 'burgundy' ||
      base.brightness == Brightness.dark) {
    return base;
  }
  final scheme = PaperfoldTokens.burgundyColorScheme();
  final theme = paperfoldComponentTheme(
    ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
    ),
  );
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
