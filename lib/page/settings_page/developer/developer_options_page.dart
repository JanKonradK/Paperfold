import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/settings_page/developer/vibration_test_page.dart';
import 'package:flutter/material.dart';

class DeveloperOptionsPage extends StatelessWidget {
  const DeveloperOptionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).settingsDeveloperOptions),
      ),
      body: AnimatedBuilder(
        animation: Prefs(),
        builder: (context, _) {
          final enabled = Prefs().developerOptionsEnabled;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              SwitchListTile(
                title:
                    Text(L10n.of(context).settingsDeveloperOptionsEnable),
                subtitle: Text(L10n.of(context)
                    .settingsDeveloperOptionsEnableDescription),
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
                leading: const Icon(Icons.vibration_outlined),
                title: Text(L10n.of(context).settingsDeveloperVibrationTest),
                subtitle: Text(L10n.of(context)
                    .settingsDeveloperVibrationTestDescription),
                trailing: const Icon(Icons.chevron_right),
                minTileHeight: 56,
                // Material, like the rest of the settings tree. A Cupertino
                // route here brought an iOS transition and an iOS back
                // gesture into a Material application.
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const VibrationTestPage(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
