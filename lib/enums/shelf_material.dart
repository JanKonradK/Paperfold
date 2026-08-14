import 'package:flutter/material.dart';

/// What the shelves are made of.
///
/// The shelf is the one piece of furniture left on the home screen, and the
/// owner should be able to choose it. Every option here is the same object -
/// a thin floating plank with two small brackets under it - in a different
/// material, so choosing one never changes the layout, the height of a bay, or
/// where a book stands. It changes what the plank is.
enum ShelfMaterial {
  /// Toughened glass. A thin slab with the green edge that gives float glass
  /// away, and almost nothing else.
  glass('glass'),

  /// Brushed metal. A little more present than the glass, with an anisotropic
  /// highlight along its front edge.
  metal('metal'),

  /// Oiled oak. The warmest of the three, and the only one with grain.
  wood('wood'),

  /// Nothing at all. The books stand on their own contact shadow.
  none('none');

  const ShelfMaterial(this.code);

  final String code;

  static ShelfMaterial fromCode(String? code) {
    return ShelfMaterial.values.firstWhere(
      (material) => material.code == code,
      orElse: () => ShelfMaterial.glass,
    );
  }
}

/// The colours one material is made of.
///
/// Held apart from the painter so a material is a small table of values rather
/// than a branch inside every draw call, and so the set can be read in a test.
@immutable
class ShelfMaterialPalette {
  const ShelfMaterialPalette({
    required this.deck,
    required this.deckFar,
    required this.edgeLight,
    required this.edgeBody,
    required this.edgeShade,
    required this.underside,
    required this.opacity,
    required this.grain,
  });

  /// The top surface, where the books stand, nearest the reader.
  final Color deck;

  /// The same surface where it recedes toward the wall.
  final Color deckFar;

  /// The front edge, which is the only part of a shelf with any thickness to
  /// it and therefore the part that says what the shelf is made of.
  final Color edgeLight;
  final Color edgeBody;
  final Color edgeShade;

  /// Under the front edge, in shadow.
  final Color underside;

  /// How present the whole plank is. Glass is mostly not there.
  final double opacity;

  /// Grain lines along the deck, for the one material that has any.
  final bool grain;

  @override
  bool operator ==(Object other) =>
      other is ShelfMaterialPalette &&
      other.deck == deck &&
      other.deckFar == deckFar &&
      other.edgeLight == edgeLight &&
      other.edgeBody == edgeBody &&
      other.edgeShade == edgeShade &&
      other.underside == underside &&
      other.opacity == opacity &&
      other.grain == grain;

  @override
  int get hashCode => Object.hash(
        deck,
        deckFar,
        edgeLight,
        edgeBody,
        edgeShade,
        underside,
        opacity,
        grain,
      );

  static ShelfMaterialPalette of(ShelfMaterial material, ColorScheme scheme) {
    switch (material) {
      case ShelfMaterial.glass:
        // Float glass seen on edge is green, and that single cue is what tells
        // a thin bright line apart from a thin bright line. The faces stay
        // nearly transparent so the page ground reads straight through.
        return ShelfMaterialPalette(
          deck: scheme.onSurface.withValues(alpha: 0.05),
          deckFar: scheme.onSurface.withValues(alpha: 0.12),
          edgeLight: const Color(0xFFDCEFE6),
          edgeBody: const Color(0xFF7FB3A3),
          edgeShade: const Color(0xFF2E5B51),
          underside: scheme.shadow.withValues(alpha: 0.30),
          opacity: 0.85,
          grain: false,
        );
      case ShelfMaterial.metal:
        return ShelfMaterialPalette(
          deck: scheme.onSurface.withValues(alpha: 0.10),
          deckFar: scheme.onSurface.withValues(alpha: 0.20),
          edgeLight: const Color(0xFFE9E1D5),
          edgeBody: const Color(0xFF8B8279),
          edgeShade: const Color(0xFF33302B),
          underside: scheme.shadow.withValues(alpha: 0.42),
          opacity: 1,
          grain: false,
        );
      case ShelfMaterial.wood:
        return ShelfMaterialPalette(
          deck: const Color(0xFFB99B72),
          deckFar: const Color(0xFF8A6E4C),
          edgeLight: const Color(0xFFC8AC85),
          edgeBody: const Color(0xFF9A7A54),
          edgeShade: const Color(0xFF4C3823),
          underside: scheme.shadow.withValues(alpha: 0.46),
          opacity: 1,
          grain: true,
        );
      case ShelfMaterial.none:
        return ShelfMaterialPalette(
          deck: const Color(0x00000000),
          deckFar: const Color(0x00000000),
          edgeLight: const Color(0x00000000),
          edgeBody: const Color(0x00000000),
          edgeShade: const Color(0x00000000),
          underside: scheme.shadow.withValues(alpha: 0.22),
          opacity: 0,
          grain: false,
        );
    }
  }
}
