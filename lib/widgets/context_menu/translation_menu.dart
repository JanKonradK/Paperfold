import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/lang_list.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/service/translate/index.dart';
import 'package:paperfold/widgets/common/axis_flex.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import 'dart:async';
import 'dart:math' as math;

class TranslationMenu extends StatefulWidget {
  const TranslationMenu({
    super.key,
    required this.content,
    required this.decoration,
    required this.axis,
    this.contextText,
  });
  final String content;
  final BoxDecoration decoration;
  final Axis axis;
  final String? contextText;

  @override
  State<TranslationMenu> createState() => _TranslationMenuState();
}

class _TranslationMenuState extends State<TranslationMenu> {
  Widget? _translationWidget;
  Timer? _debounceTimer;
  bool _translationInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTranslation();
  }

  void _initializeTranslation() {
    // Use addPostFrameCallback to ensure the UI is rendered first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _translationInitialized) return;

      // Debounce: Delay the translation call to ensure context has stopped updating
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted || _translationInitialized) return;
        _translationInitialized = true;
        _translate();
      });
    });
  }

  void _translate() {
    final effectiveContextText = (widget.contextText?.trim().isEmpty ?? true)
        ? null
        : widget.contextText;
    setState(() {
      _translationWidget = translateText(
        widget.content,
        contextText: effectiveContextText,
      );
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Widget _langPicker(bool isFrom) {
    final MenuController menuController = MenuController();
    final L10n l10n = L10n.of(context);
    final String language = isFrom
        ? Prefs().translateFrom.getNative(context)
        : Prefs().translateTo.getNative(context);

    return PointerInterceptor(
      child: MenuAnchor(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(
            Theme.of(context).colorScheme.secondaryContainer,
          ),
          maximumSize: WidgetStateProperty.all(const Size(300, 300)),
        ),
        controller: menuController,
        menuChildren: [
          for (var lang in LangListEnum.values)
            // Auto-detect is a source, never a target.
            if (isFrom || lang != LangListEnum.auto)
              PointerInterceptor(
                child: MenuItemButton(
                  onPressed: () {
                    if (isFrom) {
                      Prefs().translateFrom = lang;
                    } else {
                      Prefs().translateTo = lang;
                    }
                    // The choice was saved but the popup kept the old label
                    // and the old translation, so it looked ignored.
                    _translate();
                  },
                  child: Text(lang.getNative(context)),
                ),
              ),
        ],
        builder: (context, controller, child) {
          // A bare Text in a GestureDetector: no button semantics, no visible
          // affordance, and a target as small as the word it showed. A reader
          // could not tell it opened anything.
          return Tooltip(
            // The visible label is the language alone, so the direction has to
            // come from somewhere. A tooltip carries it into semantics too.
            message: isFrom
                ? l10n.translateFromLanguage(language)
                : l10n.translateToLanguage(language),
            child: TextButton.icon(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.arrow_drop_down, size: 18),
              iconAlignment: IconAlignment.end,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: PaperfoldSpace.xs,
                ),
                visualDensity: VisualDensity.standard,
              ),
              label: Text(language, overflow: TextOverflow.ellipsis),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final L10n l10n = L10n.of(context);
    // The panel grows with the system text setting, up to part of the screen.
    final double scale = MediaQuery.textScalerOf(context)
        .scale(1)
        .clamp(1.0, 2.0);
    final double height = math.min(
      220 * scale,
      MediaQuery.sizeOf(context).height * 0.45,
    );

    return Expanded(
      child: AnimatedSize(
        duration: PaperfoldVisualPolicy.motionAllowed(context)
            ? PaperfoldMotion.of(context, PaperfoldMotion.move)
            : Duration.zero,
        curve: Curves.easeOut,
        child: Container(
          height: widget.axis == Axis.vertical ? double.infinity : height,
          width: widget.axis == Axis.vertical ? 100 * scale : double.infinity,
          decoration: widget.decoration,
          padding: const EdgeInsets.all(PaperfoldSpace.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The passage is already highlighted on the page; two
                      // lines identify it without crowding out the result.
                      Text(
                        widget.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // A translation in flight was three literal dots, which
                      // a screen reader reads as nothing at all.
                      _translationWidget ??
                          Semantics(
                            label: l10n.translateWorking,
                            liveRegion: true,
                            child: const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              // The languages stay in reach however long the translation is.
              const Divider(height: 8),
              AxisFlex(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                axis: widget.axis,
                children: [
                  _langPicker(true),
                  Transform.rotate(
                    angle: widget.axis == Axis.horizontal ? 0 : 1.57,
                    child: Icon(Icons.arrow_forward_ios, size: 16),
                  ),
                  _langPicker(false),
                  if (widget.axis == Axis.horizontal) const Spacer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
