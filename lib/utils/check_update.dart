import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/utils/app_version.dart';
import 'package:paperfold/utils/env_var.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/platform_utils.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:paperfold/widgets/common/container/filled_container.dart';
import 'package:paperfold/widgets/markdown/styled_markdown.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

final _releasePage = Uri.parse(
  'https://github.com/JanKonradK/Paperfold/releases/latest',
);
const _installChannel = MethodChannel('com.paperfold.app/install_info');

/// Downloads the release package and gives it to the system installer, which
/// asks the reader to confirm. An update replaces the app and keeps the books.
Future<void> _installUpdate(String url) async {
  final progress = ValueNotifier<double?>(null);
  SmartDialog.show(
    tag: 'update',
    builder: (_) => Center(
      child: FilledContainer(
        child: ValueListenableBuilder(
          valueListenable: progress,
          builder: (_, value, _) => CircularProgressIndicator(value: value),
        ),
      ),
    ),
  );
  try {
    // The FileProvider in AndroidManifest.xml shares only this folder.
    final apk = path.join(
      (await getAnxTempDir()).path,
      'updates',
      'Paperfold.apk',
    );
    await Dio().download(
      url,
      apk,
      onReceiveProgress: (received, total) {
        if (total > 0) progress.value = received / total;
      },
    );
    await _installChannel.invokeMethod('installUpdate', apk);
  } catch (e) {
    AnxLog.severe('Update: could not download or install $e');
    AnxToast.show(L10n.of(navigatorKey.currentContext!).downloadFailed);
    launchUrl(_releasePage, mode: LaunchMode.externalApplication);
  } finally {
    SmartDialog.dismiss(tag: 'update');
  }
}

Future<void> checkUpdate(bool manualCheck) async {
  if (!EnvVar.enableCheckUpdate) {
    return;
  }
  // if is today
  if (!manualCheck &&
      DateTime.now().difference(Prefs().lastShowUpdate) <
          const Duration(days: 1)) {
    return;
  }
  Prefs().lastShowUpdate = DateTime.now();

  BuildContext context = navigatorKey.currentContext!;
  Response response;
  try {
    // GitHub's own releases endpoint, so the check needs no service of its
    // own. It used to ask the upstream project's API, which answers with the
    // upstream project's version: Paperfold told its readers to update to a
    // different application.
    response = await Dio().get(
      'https://api.github.com/repos/JanKonradK/Paperfold/releases/latest',
    );
  } on DioException catch (e) {
    // GitHub answers 404 while a repository has no published release. That is
    // not a failure to check: it is a complete answer, and it means there is
    // nothing newer than what the reader is holding. Reported as an error, it
    // told everybody the update check was broken until the first release.
    if (e.response?.statusCode == 404) {
      if (manualCheck) {
        AnxToast.show(L10n.of(context).commonNoNewVersion);
      }
      AnxLog.info('Update: no release published yet');
      return;
    }
    if (manualCheck) {
      AnxToast.show(L10n.of(context).commonFailed);
    }
    AnxLog.severe('Update: Failed to check for updates $e');
    return;
  } catch (e) {
    if (manualCheck) {
      AnxToast.show(L10n.of(context).commonFailed);
    }
    AnxLog.severe('Update: Failed to check for updates $e');
    return;
  }
  final tag = response.data['tag_name'].toString();
  String newVersion = tag.startsWith('v') ? tag.substring(1) : tag;
  String currentVersion = (await getAppVersion()).split('+').first;
  AnxLog.info('Update: new version $newVersion');

  List<String> newVersionList = newVersion.split('.');
  List<String> currentVersionList = currentVersion.split('.');
  AnxLog.info(
    'Current version: $currentVersionList, New version: $newVersionList',
  );
  bool needUpdate = false;
  for (int i = 0; i < newVersionList.length; i++) {
    int newVer = int.parse(newVersionList[i]);
    int curVer = int.parse(currentVersionList[i]);
    if (newVer > curVer) {
      needUpdate = true;
      break;
    } else if (newVer < curVer) {
      needUpdate = false;
      break;
    }
  }

  if (needUpdate) {
    // Android installs the release package itself. Other systems, and a
    // release without that package, use the release page. The universal
    // package keeps the plain version code: a split package adds 1000 or
    // more, so after it a universal or local build is a downgrade.
    final apk = AnxPlatform.isAndroid
        ? (response.data['assets'] as List? ?? [])
              .map((asset) => asset['browser_download_url'].toString())
              .where((url) => url.endsWith('-universal.apk'))
              .firstOrNull
        : null;
    if (manualCheck) {
      Navigator.of(context).pop();
    }
    SmartDialog.show(
      builder: (BuildContext context) {
        final body = response.data['body']
            .toString()
            .split('\n')
            .skip(1)
            .join('\n');
        return AlertDialog(
          title: Text(
            L10n.of(context).commonNewVersion,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: StyledMarkdown(
              data:
                  '''### ${L10n.of(context).updateNewVersion} $newVersion\n
${L10n.of(context).updateCurrentVersion} $currentVersion\n
$body''',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                SmartDialog.dismiss();
              },
              child: Text(L10n.of(context).commonCancel),
            ),
            TextButton(
              onPressed: () {
                if (apk == null) {
                  launchUrl(_releasePage, mode: LaunchMode.externalApplication);
                  return;
                }
                SmartDialog.dismiss();
                _installUpdate(apk);
              },
              child: Text(
                apk == null
                    ? L10n.of(context).updateViaGithub
                    : L10n.of(context).commonDownload,
              ),
            ),
          ],
        );
      },
    );
  } else {
    if (manualCheck) {
      AnxToast.show(L10n.of(context).commonNoNewVersion);
    }
  }
}
