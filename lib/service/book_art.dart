import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/utils/log/common.dart';

/// What a cover file actually holds.
enum BookArtLayout {
  /// One front cover. The spine and the back have to be derived from it.
  frontOnly,

  /// A complete jacket: back, spine and front printed on one sheet. Some
  /// publishers ship these in EPUB, and when they do, the model can wrap the
  /// real artwork round the real object instead of guessing.
  wrapAround,
}

/// A book's cover art, decoded once, with the pieces the 3D model needs.
///
/// The model paints five surfaces from this: the front board, the spine, the
/// back board, and the two inside faces. A front-only cover supplies the front
/// directly and the colour for a plain spine and back. A wrap-around jacket
/// supplies all three outright.
@immutable
class BookArt {
  const BookArt({
    required this.image,
    required this.layout,
    required this.front,
    required this.spine,
    required this.back,
    required this.coverAverage,
    required this.spineAverage,
    required this.backAverage,
    required this.coverInk,
    required this.spineInk,
  });

  /// The decoded artwork. Source rectangles below index into this.
  final ui.Image image;

  final BookArtLayout layout;

  /// The part of [image] that is the front board.
  final Rect front;

  /// The part of [image] that wraps onto the spine, when it has printed art.
  final Rect spine;

  /// The part of [image] that is the back board, when it has printed art.
  final Rect back;

  final Color coverAverage;
  final Color spineAverage;
  final Color backAverage;

  /// Text colours already tested to at least 4.5:1 over the field they sit on.
  final Color coverInk;
  final Color spineInk;

  bool get isWrapAround => layout == BookArtLayout.wrapAround;
}

/// Decodes cover files into [BookArt], once per file.
///
/// It used to share the work with a `SpineArtCache` that decoded at 48x72 for
/// a shelf of small flat spines. The shelf draws solid books now, so there is
/// one cache and it decodes at up to 512 px: a book on the shelf and a book in
/// the hand are the same object, and the one in the hand needs the pixels.
abstract final class BookArtCache {
  static final Map<String, BookArt> _ready = {};
  static final Map<String, Future<BookArt?>> _inFlight = {};

  /// The long edge of the decode, in pixels.
  static const int decodeLongEdge = 512;

  /// The share reserved for a front-only cover's spine source rectangle.
  static const double stripFraction = 0.22;

  /// A cover wider than this many times its height is a complete jacket, not a
  /// front board. A front cover runs about 0.6 to 0.75; a back-spine-front
  /// sheet runs about 1.3 to 1.6.
  static const double wrapAspectThreshold = 1.15;

  /// The assumed trim of one board inside a wrap-around jacket. It only has to
  /// be close: it decides where the spine slice is cut, and a few pixels of
  /// error there is invisible on a 12 dp spine.
  static const double assumedBoardTrim = 0.66;

  /// The art for [coverPath], if it has already been decoded.
  static BookArt? peek(String coverPath) => _ready[coverPath];

  static Future<BookArt?> load(String coverPath, {bool mirror = false}) {
    final key = _key(coverPath, mirror);
    final ready = _ready[key];
    if (ready != null) return Future.value(ready);
    return _inFlight.putIfAbsent(key, () => _decode(coverPath, mirror));
  }

  static String _key(String coverPath, bool mirror) =>
      mirror ? '$coverPath#rtl' : coverPath;

  @visibleForTesting
  static void clear() {
    _ready.clear();
    _inFlight.clear();
  }

  /// Builds the art description for an already-decoded [image].
  ///
  /// Split out from file reading so the geometry can be tested without a file
  /// on disk, and so a caller that already holds an image can reuse it.
  static Future<BookArt> describe(ui.Image image, {bool mirror = false}) async {
    final width = image.width.toDouble();
    final height = image.height.toDouble();
    final aspect = height == 0 ? 1.0 : width / height;

    if (aspect >= wrapAspectThreshold) {
      // A complete jacket. The spine is what is left when two boards are cut
      // from the sheet.
      final boardWidth = (assumedBoardTrim * height).clamp(0.0, width / 2);
      var spineWidth = width - boardWidth * 2;
      if (spineWidth < width * 0.005 || spineWidth > width * 0.24) {
        spineWidth = width * 0.06;
      }
      final sideWidth = (width - spineWidth) / 2;
      final leading = Rect.fromLTWH(0, 0, sideWidth, height);
      final trailing = Rect.fromLTWH(width - sideWidth, 0, sideWidth, height);
      final spine = Rect.fromLTWH(sideWidth, 0, spineWidth, height);
      // The front board is the trailing half of a left-to-right jacket, and
      // the leading half of a right-to-left one.
      final front = mirror ? leading : trailing;
      final back = mirror ? trailing : leading;
      return _finish(
        image: image,
        layout: BookArtLayout.wrapAround,
        front: front,
        spine: spine,
        back: back,
      );
    }

    // A front board only. Keep source rectangles for callers that inspect the
    // description; its spine and back are painted from the cover's colour.
    final stripWidth = (width * stripFraction).clamp(1.0, width);
    final hinge = mirror
        ? Rect.fromLTWH(width - stripWidth, 0, stripWidth, height)
        : Rect.fromLTWH(0, 0, stripWidth, height);
    final far = mirror
        ? Rect.fromLTWH(0, 0, stripWidth, height)
        : Rect.fromLTWH(width - stripWidth, 0, stripWidth, height);
    return _finish(
      image: image,
      layout: BookArtLayout.frontOnly,
      front: Rect.fromLTWH(0, 0, width, height),
      spine: hinge,
      back: far,
    );
  }

  static Future<BookArt> _finish({
    required ui.Image image,
    required BookArtLayout layout,
    required Rect front,
    required Rect spine,
    required Rect back,
  }) async {
    final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final coverAverage =
        _average(pixels, image, front) ?? const Color(0xFF4A1528);
    final spineAverage = layout == BookArtLayout.frontOnly
        ? coverAverage
        : _average(pixels, image, spine) ?? coverAverage;
    final backAverage = layout == BookArtLayout.frontOnly
        ? Color.lerp(coverAverage, Colors.black, 0.08)!
        : _average(pixels, image, back) ?? coverAverage;
    return BookArt(
      image: image,
      layout: layout,
      front: front,
      spine: spine,
      back: back,
      coverAverage: coverAverage,
      spineAverage: spineAverage,
      backAverage: backAverage,
      coverInk: inkOver(coverAverage),
      spineInk: inkOver(spineAverage),
    );
  }

  static Future<BookArt?> _decode(String coverPath, bool mirror) async {
    try {
      final file = File(coverPath);
      if (!file.existsSync()) return null;
      final bytes = await file.readAsBytes();
      final descriptor = await ui.ImageDescriptor.encoded(
        await ui.ImmutableBuffer.fromUint8List(bytes),
      );
      final scale = descriptor.width >= descriptor.height
          ? decodeLongEdge / descriptor.width
          : decodeLongEdge / descriptor.height;
      final codec = scale >= 1
          ? await descriptor.instantiateCodec()
          : await descriptor.instantiateCodec(
              targetWidth: (descriptor.width * scale).round(),
              targetHeight: (descriptor.height * scale).round(),
            );
      final frame = await codec.getNextFrame();
      codec.dispose();
      descriptor.dispose();

      final art = await describe(frame.image, mirror: mirror);
      _ready[_key(coverPath, mirror)] = art;
      return art;
    } catch (error) {
      AnxLog.warning('The book model could not read its cover art: $error');
      return null;
    } finally {
      _inFlight.remove(_key(coverPath, mirror));
    }
  }

  static Color? _average(ByteData? data, ui.Image image, Rect region) {
    if (data == null) return null;
    final bytes = data.buffer.asUint8List();
    final left = region.left.floor().clamp(0, image.width - 1).toInt();
    final right = region.right.ceil().clamp(1, image.width).toInt();
    final top = region.top.floor().clamp(0, image.height - 1).toInt();
    final bottom = region.bottom.ceil().clamp(1, image.height).toInt();

    // Big covers do not need every pixel to find a mean.
    final stepX = ((right - left) / 24).ceil().clamp(1, 64).toInt();
    final stepY = ((bottom - top) / 32).ceil().clamp(1, 64).toInt();

    var red = 0, green = 0, blue = 0, counted = 0;
    for (var y = top; y < bottom; y += stepY) {
      for (var x = left; x < right; x += stepX) {
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
        255, red ~/ counted, green ~/ counted, blue ~/ counted);
  }

  static double contrast(Color foreground, Color background) {
    final first = foreground.computeLuminance();
    final second = background.computeLuminance();
    final lighter = first > second ? first : second;
    final darker = first > second ? second : first;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// The better of near-white and near-black over [background].
  ///
  /// One of the two always clears 4.5:1, because they sit at the ends of the
  /// luminance range, so printed matter on a cover is never unreadable
  /// whatever the artwork under it.
  static Color inkOver(Color background) {
    const light = Color(0xFFF7F2E8);
    const dark = Color(0xFF17120E);
    return contrast(light, background) >= contrast(dark, background)
        ? light
        : dark;
  }
}
