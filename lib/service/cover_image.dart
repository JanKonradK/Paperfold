import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/platform_utils.dart';

/// The largest cover file Paperfold reads. A phone photo is 2 to 8 MiB.
const coverMaxBytes = 20 * 1024 * 1024;

/// The largest cover Paperfold decodes, in pixels. This stops a small file
/// that declares a very large image from filling memory.
const coverMaxPixels = 50 * 1000 * 1000;

/// The long edge of a saved cover. The largest cover view on a tablet needs
/// about this many pixels.
const coverLongEdge = 2048;

/// Paperfold cannot use the file as a cover.
class CoverImageException implements Exception {
  const CoverImageException(this.reason);
  final String reason;

  @override
  String toString() => 'CoverImageException: $reason';
}

/// True when the device can take a photo for a cover.
bool get canTakeCoverPhoto => AnxPlatform.isAndroid || AnxPlatform.isIOS;

/// Lets the reader choose a JPG or PNG file. Returns null on cancel.
Future<File?> chooseCoverFile() async {
  final result = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png'],
  );
  final picked = result?.path;
  return picked == null ? null : File(picked);
}

/// Opens the camera. Returns null on cancel.
Future<File?> takeCoverPhoto() async {
  final photo = await ImagePicker().pickImage(source: ImageSource.camera);
  return photo == null ? null : File(photo.path);
}

bool _isJpeg(Uint8List b) =>
    b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF;

bool _isPng(Uint8List b) =>
    b.length > 8 &&
    b[0] == 0x89 &&
    b[1] == 0x50 &&
    b[2] == 0x4E &&
    b[3] == 0x47 &&
    b[4] == 0x0D &&
    b[5] == 0x0A &&
    b[6] == 0x1A &&
    b[7] == 0x0A;

/// Makes a clean cover from JPG or PNG [bytes].
///
/// The result has the camera rotation applied, a long edge of at most
/// [coverLongEdge], and no EXIF, GPS, or text metadata. A PNG stays a PNG, so
/// a transparent cover keeps its transparency.
@visibleForTesting
({Uint8List bytes, String extension}) normaliseCover(Uint8List bytes) {
  if (bytes.length > coverMaxBytes) {
    throw const CoverImageException('too large');
  }
  final png = _isPng(bytes);
  if (!png && !_isJpeg(bytes)) {
    throw const CoverImageException('not a JPG or PNG');
  }
  final decoder = png ? img.PngDecoder() : img.JpegDecoder();
  final info = decoder.startDecode(bytes);
  if (info == null || info.width <= 0 || info.height <= 0) {
    throw const CoverImageException('damaged');
  }
  if (info.width * info.height > coverMaxPixels) {
    throw const CoverImageException('too many pixels');
  }
  final decoded = decoder.decode(bytes);
  if (decoded == null) throw const CoverImageException('damaged');

  var image = img.bakeOrientation(decoded);
  final longEdge = image.width >= image.height ? image.width : image.height;
  if (longEdge > coverLongEdge) {
    image = image.width >= image.height
        ? img.copyResize(image,
            width: coverLongEdge, interpolation: img.Interpolation.average)
        : img.copyResize(image,
            height: coverLongEdge, interpolation: img.Interpolation.average);
  }
  image
    ..exif = img.ExifData()
    ..textData = null;
  return png
      ? (bytes: img.encodePng(image), extension: 'png')
      : (bytes: img.encodeJpg(image, quality: 90), extension: 'jpg');
}

/// Writes a clean copy of [source] to the library cover folder.
///
/// Returns the library-relative path, `cover/<stem>.<jpg|png>`. Throws
/// [CoverImageException] when the file is not a usable JPG or PNG.
Future<String> saveCoverImage(File source, String stem) async {
  if (await source.length() > coverMaxBytes) {
    throw const CoverImageException('too large');
  }
  final bytes = await source.readAsBytes();
  final cover = await compute(normaliseCover, bytes);
  final safeStem = stem.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  final relative = 'cover/$safeStem.${cover.extension}';
  await File(getBasePath(relative)).writeAsBytes(cover.bytes, flush: true);
  return relative;
}
