import 'dart:core';

import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/lang_list.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/service/config/config_item.dart';
import 'package:paperfold/service/translate/deepl.dart';
import 'package:paperfold/service/translate/google_api.dart';
import 'package:paperfold/service/translate/google_web.dart';
import 'package:paperfold/service/translate/microsoft_api.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

enum TranslateService {
  googleWeb,
  microsoftApi,
  googleApi,
  deepl;

  TranslateServiceProvider get provider {
    switch (this) {
      case TranslateService.googleWeb:
        return GoogleWebTranslateProvider();
      case TranslateService.microsoftApi:
        return MicrosoftApiTranslateProvider();
      case TranslateService.googleApi:
        return GoogleApiTranslateProvider();
      case TranslateService.deepl:
        return DeepLTranslateProvider();
    }
  }

  /// Get the display label from the provider.
  String getLabel(BuildContext context) => provider.getLabel(context);

  static List<TranslateService> get activeValues => values;
}

TranslateService getTranslateService(String name) {
  if (name == 'microsoft') {
    return TranslateService.microsoftApi;
  }

  try {
    return TranslateService.values.firstWhere((e) => e.name == name);
  } catch (e) {
    // Includes the retired 'bingWeb', which embedded Bing's web page.
    return TranslateService.googleWeb;
  }
}

/// Base class for all translation service providers.
/// Subclasses must implement [service], [label], [translate], and [translateStream].
abstract class TranslateServiceProvider {
  /// The service enum value this provider corresponds to.
  TranslateService get service;

  /// The display label for this service.
  String getLabel(BuildContext context);

  /// Override this method if the service uses a different code format.
  /// Default implementation returns [lang.code].
  String mapLanguageCode(LangListEnum lang) => lang.code;

  /// Get the configuration items for this service.
  List<ConfigItem> getConfigItems(BuildContext context) {
    return [];
  }

  /// Returns the widget for displaying the translation result.
  Widget translate(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
  });

  /// Returns a stream of translation results.
  Stream<String> translateStream(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
    bool isFullText = false,
  });

  /// Translate text only (no widget), with retry logic.
  Future<String> translateTextOnly(
    String text,
    LangListEnum from,
    LangListEnum to, {
    String? contextText,
    bool isFullText = false,
  }) async {
    const int maxRetries = 2;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        String? lastResult;
        await for (String result in translateStream(
          text,
          from,
          to,
          contextText: contextText,
          isFullText: isFullText,
        )) {
          lastResult = result;
        }

        if (lastResult != null &&
            lastResult.trim().isNotEmpty &&
            lastResult != '...') {
          return lastResult;
        }

        throw Exception(
            'Translation returned no valid result: ${lastResult ?? 'No result'}');
      } catch (e) {
        if (attempt < maxRetries) {
          AnxLog.warning(
              'Translation attempt ${attempt + 1} failed with exception: $e. Retrying...');
          await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          continue;
        } else {
          throw Exception(
              'Translation failed after ${maxRetries + 1} attempts: $e');
        }
      }
    }

    throw Exception('Translation failed after all retry attempts');
  }

  /// Returns the current configuration.
  Map<String, dynamic> getConfig() => {};

  /// Saves the configuration.
  void saveConfig(Map<String, dynamic> config) {}

  /// Helper to convert a stream to a widget with copy button.
  Widget convertStreamToWidget(Stream<String> stream) {
    return StreamBuilder<String>(
      stream: stream,
      builder: (context, snapshot) {
        final theme = Theme.of(context);
        final l10n = L10n.of(context);
        if (snapshot.hasError) {
          return Text(
            '${snapshot.error}'.replaceAll('Exception: ', ''),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          );
        }
        final text = snapshot.data;
        if (text == null || text == '...') {
          // Three literal dots read as nothing to a screen reader.
          return Semantics(
            label: l10n.translateWorking,
            liveRegion: true,
            child: const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(text, style: theme.textTheme.bodyLarge),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: text)),
                icon: const Icon(Icons.copy, size: 18),
                label: Text(l10n.commonCopy),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// Helper functions (use service.provider instead of TranslateFactory)
// ============================================================================

Widget translateText(String text,
    {TranslateService? service, String? contextText}) {
  service ??= Prefs().translateService;
  final from = Prefs().translateFrom;
  final to = Prefs().translateTo;

  return service.provider.translate(
    text,
    from,
    to,
    contextText: contextText,
  );
}

List<ConfigItem> getTranslateServiceConfigItems(
    BuildContext context, TranslateService service) {
  return service.provider.getConfigItems(context);
}

Map<String, dynamic> getTranslateServiceConfig(TranslateService service) {
  return service.provider.getConfig();
}

void saveTranslateServiceConfig(
    TranslateService service, Map<String, dynamic> config) {
  return service.provider.saveConfig(config);
}

Future<String> translateTextOnly(String text,
    {TranslateService? service, String? contextText}) async {
  service ??= Prefs().translateService;
  final from = Prefs().translateFrom;
  final to = Prefs().translateTo;

  return await service.provider.translateTextOnly(
    text,
    from,
    to,
    contextText: contextText,
  );
}
