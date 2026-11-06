import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:paperfold/service/cover_image.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';

/// A page photo uses the same signature, size, rotation, and metadata guards
/// as covers. Keep a relative path so backup restores remain portable.
Future<String> savePagePhoto(File source) async {
  if (await source.length() > coverMaxBytes) {
    throw const CoverImageException('too large');
  }
  final clean = await compute(normaliseCover, await source.readAsBytes());
  final relative =
      'journal_photos/${DateTime.now().microsecondsSinceEpoch}.${clean.extension}';
  final file = File(getBasePath(relative));
  await file.parent.create(recursive: true);
  await file.writeAsBytes(clean.bytes, flush: true);
  return relative;
}
