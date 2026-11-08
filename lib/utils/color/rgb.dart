import 'package:material_ui/material_ui.dart';

/// Ensure value is RGB (strips any alpha component).
int sanitizeRgb(int value) => value & 0x00FFFFFF;

/// Extract RGB component from a Color.
int rgbFromColor(Color color) => color.toARGB32() & 0x00FFFFFF;

int? parseRgb(dynamic value) {
  if (value == null) return null;
  if (value is Color) return rgbFromColor(value);
  if (value is num) {
    return sanitizeRgb(value.toInt());
  }
  if (value is String) {
    var v = value.trim();
    if (v.startsWith('0x')) {
      v = v.substring(2);
    } else if (v.startsWith('#')) {
      v = v.substring(1);
    }
    try {
      return sanitizeRgb(int.parse(v, radix: 16));
    } catch (_) {
      return null;
    }
  }
  return null;
}

