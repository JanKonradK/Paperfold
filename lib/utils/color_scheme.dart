import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:chinese_font_library/chinese_font_library.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:material_ui/material_ui.dart';

TextStyle? _journalStyle(TextStyle? style) {
  return style?.copyWith(
    fontFamily: PaperfoldTypeTokens.journalFamily,
    fontStyle: FontStyle.normal,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: 0,
  );
}

TextStyle? _chromeHeading(TextStyle? style) {
  return style?.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.25,
  );
}

TextTheme _paperfoldTextTheme(TextTheme base) {
  final chrome = base.apply(fontFamily: PaperfoldTypeTokens.chromeFamily);
  return chrome
      .copyWith(
        displayLarge: _journalStyle(base.displayLarge),
        displayMedium: _journalStyle(base.displayMedium),
        displaySmall: _journalStyle(base.displaySmall),
        headlineLarge: _chromeHeading(chrome.headlineLarge),
        headlineMedium: _chromeHeading(chrome.headlineMedium),
        headlineSmall: _chromeHeading(chrome.headlineSmall),
        titleLarge: _chromeHeading(chrome.titleLarge),
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
      )
      .apply(fontFamilyFallback: SystemChineseFont.fontFamilyFallback);
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

  final lightGropedBackground = hasCustomSeed
      ? const Color(0xFFF2F2F7)
      : PaperfoldTokens.light.ground;
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
        ).copyWith(surface: gropedBackgroundColor);

  ThemeData themeData = isEinkMode
      ? FlexThemeData.light(
          useMaterial3: true,
          swapLegacyOnMaterial3: true,
          colorScheme: colorScheme,
        )
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
          ),
        };

  return paperfoldComponentTheme(themeData);
}

/// Shared typography, shapes, and control sizes for every route.
///
/// Paperfold 3: four corners (4, 16, 24, 32), slim controls drawn at 40 with
/// 48 touch targets, and one set of colour roles. Callers should not need
/// their own shapes; if one does, it takes a value from [PaperfoldShape].
ThemeData paperfoldComponentTheme(ThemeData themeData) {
  // Component themes animate too. Resolve their text geometry before copying
  // styles, so raw app themes and inherited library themes share inherit=false.
  themeData = ThemeData.localize(themeData, themeData.typography.englishLike);
  final colorScheme = themeData.colorScheme;
  final ground = colorScheme.surface;
  final textTheme = _paperfoldTextTheme(themeData.textTheme);
  final labelStyle = textTheme.labelLarge?.copyWith(
    fontSize: 15,
    height: 20 / 15,
  );
  const controlPadding = EdgeInsets.symmetric(horizontal: 18);
  const controlMinimum = Size(64, PaperfoldSize.control);
  final ButtonStyle controlBase = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(controlMinimum),
    padding: const WidgetStatePropertyAll(controlPadding),
    shape: const WidgetStatePropertyAll(PaperfoldShape.controlShape),
    textStyle: WidgetStatePropertyAll(labelStyle),
    iconSize: const WidgetStatePropertyAll(PaperfoldSize.smallIcon),
    tapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    animationDuration: PaperfoldMotion.tick,
  );
  final outlineSide = BorderSide(
    color: colorScheme.outline.withValues(alpha: 0.6),
  );
  OutlineInputBorder fieldBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: PaperfoldShape.controlRadius,
        borderSide: BorderSide(color: color, width: width),
      );

  return themeData.copyWith(
    sliderTheme: const SliderThemeData(year2023: false),
    progressIndicatorTheme: const ProgressIndicatorThemeData(year2023: false),
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
    textTheme: textTheme,
    primaryTextTheme: _paperfoldTextTheme(themeData.primaryTextTheme),
    scaffoldBackgroundColor: ground,
    appBarTheme: themeData.appBarTheme.copyWith(
      backgroundColor: ground,
      foregroundColor: colorScheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: PaperfoldSize.appBar,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: controlBase),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: controlBase.copyWith(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(colorScheme.primaryContainer),
        foregroundColor: WidgetStatePropertyAll(colorScheme.onPrimaryContainer),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: controlBase.copyWith(side: WidgetStatePropertyAll(outlineSide)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: controlBase.copyWith(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(PaperfoldShape.controlShape),
        iconSize: WidgetStatePropertyAll(PaperfoldSize.icon),
        minimumSize: WidgetStatePropertyAll(Size.square(PaperfoldSize.control)),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    ),
    floatingActionButtonTheme: themeData.floatingActionButtonTheme.copyWith(
      shape: PaperfoldShape.controlShape,
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 1,
      sizeConstraints: const BoxConstraints.tightFor(
        width: PaperfoldSize.fab,
        height: PaperfoldSize.fab,
      ),
      extendedSizeConstraints: const BoxConstraints(
        minHeight: PaperfoldSize.fab,
        minWidth: PaperfoldSize.fab,
      ),
      extendedTextStyle: labelStyle,
      extendedPadding: const EdgeInsetsDirectional.only(start: 16, end: 20),
      iconSize: PaperfoldSize.icon,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(PaperfoldShape.controlShape),
        minimumSize: const WidgetStatePropertyAll(
          Size(48, PaperfoldSize.control),
        ),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(fontSize: 14, height: 20 / 14),
        ),
        side: WidgetStatePropertyAll(outlineSide),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primaryContainer
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
        ),
      ),
    ),
    chipTheme: themeData.chipTheme.copyWith(
      shape: PaperfoldShape.controlShape,
      side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.16)),
      backgroundColor: Colors.transparent,
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      labelStyle: textTheme.labelLarge?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        color: colorScheme.onSurface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      showCheckmark: true,
    ),
    inputDecorationTheme: themeData.inputDecorationTheme.copyWith(
      filled: true,
      fillColor: colorScheme.surfaceContainer,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: fieldBorder(colorScheme.outline),
      enabledBorder: fieldBorder(colorScheme.outline),
      focusedBorder: fieldBorder(colorScheme.primary, 2),
      errorBorder: fieldBorder(colorScheme.error),
      focusedErrorBorder: fieldBorder(colorScheme.error, 2),
    ),
    listTileTheme: themeData.listTileTheme.copyWith(
      shape: PaperfoldShape.controlShape,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PaperfoldSpace.gutter,
      ),
      minTileHeight: PaperfoldSize.target,
      minVerticalPadding: 6,
      horizontalTitleGap: 14,
      iconColor: colorScheme.onSurfaceVariant,
      titleTextStyle: textTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 22 / 16,
        color: colorScheme.onSurface,
      ),
      subtitleTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: PaperfoldSize.navigationBar,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: colorScheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelSmall?.copyWith(
          fontSize: 12,
          color: states.contains(WidgetState.selected)
              ? colorScheme.onSurface
              : colorScheme.onSurfaceVariant,
        ),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: themeData.navigationRailTheme.copyWith(
      backgroundColor: ground,
      indicatorColor: colorScheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
    ),
    bottomSheetTheme: themeData.bottomSheetTheme.copyWith(
      backgroundColor: ground,
      modalBackgroundColor: ground,
      surfaceTintColor: Colors.transparent,
      shape: PaperfoldShape.sheetShape,
      dragHandleSize: const Size(32, 4),
      dragHandleColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      clipBehavior: Clip.antiAlias,
    ),
    drawerTheme: themeData.drawerTheme.copyWith(
      backgroundColor: ground,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: themeData.dialogTheme.copyWith(
      backgroundColor: ground,
      surfaceTintColor: Colors.transparent,
      shape: PaperfoldShape.frameShape,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: colorScheme.onSurface,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    cardTheme: themeData.cardTheme.copyWith(
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: PaperfoldShape.paneShape,
    ),
    popupMenuTheme: themeData.popupMenuTheme.copyWith(
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: PaperfoldShape.paneShape,
      textStyle: textTheme.bodyMedium,
    ),
    tooltipTheme: themeData.tooltipTheme.copyWith(
      decoration: BoxDecoration(
        color: colorScheme.inverseSurface,
        borderRadius: PaperfoldShape.controlRadius,
      ),
    ),
    dividerTheme: themeData.dividerTheme.copyWith(
      color: colorScheme.onSurface.withValues(alpha: 0.12),
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      actionTextColor: colorScheme.inversePrimary,
      elevation: 2,
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      shape: PaperfoldShape.controlShape,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        // The system Back gesture drives the page on Android 14 and later.
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
