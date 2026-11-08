
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

  return FlutterFileDialog.saveFile(
    params: SaveFileDialogParams(
      sourceFilePath: sourceFilePath,
      data: bytes,
      mimeTypesFilter: [mimeType ?? 'application/zip'],
      fileName: fileName,
    ),
  );
}
