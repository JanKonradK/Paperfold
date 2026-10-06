import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

TextStyle? _journalStyle(TextStyle? style) {
  return style?.copyWith(
    fontFamily: PaperfoldTypeTokens.journalFamily,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: 0,
  );
}

TextTheme _paperfoldTextTheme(TextTheme base) {
  final chrome = base.apply(fontFamily: PaperfoldTypeTokens.chromeFamily);
  return chrome.copyWith(
    displayLarge: _journalStyle(base.displayLarge),
    displayMedium: _journalStyle(base.displayMedium),
    displaySmall: _journalStyle(base.displaySmall),
    headlineLarge: _journalStyle(base.headlineLarge),
    headlineMedium: _journalStyle(base.headlineMedium),
    headlineSmall: _journalStyle(base.headlineSmall),
    titleLarge: _journalStyle(base.titleLarge),
    titleMedium: chrome.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    titleSmall: chrome.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    bodyLarge: chrome.bodyLarge?.copyWith(height: 1.5, letterSpacing: 0),
    bodyMedium: chrome.bodyMedium?.copyWith(height: 1.45, letterSpacing: 0),
    bodySmall: chrome.bodySmall?.copyWith(height: 1.4, letterSpacing: 0),
    labelLarge: chrome.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: chrome.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelSmall: chrome.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
  );
}

ThemeData colorSchema(
  Prefs prefsNotifier,
  BuildContext context,
  Brightness brightness,
) {
  brightness = prefsNotifier.eInkMode
      ? Brightness.light
      : switch (prefsNotifier.themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };
  final Color seedColor = prefsNotifier.themeColor;
  final isDark = brightness == Brightness.dark;
  final isEinkMode = prefsNotifier.eInkMode;
  final hasCustomSeed = !prefsNotifier.useBrandTheme;

  final lightGropedBackground =
      hasCustomSeed ? const Color(0xFFF2F2F7) : PaperfoldTokens.light.ground;
  // trueDarkMode picks between Paperfold's two dark variants, and it defaults
  // on. A custom seed keeps the inherited iOS-grey backgrounds instead.
  final trueBlack = prefsNotifier.trueDarkMode;
  final darkGropedBackground = hasCustomSeed
      ? (trueBlack ? Colors.black : const Color(0xFF1C1C1E))
      : PaperfoldTokens.pagePalette(
          Brightness.dark,
          trueBlack: trueBlack,
        ).ground;
  final gropedBackgroundColor = isEinkMode
      ? Colors.white
      : isDark
          ? darkGropedBackground
          : lightGropedBackground;

  final colorScheme = isEinkMode
      ? const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          primaryContainer: Colors.grey,
          onPrimaryContainer: Colors.black,
          secondary: Colors.grey,
          onSecondary: Colors.black,
          secondaryContainer: Colors.black12,
          onSecondaryContainer: Colors.black,
          tertiary: Colors.black,
          onTertiary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
          onSurfaceVariant: Colors.black,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainer: Colors.white,
          surfaceContainerHigh: Color(0xFFF2F2F2),
          surfaceContainerHighest: Color(0xFFE5E5E5),
          surfaceTint: Colors.transparent,
        )
      : hasCustomSeed
          ? switch (brightness) {
              Brightness.light => ColorScheme.fromSeed(
                  seedColor: seedColor,
                  brightness: Brightness.light,
                  surfaceContainer: const Color(0xFFFFFFFF),
                  surface: lightGropedBackground,
                ),
              Brightness.dark => ColorScheme.fromSeed(
                  seedColor: seedColor,
                  brightness: Brightness.dark,
                  surfaceContainer: const Color(0xFF2C2C2E),
                  surface: darkGropedBackground,
                ),
            }
          : PaperfoldTokens.colorScheme(
              brightness,
              trueBlack: trueBlack,
            ).copyWith(
              surface: gropedBackgroundColor,
            );

  ThemeData themeData = isEinkMode
      ? FlexThemeData.light(
          useMaterial3: true,
          swapLegacyOnMaterial3: true,
          colorScheme: colorScheme)
      : switch (brightness) {
          Brightness.light => FlexThemeData.light(
              useMaterial3: true,
              swapLegacyOnMaterial3: true,
              colorScheme: colorScheme,
            ),
          Brightness.dark => FlexThemeData.dark(
              useMaterial3: true,
              swapLegacyOnMaterial3: true,
              darkIsTrueBlack: prefsNotifier.trueDarkMode,
              colorScheme: colorScheme,
            )
        };

  return paperfoldComponentTheme(themeData);
}

/// Shared typography and surfaces for the paper pages and burgundy library.
ThemeData paperfoldComponentTheme(ThemeData themeData) {
  // Component themes animate too. Resolve their text geometry before copying
  // styles, so raw app themes and inherited library themes share inherit=false.
  themeData = ThemeData.localize(themeData, themeData.typography.englishLike);
  final colorScheme = themeData.colorScheme;
  final brightness = colorScheme.brightness;
  final gropedBackgroundColor = colorScheme.surface;
  final textTheme = _paperfoldTextTheme(themeData.textTheme);
  const surfaceShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );

  return themeData
      .copyWith(
          sliderTheme: const SliderThemeData(year2023: false),
          progressIndicatorTheme:
              const ProgressIndicatorThemeData(year2023: false),
          textTheme: textTheme,
          primaryTextTheme: _paperfoldTextTheme(themeData.primaryTextTheme)
              .useSystemChineseFont(brightness),
          scaffoldBackgroundColor: gropedBackgroundColor,
          appBarTheme: themeData.appBarTheme.copyWith(
            backgroundColor: gropedBackgroundColor,
            foregroundColor: colorScheme.onSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            titleTextStyle: textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          bottomSheetTheme: themeData.bottomSheetTheme.copyWith(
            backgroundColor: gropedBackgroundColor,
            modalBackgroundColor: gropedBackgroundColor,
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          drawerTheme: themeData.drawerTheme.copyWith(
            backgroundColor: gropedBackgroundColor,
            surfaceTintColor: Colors.transparent,
          ),
          dialogTheme: themeData.dialogTheme.copyWith(
            backgroundColor: gropedBackgroundColor,
            surfaceTintColor: Colors.transparent,
            shape: surfaceShape,
            titleTextStyle: textTheme.headlineSmall,
            contentTextStyle: textTheme.bodyMedium,
          ),
          cardTheme: themeData.cardTheme.copyWith(
            color: colorScheme.surfaceContainerLow,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: surfaceShape,
          ),
          popupMenuTheme: themeData.popupMenuTheme.copyWith(
            color: colorScheme.surfaceContainerLow,
            surfaceTintColor: Colors.transparent,
            shape: surfaceShape,
            textStyle: textTheme.bodyMedium,
          ),
          dividerTheme: themeData.dividerTheme.copyWith(
            color: colorScheme.outlineVariant,
            thickness: 0.5,
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: colorScheme.surfaceContainerHigh,
            contentTextStyle:
                textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
            actionTextColor: colorScheme.primary,
            elevation: 2,
            insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ))
      .useSystemChineseFont(brightness);
}
