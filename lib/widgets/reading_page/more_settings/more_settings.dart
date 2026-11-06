import 'package:paperfold/widgets/common/paperfold_modal_motion.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/widgets/reading_page/more_settings/other_settings.dart';
import 'package:paperfold/widgets/reading_page/more_settings/reading_settings.dart';
import 'package:paperfold/widgets/reading_page/more_settings/style_settings.dart';
import 'package:paperfold/widgets/reading_page/more_settings/custom_css_editor.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

enum ReadingSettings { theme, style }

void showMoreSettings(ReadingSettings settings) {
  final context = navigatorKey.currentContext!;
  showDialog<void>(
    context: context,
    animationStyle: paperfoldModalMotion(context),
    builder: (context) => Dialog(
      child: PointerInterceptor(
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          height: MediaQuery.sizeOf(context).height * 0.85,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  settings == ReadingSettings.style
                      ? L10n.of(context).readerMoreAppearance
                      : L10n.of(context).readerAdvancedSettings,
                ),
                trailing: CloseButton(),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (settings == ReadingSettings.style)
                      const StyleSettings(),
                    const ReadingMoreSettings(),
                    const OtherSettings(),
                    ExpansionTile(
                      title: Text(L10n.of(context).settingsAdvanced),
                      children: [CustomCSSEditor()],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
