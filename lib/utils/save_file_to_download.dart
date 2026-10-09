import 'dart:io';
import 'package:paperfold/utils/platform_utils.dart';

import 'package:paperfold/utils/get_path/get_download_path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

String safeDownloadFileName(String name) {
  name = name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '')
      .trim();
  if (name.isEmpty) return 'export';
  if (RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
          caseSensitive: false)
      .hasMatch(name)) {
    name = '_$name';
  }
  return name;
}

Future<String?> saveFileToDownload(
    {Uint8List? bytes,
    String? sourceFilePath,
    required String fileName,
    String? mimeType}) async {
  fileName = safeDownloadFileName(fileName);

  switch (AnxPlatform.type) {
    case AnxPlatformEnum.android:
    case AnxPlatformEnum.ios:
    case AnxPlatformEnum.ohos:
      SaveFileDialogParams params = SaveFileDialogParams(
        sourceFilePath: sourceFilePath,
        data: bytes,
        mimeTypesFilter: [mimeType ?? 'application/zip'],
        fileName: fileName,
      );
      final filePath = await FlutterFileDialog.saveFile(params: params);
      return filePath;
    case AnxPlatformEnum.macos:
      bytes ??= await File(sourceFilePath!).readAsBytes();
      final saved = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
      );
      return saved?.toFilePath();
    case AnxPlatformEnum.windows:
      final downloadPath = await getDownloadPath();
      final fileSavePath = '$downloadPath/$fileName';
      final file = File(fileSavePath);

      if (!await file.exists()) {
        await file.create(recursive: true);
      }

      bytes ??= await File(sourceFilePath!).readAsBytes();
      await file.writeAsBytes(bytes);
      return fileSavePath;
  }
}
