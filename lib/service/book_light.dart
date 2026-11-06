import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/utils/log/common.dart';

/// A colour in OKLab.
@immutable
class OkLab {
  const OkLab(this.l, this.a, this.b);

  final double l;
  final double a;
  final double b;

  double get chroma => math.sqrt(a * a + b * b);
  double get hue => math.atan2(b, a);

  double distanceTo(OkLab other) {
    final dl = l - other.l, da = a - other.a, db = b - other.b;
    return math.sqrt(dl * dl + da * da + db * db);
  }

  static double _lin(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static double _enc(double c) => c <= 0.0031308
      ? 12.92 * c
      : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

  factory OkLab.fromRgb(double r8, double g8, double b8) {
    final r = _lin(r8 / 255), g = _lin(g8 / 255), b = _lin(b8 / 255);
    final l = math
        .pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3)
        .toDouble();
    final m = math
        .pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3)
        .toDouble();
    final s = math
        .pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3)
        .toDouble();
    return OkLab(
      0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
    );
  }

  factory OkLab.fromLch(double l, double c, double h) =>
      OkLab(l, c * math.cos(h), c * math.sin(h));

  /// Linear sRGB, possibly out of gamut.
  List<double> _linear() {
    final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = l - 0.0894841775 * a - 1.2914855480 * b;
    final ll = l_ * l_ * l_, mm = m_ * m_ * m_, ss = s_ * s_ * s_;
    return [
      4.0767416621 * ll - 3.3077115913 * mm + 0.2309699292 * ss,
      -1.2684380046 * ll + 2.6097574011 * mm - 0.3413193965 * ss,
      -0.0041960863 * ll - 0.7034186147 * mm + 1.7076147010 * ss,
    ];
  }

  bool get inGamut => _linear().every((c) => c >= -0.0001 && c <= 1.0001);

  Color toColor() {
    final lin = _linear();
    int ch(double c) => (_enc(c.clamp(0.0, 1.0)) * 255).round().clamp(0, 255);
    return Color.fromARGB(255, ch(lin[0]), ch(lin[1]), ch(lin[2]));
  }

  List<double> toJson() => [l, a, b];

  static OkLab fromJson(List<dynamic> v) => OkLab(
    (v[0] as num).toDouble(),
    (v[1] as num).toDouble(),
    (v[2] as num).toDouble(),
  );
}

/// The two colours a cover lends to the glass, before a theme clamps them.
@immutable
class BookLightSource {
  const BookLightSource(this.dominant, this.secondary);

  final OkLab dominant;
  final OkLab secondary;

  /// Both colours, clamped into [band] and reduced into sRGB.
  (Color, Color) resolve(BookLightBand band) =>
      (_clamp(dominant, band), _clamp(secondary, band));

  static Color _clamp(OkLab c, BookLightBand band) {
    final l = c.l.clamp(band.minL, band.maxL).toDouble();
    var chroma = c.chroma < 0.01 ? 0.0 : math.min(c.chroma, band.maxC);
    final hue = c.hue;
    var candidate = OkLab.fromLch(l, chroma, hue);
    // Reduce chroma, never clip channels, until the colour fits sRGB.
    var lo = 0.0, hi = chroma;
    if (!candidate.inGamut) {
      for (var i = 0; i < 18; i++) {
        final mid = (lo + hi) / 2;
        if (OkLab.fromLch(l, mid, hue).inGamut) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      chroma = lo;
      candidate = OkLab.fromLch(l, chroma, hue);
    }
    return candidate.toColor();
  }

  /// A single-colour source, for a book with no cover image.
  factory BookLightSource.solid(Color color) {
    final lab = OkLab.fromRgb(color.r * 255, color.g * 255, color.b * 255);
    return BookLightSource(lab, lab);
  }
}

/// Extracts and remembers each cover's BookLight colours.
///
/// A cover is decoded once at 64 x 64. The two OKLab centroids are kept in
/// memory and in a small file, keyed by path, size and modification time, so
/// a replaced cover is read again and an unchanged one never is.
class BookLightService {
  BookLightService._();

  static final BookLightService instance = BookLightService._();

  /// The extraction rule. Bump it to invalidate every cached entry.
  static const int ruleVersion = 1;
  static const int _maxEntries = 2000;

  final LinkedHashMap<String, BookLightSource> _memory =
      LinkedHashMap<String, BookLightSource>();
  final Map<String, Future<BookLightSource?>> _pending = {};
  bool _loaded = false;
  File? _file;
  bool _saveScheduled = false;

  /// The cached source for [coverPath], without reading anything.
  BookLightSource? peek(String coverPath) {
    final key = _keyFor(coverPath);
    return key == null ? null : _memory[key];
  }

  Future<BookLightSource?> sourceFor(String coverPath) async {
    if (coverPath.isEmpty) return null;
    await _load();
    final key = _keyFor(coverPath);
    if (key == null) return null;
    final cached = _memory[key];
    if (cached != null) return cached;
    return _pending[key] ??= _extract(coverPath).then((source) {
      _pending.remove(key);
      if (source != null) {
        _memory[key] = source;
        while (_memory.length > _maxEntries) {
          _memory.remove(_memory.keys.first);
        }
        _scheduleSave();
      }
      return source;
    });
  }

  String? _keyFor(String coverPath) {
    try {
      final stat = File(coverPath).statSync();
      if (stat.type == FileSystemEntityType.notFound) return null;
      return '$ruleVersion|$coverPath|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
    } catch (_) {
      return null;
    }
  }

  Future<BookLightSource?> _extract(String coverPath) async {
    try {
      final bytes = await File(coverPath).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 64,
        targetHeight: 64,
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      frame.image.dispose();
      codec.dispose();
      if (data == null) return null;
      return extractFromRgba(data.buffer.asUint8List());
    } catch (e) {
      AnxLog.info('BookLight: cover not read ($e)');
      return null;
    }
  }

  /// The rule, on raw straight RGBA pixels. Public for tests.
  static BookLightSource? extractFromRgba(List<int> rgba) {
    final weights = <(int, int, int), double>{};
    final sums = <(int, int, int), List<double>>{};
    for (var i = 0; i + 3 < rgba.length; i += 4) {
      final alpha = rgba[i + 3] / 255;
      if (alpha < 0.5) continue;
      final lab = OkLab.fromRgb(
        rgba[i].toDouble(),
        rgba[i + 1].toDouble(),
        rgba[i + 2].toDouble(),
      );
      final bin = (
        (lab.l / 0.05).floor(),
        (lab.a / 0.025).floor(),
        (lab.b / 0.025).floor(),
      );
      weights[bin] = (weights[bin] ?? 0) + alpha;
      final sum = sums[bin] ??= [0, 0, 0];
      sum[0] += lab.l * alpha;
      sum[1] += lab.a * alpha;
      sum[2] += lab.b * alpha;
    }
    if (weights.isEmpty) return null;
    final bins = weights.keys.toList()
      ..sort((x, y) {
        final byWeight = weights[y]!.compareTo(weights[x]!);
        if (byWeight != 0) return byWeight;
        if (x.$1 != y.$1) return x.$1.compareTo(y.$1);
        if (x.$2 != y.$2) return x.$2.compareTo(y.$2);
        return x.$3.compareTo(y.$3);
      });
    OkLab centroid((int, int, int) bin) {
      final w = weights[bin]!, s = sums[bin]!;
      return OkLab(s[0] / w, s[1] / w, s[2] / w);
    }

    final dominant = centroid(bins.first);
    var secondary = dominant;
    for (final bin in bins.skip(1)) {
      final c = centroid(bin);
      if (c.distanceTo(dominant) >= 0.04) {
        secondary = c;
        break;
      }
    }
    return BookLightSource(dominant, secondary);
  }

  Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final dir = await getApplicationSupportDirectory();
      _file = File(p.join(dir.path, 'book_light.json'));
      if (!await _file!.exists()) return;
      final decoded = jsonDecode(await _file!.readAsString());
      if (decoded is! Map<String, dynamic>) return;
      for (final entry in decoded.entries) {
        if (!entry.key.startsWith('$ruleVersion|')) continue;
        final v = entry.value as List<dynamic>;
        _memory[entry.key] = BookLightSource(
          OkLab.fromJson(v[0] as List<dynamic>),
          OkLab.fromJson(v[1] as List<dynamic>),
        );
      }
    } catch (e) {
      AnxLog.info('BookLight: cache not read ($e)');
    }
  }

  void _scheduleSave() {
    if (_saveScheduled || _file == null) return;
    _saveScheduled = true;
    Future<void>.delayed(const Duration(seconds: 2), () async {
      _saveScheduled = false;
      try {
        final map = <String, Object>{
          for (final e in _memory.entries)
            e.key: [e.value.dominant.toJson(), e.value.secondary.toJson()],
        };
        await _file!.writeAsString(jsonEncode(map), flush: true);
      } catch (e) {
        AnxLog.info('BookLight: cache not written ($e)');
      }
    });
  }
}
