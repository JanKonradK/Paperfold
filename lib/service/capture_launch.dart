import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/providers/current_reading.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:paperfold/service/quick_capture.dart';
import 'package:paperfold/service/home_widgets.dart';
import 'package:paperfold/service/reading_reminder.dart';
import 'package:paperfold/utils/log/common.dart';

/// Listen after HomePage is ready, then call [CaptureLaunch.takeOpenBook]. A null bookId
/// means continue the current/last-read book. Resolve the book and use the
/// existing pushToReadingPage path; paper books request progress capture.
class OpenBookRequest {
  const OpenBookRequest(this.bookId, this.source);
  final int? bookId;
  final String source;
}

abstract final class CaptureLaunch {
  static const channel = MethodChannel('com.paperfold.app/capture');
  static final openBook = ValueNotifier<OpenBookRequest?>(null);

  static OpenBookRequest? takeOpenBook() {
    final request = openBook.value;
    openBook.value = null;
    return request;
  }

  /// Both warm and cold launches use the same strict parser. Notification
  /// action identifiers override only a valid reminder body payload.
  static bool handle(
    String? payload, {
    String source = 'widget',
    String? action,
  }) {
    try {
      return _handle(payload, source: source, action: action);
    } on FormatException {
      return false;
    }
  }

  static bool _handle(
    String? payload, {
    required String source,
    String? action,
  }) {
    if (payload == null) return false;
    final uri = Uri.tryParse(payload);
    if (uri == null ||
        uri.scheme != 'paperfold' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasFragment ||
        !{'capture', 'open'}.contains(uri.host)) {
      return false;
    }
    if (uri.queryParametersAll.values.any((values) => values.length != 1)) {
      return false;
    }
    final rawBook = uri.queryParameters['book'];
    final book = rawBook == null ? null : int.tryParse(rawBook);
    if (rawBook != null &&
        (!RegExp(r'^[0-9]+$').hasMatch(rawBook) || book == null || book <= 0)) {
      return false;
    }
    String? kind = uri.queryParameters['kind'];
    if (action != null && action.isNotEmpty) {
      if (source != 'notification' ||
          uri.host != 'open' ||
          !{'progress', 'note'}.contains(action)) {
        return false;
      }
      kind = action;
    } else if (uri.host == 'open') {
      if (kind != null) return false;
      openBook.value = OpenBookRequest(book, source);
      return true;
    }
    final kinds = {
      for (final value in QuickCaptureKind.values) value.name: value,
    };
    if (!kinds.containsKey(kind)) return false;
    QuickCapture.request(
      QuickCaptureRequest(kind: kinds[kind]!, bookId: book, source: source),
    );
    return true;
  }

  /// The listener belongs to the app's WidgetRef and is disposed with it.
  static void observe(WidgetRef ref) {
    ref.listenManual(currentReadingProvider, (_, next) {
      HomeWidgets.setActiveBook(next.isReading ? next.book?.id : null);
    });
  }

  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      try {
        channel.setMethodCallHandler((call) async {
          if (call.method == 'launch' && call.arguments is String) {
            handle(call.arguments as String);
          }
        });
        handle(await channel.invokeMethod<String>('takeLaunch'));
        HomeWidgets.initialize();
      } catch (error) {
        AnxLog.warning('Capture: could not read widget launch: $error');
      }
    }
    if (ReadingReminder.supported) {
      try {
        await ReadingReminder.initializeLaunch();
      } catch (error) {
        AnxLog.warning('Capture: could not read notification launch: $error');
      }
    }
  }
}
