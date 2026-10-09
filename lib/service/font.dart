import 'dart:io';

import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:file_picker/file_picker.dart';

Future<void> importFont() async {
  final files = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['ttf', 'otf'],
  );

  for (var file in files) {
    final fontDir = getFontDir();
    File newFile = File(file.path!);
    newFile.copy('${fontDir.path}/${file.name}');

    AnxToast.show(L10n.of(navigatorKey.currentContext!).commonSuccess);
  }
}
