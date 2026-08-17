import 'dart:async';

import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/page/settings_page/developer/developer_options_page.dart';
import 'package:paperfold/utils/env_var.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:paperfold/widgets/paperfold_logo_mark.dart';
import 'package:paperfold/widgets/settings/link_icon.dart';
import 'package:paperfold/utils/check_update.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:url_launcher/url_launcher.dart';

class About extends StatefulWidget {
  const About({
    super.key,
    this.leadingColor = false,
  });
  final bool leadingColor;

  @override
  State<About> createState() => _AboutState();
}

class _AboutState extends State<About> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(L10n.of(context).appAbout),
      leading: Icon(Icons.info_outline,
          color: widget.leadingColor
              ? Theme.of(context).colorScheme.primary
              : null),
      onTap: () => openAboutDialog(),
    );
  }
}

const int _developerUnlockTapThreshold = 7;
int _developerUnlockTapCount = 0;
Timer? _developerUnlockResetTimer;

void _handleDeveloperUnlockTap(BuildContext context) {
  _developerUnlockTapCount++;
  _developerUnlockResetTimer?.cancel();
  _developerUnlockResetTimer =
      Timer(const Duration(seconds: 2), () => _developerUnlockTapCount = 0);

  final alreadyEnabled = Prefs().developerOptionsEnabled;
  if (_developerUnlockTapCount < _developerUnlockTapThreshold) {
    return;
  }

  _developerUnlockTapCount = 0;
  if (!alreadyEnabled) {
    Prefs().developerOptionsEnabled = true;
    AnxToast.show(L10n.of(context).settingsDeveloperOptionsEnabledToast);
  }

  final navigator = Navigator.of(context, rootNavigator: true);
  if (navigator.canPop()) {
    navigator.pop();
  }
  Future.microtask(_openDeveloperOptionsPage);
}

void _openDeveloperOptionsPage() {
  final BuildContext? navContext = navigatorKey.currentContext;
  if (navContext == null) return;
  Navigator.of(navContext).push(
    CupertinoPageRoute(
      fullscreenDialog: false,
      builder: (context) => const DeveloperOptionsPage(),
    ),
  );
}

Future<void> openAboutDialog() async {
  final pubspecContent = await rootBundle.loadString('pubspec.yaml');
  final pubspec = Pubspec.parse(pubspecContent);
  final version = pubspec.version.toString();

  showDialog(
    context: navigatorKey.currentContext!,
    builder: (BuildContext context) {
      return AlertDialog(
          content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          minWidth: 300,
        ),
        child: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The fork's own name, and the mark that goes with it. The
                // dialog still said "Anx" at 50 points, directly under the
                // Paperfold mark on the settings page that opened it.
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                  child: Column(
                    children: [
                      PaperfoldLogoMark(
                        size: 64,
                        tint: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        L10n.of(context).appName,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  title: Text(L10n.of(context).appVersion),
                  subtitle: Text(version + (kDebugMode ? ' (debug)' : '')),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: version));
                    AnxToast.show(L10n.of(context).notesPageCopied);
                    _handleDeveloperUnlockTap(context);
                  },
                ),
                if (EnvVar.enableCheckUpdate)
                  ListTile(
                      title: Text(L10n.of(context).aboutCheckForUpdates),
                      onTap: () => checkUpdate(true)),
                ListTile(
                  title: Text(L10n.of(context).appLicense),
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: L10n.of(context).appName,
                      applicationVersion: version,
                    );
                  },
                ),
                ListTile(
                  title: Text(L10n.of(context).appAuthor),
                  onTap: () {
                    launchUrl(
                      Uri.parse(
                          'https://github.com/JanKonradK/Paperfold/graphs/contributors'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
                const Divider(),
                // Two links, and both are Paperfold's own.
                //
                // This row used to carry the upstream project's website, its
                // repository, its Xiaohongshu profile and its QQ group. A fork
                // that has become its own application should not be sending its
                // readers to another project's community.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      linkIcon(
                          icon: Icon(
                            IonIcons.logo_github,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          url: 'https://github.com/JanKonradK/Paperfold',
                          mode: LaunchMode.externalApplication),
                      if (EnvVar.showTelegramLink)
                        linkIcon(
                            icon: Icon(
                              Icons.telegram,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            url: 'https://t.me/Paperfold',
                            mode: LaunchMode.externalApplication),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
    },
  );
}
