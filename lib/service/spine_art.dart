import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:paperfold/utils/log/common.dart';

/// A strip of a book's own cover, for painting down its spine.
///
/// A real hardback wears one jacket that wraps from the front, around the
/// spine, to the back, so the spine and the cover are obviously the same
/// object. Paperfold used to derive a spine colour by hashing the book id into
/// a fixed table of eight cloths, which meant a shelf of books wore colours
/// that had nothing to do with the books.
@immutable
class SpineArt {
  const SpineArt({
    required this.strip,
    required this.average,
    required this.foreground,
  });

  /// A small decode of the cover. The painter samples its leading edge and
  /// stretches that slice across the spine, so the spine carries the art that
  /// wraps around the real book's hinge.
  final ui.Image strip;

  /// The average colour of that slice. Text contrast is measured against this,
  /// and the painter lays a veil of it over the art so the measurement holds
  /// over every pixel, not just the mean.
  final Color average;

  /// The tested title colour: at least 4.5:1 over [average].
  final Color foreground;
}

/// Decodes cover art into spine strips, once per cover.
///
/// Decoding happens at 48x72, which is enough pixels for a 64 dp strip and
/// small enough that a shelf of them costs almost nothing. Results are held
/// for the life of the process because a cover does not change while the
/// application runs, and a shelf rebuilds on every scroll.
abstract final class SpineArtCache {
  static final Map<String, SpineArt> _ready = {};
  static final Map<String, Future<SpineArt?>> _inFlight = {};

  static const int _decodeWidth = 48;
  static const int _decodeHeight = 72;

  /// The share of the cover width that wraps onto the spine.
  static const double stripFraction = 0.22;

  /// The strip for [coverPath], if it has already been decoded.
  ///
  /// Callers paint this synchronously when it is present, so a shelf that has
  /// been seen once never flickers back to the fallback cloth while scrolling.
  static SpineArt? peek(String coverPath) => _ready[coverPath];

  static Future<SpineArt?> load(String coverPath) {
    final ready = _ready[coverPath];
    if (ready != null) return Future.value(ready);
    return _inFlight.putIfAbsent(coverPath, () => _decode(coverPath));
  }

  static Future<SpineArt?> _decode(String coverPath) async {
    try {
      final file = File(coverPath);
      if (!file.existsSync()) return null;
      final codec = await ui.instantiateImageCodec(
        await file.readAsBytes(),
        targetWidth: _decodeWidth,
        targetHeight: _decodeHeight,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      final image = frame.image;

      final average = await _averageOfLeadingEdge(image);
      if (average == null) {
        image.dispose();
        return null;
      }

      final art = SpineArt(
        strip: image,
        average: average,
        foreground: _titleColourOver(average),
      );
      _ready[coverPath] = art;
      return art;
    } catch (e) {
      AnxLog.warning('Cover art for the spine could not be read: $e');
      return null;
    } finally {
      _inFlight.remove(coverPath);
    }
  }

  static Future<Color?> _averageOfLeadingEdge(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final bytes = data.buffer.asUint8List();
    final sliceWidth = (image.width * stripFraction).ceil().clamp(1, image.width);

    var red = 0, green = 0, blue = 0, counted = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < sliceWidth; x++) {
        final i = (y * image.width + x) * 4;
        if (i + 3 >= bytes.length) continue;
        // A transparent pixel is not part of the artwork.
        if (bytes[i + 3] < 8) continue;
        red += bytes[i];
        green += bytes[i + 1];
        blue += bytes[i + 2];
        counted++;
      }
    }
    if (counted == 0) return null;
    return Color.fromARGB(
      255,
      red ~/ counted,
      green ~/ counted,
      blue ~/ counted,
    );
  }

  static double contrast(Color foreground, Color background) {
    final lighter = foreground.computeLuminance() > background.computeLuminance()
        ? foreground.computeLuminance()
        : background.computeLuminance();
    final darker = foreground.computeLuminance() > background.computeLuminance()
        ? background.computeLuminance()
        : foreground.computeLuminance();
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// The better of near-white and near-black over [background].
  ///
  /// One of the two always clears 4.5:1, because they sit at the ends of the
  /// luminance range, so a title is never unreadable whatever the cover.
  static Color _titleColourOver(Color background) {
    const light = Color(0xFFF7F2E8);
    const dark = Color(0xFF17120E);
    return contrast(light, background) >= contrast(dark, background)
        ? light
        : dark;
  }
}
