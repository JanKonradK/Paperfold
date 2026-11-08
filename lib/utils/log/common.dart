import 'dart:io';

import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Log messages go to the debug console only. Release builds keep no log.
class AnxLog {
  static final log = Logger('Paperfold');

  static Future<void> init() async {
    Logger.root.level = kDebugMode ? Level.ALL : Level.OFF;
    Logger.root.onRecord.listen((record) {
      final colorCode = switch (record.level) {
        Level.SEVERE => '[31m',
        Level.WARNING => '[33m',
        Level.INFO => '[34m',
        _ => '',
      };
      debugPrint(
          '$colorCode${record.level.name}: ${record.time}: ${record.message} [0m');
      if (record.error != null) debugPrint('$colorCode${record.error} [0m');
      if (record.stackTrace != null) {
        debugPrint('$colorCode${record.stackTrace} [0m');
      }
    });
    // Earlier versions kept a log file. Nothing reads it now.
    final oldLog = File('${await getAnxDocumentsPath()}/paperfold.log');
    if (await oldLog.exists()) await oldLog.delete();
  }

  static info(String message, [Object? error, StackTrace? stackTrace]) {
    log.info(message, error, stackTrace);
  }

  static warning(String message, [Object? error, StackTrace? stackTrace]) {
    log.warning(message, error, stackTrace);
  }

  static severe(String message, [Object? error, StackTrace? stackTrace]) {
    stackTrace ??= StackTrace.current;
    log.severe(message, error, stackTrace);
  }
}
