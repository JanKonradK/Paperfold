import 'package:paperfold/page/settings_page/more_settings_page.dart';
import 'package:paperfold/widgets/paperfold_logo_mark.dart';
import 'package:paperfold/widgets/settings/about.dart';
import 'package:paperfold/widgets/settings/theme_mode.dart';
import 'package:paperfold/widgets/settings/webdav_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.controller});

  final ScrollController? controller;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final ScrollController _scrollController =
      widget.controller ?? ScrollController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            children: [
              // The fork's own name was still here at 130 points. The mark
              // carries the brand now, and the name sits at a size the page
              // can hold in every language.
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 48, 0, 20),
                child: Column(
                  children: [
                    PaperfoldLogoMark(
                      size: 96,
                      tint: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Paperfold',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 10, 8),
                child: ChangeThemeMode(),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: webdavSwitch(context, setState, ref),
              ),
              const Divider(),
              const MoreSettings(),
              const About(),
            ],
          ),
        ),
      ),
    );
  }
}
