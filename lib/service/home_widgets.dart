import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/service/capture_launch.dart';
import 'package:paperfold/utils/log/common.dart';

/// One atomic snapshot, shared with the native providers. No alarms or polling.
abstract final class HomeWidgets {
  static Timer? _debounce;
  static bool _started = false;
  static int? _activeBook;
  static String? _lastSnapshot;

  static void initialize() {
    if (_started || !Platform.isAndroid) return;
    _started = true;
    Prefs().addListener(refresh);
    WidgetsBinding.instance.addObserver(_WidgetAppearanceObserver());
    refresh();
  }

  /// Also called after a successful DAO write. Bursts collapse into one query.
  static void refresh() {
    if (!_started) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        Book? current;
        if (_activeBook != null) {
          current = await bookDao.querySingle(
            BookDao.table,
            mapper: Book.fromDb,
            where: 'id = ? AND is_deleted = 0',
            whereArgs: [_activeBook],
          );
        }
        current ??= await bookDao.querySingle(
          BookDao.table,
          mapper: Book.fromDb,
          where: 'is_deleted = 0 AND status = ?',
          whereArgs: [BookStatus.reading.databaseValue],
          orderBy: 'update_time DESC, id DESC',
        );
        final encoded = jsonEncode(
          snapshot(
            current,
            burgundy:
                Prefs().appThemeMode == 'burgundy' ||
                Prefs().appThemeMode == 'dark' ||
                (Prefs().appThemeMode == 'auto' &&
                    WidgetsBinding
                            .instance
                            .platformDispatcher
                            .platformBrightness ==
                        Brightness.dark),
          ),
        );
        if (encoded == _lastSnapshot) return;
        await CaptureLaunch.channel.invokeMethod<void>(
          'updateWidgets',
          encoded,
        );
        _lastSnapshot = encoded;
      } catch (error) {
        AnxLog.warning('Widgets: could not update: $error');
      }
    });
  }

  static void setActiveBook(int? id) {
    if (_activeBook == id) return;
    _activeBook = id;
    refresh();
  }

  @visibleForTesting
  static Map<String, Object?> snapshot(Book? book, {required bool burgundy}) {
    final fraction = book?.readingPercentage ?? 0;
    final progress = fraction.isFinite
        ? (fraction.clamp(0, 1) * 100).round()
        : 0;
    return {
      'book': book?.id,
      'title': book?.title ?? '',
      'cover': book == null || book.coverPath.isEmpty ? '' : book.coverFullPath,
      'progress': progress,
      'physical': book?.isPhysical ?? false,
      'ground': burgundy ? '#3D1723' : '#F3EFE8',
      'text': burgundy ? '#F3EBDD' : '#160F0C',
      'accent': burgundy ? '#C8B28F' : '#391214',
    };
  }
}

class _WidgetAppearanceObserver extends WidgetsBindingObserver {
  @override
  void didChangePlatformBrightness() => HomeWidgets.refresh();
}
