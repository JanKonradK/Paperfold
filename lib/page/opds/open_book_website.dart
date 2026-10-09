import 'package:material_ui/material_ui.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/service/opds/opds.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openBookWebsite(BuildContext context, Uri url) async {
  try {
    if (!isOpdsWebUri(url) ||
        !await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw StateError('The website could not be opened');
    }
  } catch (_) {
    AnxLog.warning('Could not open book website');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).onlineOpenWebsiteFailed)),
      );
    }
  }
}
