import 'package:paperfold/widgets/common/container/filled_container.dart';
import 'package:paperfold/widgets/settings/settings_tile.dart';
import 'package:flutter/material.dart';

abstract class AbstractSettingsSection extends StatelessWidget {
  const AbstractSettingsSection({super.key});
}

class SettingsSection extends AbstractSettingsSection {
  const SettingsSection({
    super.key,
    required this.tiles,
    this.margin,
    this.title,
  });

  final List<AbstractSettingsTile> tiles;
  final EdgeInsetsDirectional? margin;
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    return buildSectionBody(context);
  }

  Widget buildSectionBody(BuildContext context) {
    final theme = Theme.of(context);
    final tileList = buildTileList();

    // A section without a header still gets the card and the side inset. It
    // used to fall back to a bare column, so a headerless section sat flush
    // against the screen edge while its neighbours were inset and grouped.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title == null)
          // Without a header there is nothing to separate this card from the
          // one above it, and the two ran together at the seam.
          const SizedBox(height: 12)
        else
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: 20,
              bottom: 8,
              start: 24,
              end: 24,
            ),
            child: DefaultTextStyle(
              // The Label role. DESIGN.md gives Source Sans 3 to navigation,
              // controls, menus and metadata, and a section header is all
              // four; it also sets the header apart from the Philosopher row
              // titles under it. The bare TextStyle this replaced carried a
              // colour and nothing else, so the header printed at the ambient
              // body size in the platform default face.
              style:
                  (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
                color: theme.colorScheme.primary,
              ),
              child: Semantics(
                header: true,
                child: title!,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FilledContainer(
            padding: EdgeInsetsGeometry.zero,
            child: tileList,
          ),
        ),
      ],
    );
  }

  Widget buildTileList() {
    return Column(
      children: tiles,
    );
  }
}

class CustomSettingsSection extends AbstractSettingsSection {
  const CustomSettingsSection({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
