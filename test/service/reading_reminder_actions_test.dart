import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/service/quick_capture.dart';
import 'package:paperfold/service/reading_reminder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'registers foreground actions, handles cold launch, schedules inexactly',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final calls = <MethodCall>[];
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'getNotificationAppLaunchDetails')
          return {
            'notificationLaunchedApp': true,
            'notificationResponse': {
              'notificationResponseType': 1,
              'id': 7101,
              'actionId': 'progress',
              'payload': 'paperfold://open',
            },
          };
        return true;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        (_) async => {
          'identifier': 'Europe/London',
          'name': 'London',
          'abbreviation': 'GMT',
          'offset': 0,
        },
      );
      SharedPreferences.setMockInitialValues({});
      await Prefs().initPrefs();
      final l10n = await L10n.delegate.load(const Locale('en'));
      try {
        expect(Prefs().readingReminderEnabled, isFalse);
        await ReadingReminder.schedule(l10n, 1200);
        final schedule =
            calls
                    .singleWhere((call) => call.method == 'zonedSchedule')
                    .arguments
                as Map;
        expect(schedule['payload'], 'paperfold://open');
        expect(
          schedule['platformSpecifics']['scheduleMode'],
          'inexactAllowWhileIdle',
        );
        final android = schedule['platformSpecifics'] as Map;
        final actions = android['actions'] as List;
        expect(actions.map((a) => a['id']), ['progress', 'note']);
        expect(actions.every((a) => a['showsUserInterface'] == true), isTrue);
        expect(
          calls.any((c) => c.method.toLowerCase().contains('permission')),
          isFalse,
        );
        expect(QuickCapture.take()!.kind, QuickCaptureKind.progress);
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('didReceiveNotificationResponse', {
              'notificationResponseType': 1,
              'notificationId': 7101,
              'actionId': 'note',
              'payload': 'paperfold://open',
            }),
          ),
          (_) {},
        );
        expect(QuickCapture.take()!.kind, QuickCaptureKind.note);
        expect(ReadingReminder.actions(l10n).map((a) => a.title), [
          'Log pages',
          'Write a note',
        ]);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_timezone'),
          null,
        );
        QuickCapture.take();
      }
    },
  );
}
