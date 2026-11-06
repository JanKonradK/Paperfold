import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/service/reader_window.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    messenger.setMockMethodCallHandler(ReaderWindow.channel, (call) async {
      calls.add(call);
      if (call.method == 'rotation') return 1;
      return null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(ReaderWindow.channel, null);
  });
  test(
    'brightness is bounded and System releases the window override',
    () async {
      final window = ReaderWindow();
      await window.setBrightness(0);
      expect(calls.last.arguments, 0.05);
      await window.setBrightness(2);
      expect(calls.last.arguments, 1);
      await window.setBrightness(null);
      expect(calls.last.arguments, isNull);
      expect(window.brightness, isNull);
      await window.restore();
    },
  );
  test(
    'exit waits for in-flight adjustment and ignores later requests',
    () async {
      final pending = Completer<void>();
      messenger.setMockMethodCallHandler(ReaderWindow.channel, (call) async {
        calls.add(call);
        if (call.method == 'brightness') await pending.future;
        return null;
      });
      final window = ReaderWindow();
      final adjustment = window.setBrightness(0.4);
      final exit = window.restore();
      await window.setBrightness(0.8);
      pending.complete();
      await adjustment;
      await exit;
      expect(calls.map((c) => c.method), ['brightness', 'restore']);
    },
  );
  test(
    'refused rotation preserves system state and releases overrides',
    () async {
      messenger.setMockMethodCallHandler(ReaderWindow.channel, (call) async {
        calls.add(call);
        return null;
      });
      final window = ReaderWindow();
      await expectLater(
        window.lockRotation(true),
        throwsA(isA<PlatformException>()),
      );
      expect(window.rotationLocked, isFalse);
      expect(calls.last.method, 'restore');
      await window.restore();
    },
  );
  test('resume reflects activity recreation clearing window state', () async {
    messenger.setMockMethodCallHandler(ReaderWindow.channel, (call) async {
      if (call.method == 'state') return {'brightness': -1.0, 'locked': false};
      return null;
    });
    final window = ReaderWindow();
    await window.setBrightness(0.7);
    await window.refresh();
    expect(window.brightness, isNull);
    expect(window.rotationLocked, isFalse);
    await window.restore();
  });
}
