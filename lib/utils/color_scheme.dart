import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

TextStyle? _journalStyle(
  TextStyle? style, {
  FontStyle fontStyle = FontStyle.normal,
  FontWeight fontWeight = FontWeight.w400,
}) {
  return style?.copyWith(
    fontFamily: PaperfoldTypeTokens.journalFamily,
    fontStyle: fontStyle,
    fontWeight: fontWeight,
  );
}

TextTheme _paperfoldTextTheme(TextTheme base) {
  return base.copyWith(
    displayLarge: _journalStyle(
      base.displayLarge,
      fontStyle: FontStyle.italic,
    ),
    displayMedium: _journalStyle(
      base.displayMedium,
      fontStyle: FontStyle.italic,
    ),
    displaySmall: _journalStyle(
      base.displaySmall,
      fontStyle: FontStyle.italic,
    ),
    headlineLarge: _journalStyle(
      base.headlineLarge,
      fontStyle: FontStyle.italic,
    ),
    headlineMedium: _journalStyle(
      base.headlineMedium,
      fontStyle: FontStyle.italic,
    ),
    headlineSmall: _journalStyle(
      base.headlineSmall,
      fontStyle: FontStyle.italic,
    ),
    titleLarge: _journalStyle(base.titleLarge),
    titleMedium: _journalStyle(base.titleMedium),
    titleSmall: _journalStyle(base.titleSmall),
    bodyLarge: _journalStyle(base.bodyLarge),
    bodyMedium: _journalStyle(base.bodyMedium),
    bodySmall: _journalStyle(base.bodySmall),
    labelLarge: base.labelLarge?.copyWith(
      fontFamily: PaperfoldTypeTokens.chromeFamily,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontFamily: PaperfoldTypeTokens.chromeFamily,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontFamily: PaperfoldTypeTokens.chromeFamily,
      fontStyle: FontStyle.normal,
      fontWeight: FontWeight.w600,
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
          onSecondary: Colors.white,
          secondaryContainer: Colors.black12,
          onSecondaryContainer: Colors.black,
          surface: Colors.white,
          onSurface: Colors.black,
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

  return themeData
      .copyWith(
          sliderTheme: const SliderThemeData(year2023: false),
          progressIndicatorTheme:
              const ProgressIndicatorThemeData(year2023: false),
          textTheme: _paperfoldTextTheme(themeData.textTheme),
          primaryTextTheme: _paperfoldTextTheme(themeData.primaryTextTheme)
              .useSystemChineseFont(brightness),
          scaffoldBackgroundColor: gropedBackgroundColor,
          bottomSheetTheme: BottomSheetThemeData()
              .copyWith(backgroundColor: gropedBackgroundColor),
          drawerTheme: DrawerThemeData()
              .copyWith(backgroundColor: gropedBackgroundColor),
          dialogTheme: DialogThemeData()
              .copyWith(backgroundColor: gropedBackgroundColor),
          // The one surface still wearing stock Material: a white slab of
          // snack bar across a true-black shelf. Every other surface in the
          // application takes the grouped background and the body face, so
          // this one does too, floating and rounded like the rest of the
          // chrome rather than welded to the bottom edge.
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            // A raised step of the scheme, not the ground: on true black a
            // snack bar the colour of the shelf is a message nobody can see.
            backgroundColor: colorScheme.surfaceContainerHigh,
            contentTextStyle: _paperfoldTextTheme(themeData.textTheme)
                .bodyMedium
                ?.copyWith(color: colorScheme.onSurface),
            actionTextColor: colorScheme.primary,
            elevation: 2,
            insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ))
      .useSystemChineseFont(brightness);
}
