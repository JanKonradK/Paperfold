import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Window settings belong to one reader session, never to device preferences.
class ReaderWindow extends ChangeNotifier {
  static const channel = MethodChannel('com.paperfold.app/reader_window');
  double? brightness;
  bool rotationLocked = false;
  bool _closed = false;
  Future<void> _pending = Future.value();

  bool get supported => defaultTargetPlatform == TargetPlatform.android;

  Future<void> _run(Future<void> Function() action) {
    if (!supported || _closed) return Future.value();
    final result = _pending.then((_) async {
      try {
        await action();
      } catch (_) {
        try {
          await SystemChrome.setPreferredOrientations([]);
          await channel.invokeMethod<void>('restore');
        } catch (error) {
          debugPrint('Reader window reset failed: $error');
        }
        brightness = null;
        rotationLocked = false;
        notifyListeners();
        rethrow;
      }
    });
    // Keep exit/reset ordered after in-flight slider requests, including errors.
    _pending = result.catchError((Object _) {});
    return result;
  }

  Future<void> setBrightness(double? value) => _run(() async {
    await channel.invokeMethod<void>('brightness', value?.clamp(0.05, 1.0));
    brightness = value?.clamp(0.05, 1.0);
    notifyListeners();
  });

  Future<void> lockRotation(bool lock) => _run(() async {
    if (lock) {
      final rotation = await channel.invokeMethod<int>('rotation');
      if (rotation == null) {
        throw PlatformException(code: 'ROTATION_UNAVAILABLE');
      }
      final orientation = [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeRight,
      ][rotation];
      await SystemChrome.setPreferredOrientations([orientation]);
    } else {
      await SystemChrome.setPreferredOrientations([]);
      await channel.invokeMethod<void>('restoreOrientation');
    }
    rotationLocked = lock;
    notifyListeners();
  });

  /// Lets the screen drop to its slowest refresh rate while the page is still.
  /// [restore] ends it.
  Future<void> lowRefresh() async {
    if (!supported || _closed) return;
    try {
      await channel.invokeMethod<void>('lowRefresh');
    } on PlatformException catch (error) {
      debugPrint('Reader low refresh failed: $error');
    } on MissingPluginException {
      // No Android host in widget tests.
    }
  }

  Future<void> refresh() => _run(() async {
    try {
      final state = await channel.invokeMapMethod<String, dynamic>('state');
      final value = state?['brightness'] as num?;
      brightness = value != null && value >= 0 ? value.toDouble() : null;
      rotationLocked = state?['locked'] == true;
      notifyListeners();
    } on PlatformException catch (error) {
      debugPrint('Reader window refresh failed: $error');
    } on MissingPluginException {
      // No Android host in widget tests.
    }
  });

  Future<void> restore() async {
    if (_closed) return;
    _closed = true;
    await _pending;
    if (!supported) return;
    try {
      await SystemChrome.setPreferredOrientations([]);
      await channel.invokeMethod<void>('restore');
    } on PlatformException catch (error) {
      debugPrint('Reader window restore failed: $error');
    } on MissingPluginException {
      // The Android activity may already have been destroyed.
    }
  }
}
