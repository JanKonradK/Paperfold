import 'dart:ui';

import 'package:paperfold/utils/log/common.dart';
import 'package:material_ui/material_ui.dart';

class AnxError {
  static Future<void> init() async {
    AnxLog.info('AnxError init');
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AnxLog.severe(details.exceptionAsString(), details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      AnxLog.severe(error.toString(), stack);
      return false;
    };
  }
}
