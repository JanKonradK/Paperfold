import 'dart:io';

import 'package:paperfold/service/capture_launch.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// One daily notification at a time the reader selects.
///
/// Android may deliver it a few minutes late: Paperfold does not ask for the
/// exact-alarm permission for a reminder. The system restores it after a
/// restart; Paperfold schedules it again at each start, which also follows a
/// change of time zone.
abstract final class ReadingReminder {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _id = 7101;
  static const _channelId = 'reading_reminder';
  static bool _ready = false;

  /// Desktop systems have no background delivery for a closed app.
  static bool get supported => Platform.isAndroid || Platform.isIOS;

  static Future<void> initializeLaunch() => _init();

  static Future<void>? _initializing;
  static Future<void> _init() =>
      _initializing ??= _initialize().onError<Object>((error, stack) {
        _initializing = null;
        Error.throwWithStackTrace(error, stack);
      });

  static Future<void> _initialize() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      // An unknown zone keeps UTC. The reminder then moves with UTC offsets.
      AnxLog.warning('Reminder: time zone not found: $e');
    }
    final l10n = await L10n.delegate.load(Prefs().locale ?? const Locale('en'));
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings(
          '@drawable/ic_launcher_monochrome',
        ),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              'reading_capture',
              actions: [
                DarwinNotificationAction.plain(
                  'progress',
                  l10n.captureLogPages,
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  'note',
                  l10n.captureWriteNote,
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: _respond,
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse != null) {
      _respond(launch!.notificationResponse!);
    }
    _ready = true;
  }

  static void _respond(NotificationResponse response) {
    CaptureLaunch.handle(
      response.payload,
      source: 'notification',
      action: response.actionId,
    );
  }

  @visibleForTesting
  static List<AndroidNotificationAction> actions(L10n l10n) => [
    AndroidNotificationAction(
      'progress',
      l10n.captureLogPages,
      showsUserInterface: true,
    ),
    AndroidNotificationAction(
      'note',
      l10n.captureWriteNote,
      showsUserInterface: true,
    ),
  ];

  /// Asks the system for permission to show notifications.
  static Future<bool> requestPermission() async {
    await _init();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true) ??
        false;
  }

  /// The next local time at [minutes] after midnight, today or tomorrow.
  @visibleForTesting
  static tz.TZDateTime nextAt(int minutes, tz.TZDateTime now) {
    var next = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (!next.isAfter(now)) {
      next = tz.TZDateTime(
        now.location,
        now.year,
        now.month,
        now.day + 1,
        minutes ~/ 60,
        minutes % 60,
      );
    }
    return next;
  }

  /// Replaces the reminder with one at [minutes] after midnight.
  static Future<void> schedule(L10n l10n, int minutes) async {
    await _init();
    await _plugin.cancel(id: _id);
    await _plugin.zonedSchedule(
      id: _id,
      title: l10n.reminderNotificationTitle,
      body: l10n.reminderNotificationBody,
      scheduledDate: nextAt(minutes, tz.TZDateTime.now(tz.local)),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          l10n.reminderChannelName,
          category: AndroidNotificationCategory.reminder,
          actions: actions(l10n),
        ),
        iOS: const DarwinNotificationDetails(
          categoryIdentifier: 'reading_capture',
        ),
      ),
      payload: 'paperfold://open',
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel() async {
    await _init();
    await _plugin.cancel(id: _id);
  }

  /// Schedules the saved reminder again. Call it once the app has started.
  static Future<void> restore(L10n l10n) async {
    if (!supported || !Prefs().readingReminderEnabled) return;
    try {
      await schedule(l10n, Prefs().readingReminderMinutes);
    } catch (e) {
      AnxLog.warning('Reminder: could not restore: $e');
    }
  }
}
