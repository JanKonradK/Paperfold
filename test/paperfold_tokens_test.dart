import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/paperfold_tokens.dart';

double _linearChannel(int channel) {
  final double value = channel / 255;
  return value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(Color color) {
  final int value = color.toARGB32();
  final int red = (value >> 16) & 0xFF;
  final int green = (value >> 8) & 0xFF;
  final int blue = value & 0xFF;

  return 0.2126 * _linearChannel(red) +
      0.7152 * _linearChannel(green) +
      0.0722 * _linearChannel(blue);
}

double _contrastRatio(Color foreground, Color background) {
  final double foregroundLuminance = _relativeLuminance(foreground);
  final double backgroundLuminance = _relativeLuminance(background);
  final double lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final double darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;

  return (lighter + 0.05) / (darker + 0.05);
}

void _expectTextContrast(
  ColorScheme scheme,
  Color foreground,
  Color background,
  String pairing,
) {
  expect(
    _contrastRatio(foreground, background),
    greaterThanOrEqualTo(4.5),
    reason:
        '$pairing must support body text in ${scheme.brightness.name} mode.',
  );
}

void _expectMaterialRoleContrast(ColorScheme scheme) {
  _expectTextContrast(
    scheme,
    scheme.onPrimary,
    scheme.primary,
    'onPrimary/primary',
  );
  _expectTextContrast(
    scheme,
    scheme.onSecondary,
    scheme.secondary,
    'onSecondary/secondary',
  );
  _expectTextContrast(
    scheme,
    scheme.onTertiary,
    scheme.tertiary,
    'onTertiary/tertiary',
  );
  _expectTextContrast(
    scheme,
    scheme.onSurface,
    scheme.surface,
    'onSurface/surface',
  );
  _expectTextContrast(
    scheme,
    scheme.onSurfaceVariant,
    scheme.surface,
    'onSurfaceVariant/surface',
  );
  _expectTextContrast(
    scheme,
    scheme.onPrimaryContainer,
    scheme.primaryContainer,
    'onPrimaryContainer/primaryContainer',
  );
  _expectTextContrast(
    scheme,
    scheme.onSecondaryContainer,
    scheme.secondaryContainer,
    'onSecondaryContainer/secondaryContainer',
  );
  _expectTextContrast(
    scheme,
    scheme.onTertiaryContainer,
    scheme.tertiaryContainer,
    'onTertiaryContainer/tertiaryContainer',
  );
  _expectTextContrast(scheme, scheme.onError, scheme.error, 'onError/error');
  _expectTextContrast(
    scheme,
    scheme.onInverseSurface,
    scheme.inverseSurface,
    'onInverseSurface/inverseSurface',
  );
}

void main() {
  test('burgundy sits between cream and dark with readable Material roles', () {
    _expectMaterialRoleContrast(PaperfoldTokens.burgundyColorScheme());
    expect(
      _relativeLuminance(PaperfoldTokens.burgundy.ground),
      greaterThan(_relativeLuminance(PaperfoldTokens.darkNearBlack.ground)),
    );
    expect(
      _relativeLuminance(PaperfoldTokens.burgundy.ground),
      lessThan(_relativeLuminance(PaperfoldTokens.light.ground)),
    );
    expect(
      _contrastRatio(
        PaperfoldTokens.burgundy.accent,
        PaperfoldTokens.burgundy.surfaceHighest,
      ),
      greaterThanOrEqualTo(4.5),
    );
  });
  group('Paperfold contrast', () {
    test('light text and accent pass on paper', () {
      expect(
        _contrastRatio(PaperfoldTokens.light.ink, PaperfoldTokens.light.ground),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          PaperfoldTokens.light.inkSoft,
          PaperfoldTokens.light.ground,
        ),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrastRatio(
          PaperfoldTokens.light.accent,
          PaperfoldTokens.light.ground,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('aged gold is readable on the burgundy cover', () {
      expect(
        _contrastRatio(
          PaperfoldTokens.cover.foil,
          PaperfoldTokens.cover.ground,
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    for (final (name, palette) in <(String, PaperfoldPagePalette)>[
      ('burgundy', PaperfoldTokens.burgundy),
      ('true black', PaperfoldTokens.darkTrueBlack),
      ('near-black', PaperfoldTokens.darkNearBlack),
    ]) {
      test('dark text and accent pass on the $name ground', () {
        expect(
          _contrastRatio(palette.ink, palette.ground),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(palette.inkSoft, palette.ground),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrastRatio(palette.accent, palette.ground),
          greaterThanOrEqualTo(4.5),
        );
      });

      // A card, a dialog and a menu must still separate. Black gives no tonal
      // elevation for free, so the ramp is asserted rather than assumed.
      test('the $name surface ramp has five distinct steps', () {
        final steps = <Color>[
          palette.surfaceLowest,
          palette.surfaceLow,
          palette.surface,
          palette.surfaceHigh,
          palette.surfaceHighest,
        ];
        expect(
          steps.toSet().length,
          steps.length,
          reason: 'every $name surface step must be a distinct colour',
        );
        for (var i = 1; i < steps.length; i++) {
          expect(
            _relativeLuminance(steps[i]),
            greaterThan(_relativeLuminance(steps[i - 1])),
            reason: 'the $name ramp must rise monotonically',
          );
        }
        for (final step in steps) {
          expect(
            _contrastRatio(palette.ink, step),
            greaterThanOrEqualTo(4.5),
            reason: 'ink must stay readable on every $name surface',
          );
          expect(
            _contrastRatio(palette.inkSoft, step),
            greaterThanOrEqualTo(4.5),
            reason: 'secondary text must stay readable on every $name surface',
          );
        }
      });
    }
  });

  test('the primary role swaps accents between brightnesses', () {
    final ColorScheme lightScheme = PaperfoldTokens.colorScheme(
      Brightness.light,
    );
    final ColorScheme darkScheme = PaperfoldTokens.colorScheme(Brightness.dark);

    expect(lightScheme.primary, PaperfoldTokens.light.accent);
    expect(darkScheme.primary, PaperfoldTokens.dark.accent);
    expect(lightScheme.primary, isNot(darkScheme.primary));
  });

  test('light Material role pairings support body text', () {
    _expectMaterialRoleContrast(PaperfoldTokens.colorScheme(Brightness.light));
  });

  test('dark Material role pairings support body text on true black', () {
    _expectMaterialRoleContrast(
      PaperfoldTokens.colorScheme(Brightness.dark, trueBlack: true),
    );
  });

  test('dark Material role pairings support body text on near-black', () {
    _expectMaterialRoleContrast(
      PaperfoldTokens.colorScheme(Brightness.dark, trueBlack: false),
    );
  });

  test('the dark variants are different and default to true black', () {
    expect(
      PaperfoldTokens.pagePalette(Brightness.dark).ground,
      PaperfoldTokens.darkTrueBlack.ground,
      reason: 'a new install gets true black; trueDarkMode defaults on',
    );
    expect(
      PaperfoldTokens.darkTrueBlack.ground,
      isNot(PaperfoldTokens.darkNearBlack.ground),
    );
    expect(
      PaperfoldTokens.pagePalette(Brightness.light).ground,
      PaperfoldTokens.light.ground,
      reason: 'trueBlack must not leak into the light theme',
    );
  });

  test('the bookcase wood differs between themes', () {
    expect(
      PaperfoldTokens.wood(Brightness.light).board,
      isNot(PaperfoldTokens.wood(Brightness.dark).board),
    );
    // The boards carry no text by default, but onWood must be legible on the
    // board it belongs to for the cases where a label has to sit on wood.
    for (final brightness in Brightness.values) {
      final wood = PaperfoldTokens.wood(brightness);
      expect(
        _contrastRatio(wood.onWood, wood.board),
        greaterThanOrEqualTo(4.5),
        reason: 'onWood must be readable on ${brightness.name} board',
      );
    }
  });
}
