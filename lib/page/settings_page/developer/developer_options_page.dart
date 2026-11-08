import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/settings_page/subpage/log_page.dart';
import 'package:material_ui/material_ui.dart';

class DeveloperOptionsPage extends StatelessWidget {
  const DeveloperOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).settingsDeveloperOptions)),
      body: AnimatedBuilder(
        animation: Prefs(),
        builder: (context, _) {
          final enabled = Prefs().developerOptionsEnabled;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: PaperfoldSpace.xs),
            children: [
              SwitchListTile(
                title: Text(L10n.of(context).settingsDeveloperOptionsEnable),
                subtitle: Text(
                  L10n.of(context).settingsDeveloperOptionsEnableDescription,
                ),
                value: enabled,
                onChanged: (value) {
                  Prefs().developerOptionsEnabled = value;
                  if (!value && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(L10n.of(context).settingsAdvancedLog),
                trailing: const Icon(Icons.chevron_right),
                minTileHeight: 56,
                // Material, like the rest of the settings tree.
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const LogPage(),
                    ),
                  );
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.delete_forever_outlined),
                title: Text(L10n.of(context).settingsAdvancedClearLogWhenStart),
                value: Prefs().clearLogWhenStart,
                onChanged: Prefs().saveClearLogWhenStart,
              ),
            ],
          );
        },
      ),
    );
  }
}
