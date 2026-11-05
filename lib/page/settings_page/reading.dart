import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/service/reading_reminder.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/widgets/reading_page/more_settings/other_settings.dart';
import 'package:paperfold/widgets/reading_page/more_settings/reading_settings.dart';
import 'package:paperfold/widgets/reading_page/more_settings/style_settings.dart';
import 'package:paperfold/widgets/settings/settings_section.dart';
import 'package:paperfold/widgets/settings/settings_tile.dart';
import 'package:paperfold/widgets/settings/settings_title.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReadingSettings extends ConsumerStatefulWidget {
  const ReadingSettings({super.key});

  @override
  ConsumerState<ReadingSettings> createState() => _ReadingSettingsState();
}

class _ReadingSettingsState extends ConsumerState<ReadingSettings> {
  bool _busy = false;

  void _showMessage(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setReminder(bool enabled) async {
    final l10n = L10n.of(context);
    setState(() => _busy = true);
    try {
      if (enabled) {
        // Ask only now, when the reader asks for the reminder.
        if (!await ReadingReminder.requestPermission()) {
          _showMessage(l10n.reminderPermissionDenied);
          return;
        }
        await ReadingReminder.schedule(l10n, Prefs().readingReminderMinutes);
      } else {
        await ReadingReminder.cancel();
      }
      Prefs().readingReminderEnabled = enabled;
    } catch (e) {
      AnxLog.warning('Reminder: could not change: $e');
      _showMessage(l10n.commonFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime() async {
    final l10n = L10n.of(context);
    final minutes = Prefs().readingReminderMinutes;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (time == null || !mounted) return;
    final next = time.hour * 60 + time.minute;
    try {
      if (Prefs().readingReminderEnabled) {
        await ReadingReminder.schedule(l10n, next);
      }
      Prefs().readingReminderMinutes = next;
      if (mounted) setState(() {});
    } catch (e) {
      AnxLog.warning('Reminder: could not change the time: $e');
      _showMessage(l10n.commonFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final minutes = Prefs().readingReminderMinutes;
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return settingsSections(sections: [
      if (ReadingReminder.supported)
        SettingsSection(title: Text(l10n.reminderSection), tiles: [
          SettingsTile.switchTile(
            key: const ValueKey('reading-reminder-switch'),
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l10n.reminderTitle),
            description: Text(l10n.reminderDescription),
            initialValue: Prefs().readingReminderEnabled,
            enabled: !_busy,
            onToggle: _setReminder,
          ),
          SettingsTile.navigation(
            key: const ValueKey('reading-reminder-time'),
            leading: const Icon(Icons.schedule_outlined),
            title: Text(l10n.reminderTime),
            value: Text(time.format(context)),
            onPressed: (_) => _pickTime(),
          ),
        ]),
      SettingsSection(title: Text(L10n.of(context).readingPageReading), tiles: [
        CustomSettingsTile(child: ReadingMoreSettings()),
      ]),
      SettingsSection(title: Text(L10n.of(context).readingPageStyle), tiles: [
        CustomSettingsTile(child: StyleSettings()),
      ]),
      SettingsSection(title: Text(L10n.of(context).readingPageOther), tiles: [
        CustomSettingsTile(child: OtherSettings()),
      ]),
    ]);
  }
}
