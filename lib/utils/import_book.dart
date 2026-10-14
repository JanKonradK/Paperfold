import 'dart:async';
import 'dart:io';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/log/common.dart';

Future<String> saveImageToLocal(String? imageFile, String name) async {
  if (imageFile == null || imageFile.isEmpty) {
    return '';
  }
  try {
    final data = UriData.parse(imageFile);
    final extension = const {
      'image/png': 'png',
      'image/jpeg': 'jpg',
      'image/gif': 'gif',
      'image/webp': 'webp',
      'image/bmp': 'bmp',
      'image/svg+xml': 'svg',
    }[data.mimeType.toLowerCase()];
    if (extension == null) return '';

    name = '$name.$extension';
    final path = getBasePath(name);

    final file = File(path);
    await file.writeAsBytes(data.contentAsBytes());

    return name;
  } catch (e) {
    AnxLog.severe('Error saving image\n$e');
    return '';
  }
}
