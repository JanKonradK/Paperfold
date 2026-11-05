import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/platform_utils.dart';
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
  static bool get supported => AnxPlatform.isAndroid || AnxPlatform.isIOS;

  static Future<void> _init() async {
    if (_ready) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      // An unknown zone keeps UTC. The reminder then moves with UTC offsets.
      AnxLog.warning('Reminder: time zone not found: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_launcher_monochrome'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Asks the system for permission to show notifications.
  static Future<bool> requestPermission() async {
    await _init();
    if (AnxPlatform.isAndroid) {
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
        ),
        iOS: const DarwinNotificationDetails(),
      ),
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
