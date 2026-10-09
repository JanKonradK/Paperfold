import 'package:material_ui/material_ui.dart';

abstract class AbstractSettingsTile extends StatelessWidget {
  const AbstractSettingsTile({super.key});
}

/// The metrics a [ListTile] needs to line up with the rows around it.
///
/// A settings row indents its title to 42: an 8 start inset, a 24 icon, a 10
/// gap. A stock ListTile indents to 56, so a card holding both kinds of row
/// had two left edges down the middle of it.
const ListTileThemeData settingsListTileTheme = ListTileThemeData(
  contentPadding: EdgeInsetsDirectional.only(start: 8, end: 8),
  minLeadingWidth: 24,
  horizontalTitleGap: 10,
  minTileHeight: 56,
);

enum SettingsTileType { simpleTile, switchTile, navigationTile }

class SettingsTile extends AbstractSettingsTile {
  SettingsTile({
    this.leading,
    this.trailing,
    this.value,
    required this.title,
    this.description,
    this.onPressed,
    this.enabled = true,
    super.key,
  }) {
    onToggle = null;
    initialValue = null;
    activeSwitchColor = null;
    tileType = SettingsTileType.simpleTile;
  }

  SettingsTile.navigation({
    this.leading,
    this.trailing,
    this.value,
    required this.title,
    this.description,
    this.onPressed,
    this.enabled = true,
    super.key,
  }) {
    onToggle = null;
    initialValue = null;
    activeSwitchColor = null;
    tileType = SettingsTileType.navigationTile;
  }

  SettingsTile.switchTile({
    required this.initialValue,
    required this.onToggle,
    this.activeSwitchColor,
    this.leading,
    this.trailing,
    required this.title,
    this.description,
    this.onPressed,
    this.enabled = true,
    super.key,
  }) {
    value = null;
    tileType = SettingsTileType.switchTile;
  }

  /// The widget at the beginning of the tile
  final Widget? leading;

  /// The Widget at the end of the tile
  final Widget? trailing;

  /// The widget at the center of the tile
  final Widget title;

  /// The widget at the bottom of the [title]
  final Widget? description;

  /// A function that is called by tap on a tile
  final Function(BuildContext context)? onPressed;

  late final Color? activeSwitchColor;
  late final Widget? value;
  late final Function(bool value)? onToggle;
  late final SettingsTileType tileType;
  late final bool? initialValue;
  late final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AndroidSettingsTile(
      description: description,
      onPressed: onPressed,
      onToggle: onToggle,
      tileType: tileType,
      value: value,
      leading: leading,
      title: title,
      enabled: enabled,
      activeSwitchColor: activeSwitchColor,
      initialValue: initialValue ?? false,
      trailing: trailing,
    );
  }
}

class AndroidSettingsTile extends StatelessWidget {
  const AndroidSettingsTile({
    required this.tileType,
    required this.leading,
    required this.title,
    required this.description,
    required this.onPressed,
    required this.onToggle,
    required this.value,
    required this.initialValue,
    required this.activeSwitchColor,
    required this.enabled,
    required this.trailing,
    super.key,
  });

  final SettingsTileType tileType;
  final Widget? leading;
  final Widget? title;
  final Widget? description;
  final Function(BuildContext context)? onPressed;
  final Function(bool value)? onToggle;
  final Widget? value;
  final bool initialValue;
  final bool enabled;
  final Color? activeSwitchColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final cantShowAnimation = tileType == SettingsTileType.switchTile
        ? onToggle == null && onPressed == null
        : onPressed == null;

    // The Material roles, not a local size. A bare TextStyle here replaced the
    // theme's family outright, so every settings row printed in the platform
    // default face while the About row beside it printed in Philosopher.
    // DESIGN.md, the Roles-Not-Sizes Rule.
    final titleStyle = (theme.textTheme.titleMedium ?? const TextStyle())
        .copyWith(color: enabled ? scheme.onSurface : theme.disabledColor);
    final supportingStyle = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(
            color: enabled ? scheme.onSurfaceVariant : theme.disabledColor);

    // A disabled row still reads as one node and still announces that it is
    // disabled. IgnorePointer swallowed the tap without telling anybody why.
    return Semantics(
      enabled: enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: !enabled || cantShowAnimation
              ? null
              : () {
                  if (tileType == SettingsTileType.switchTile) {
                    onToggle?.call(!initialValue);
                  } else {
                    onPressed?.call(context);
                  }
                },
          highlightColor: theme.listTileTheme.selectedColor,
          child: ConstrainedBox(
            // The 48-and-8 Rule. The old fixed padding made a one-line row
            // about 46 dp high.
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                if (leading != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: IconTheme(
                      data: IconTheme.of(context).copyWith(
                        color: enabled
                            ? theme.iconTheme.color
                            : theme.disabledColor,
                      ),
                      child: leading!,
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 10,
                      end: 8,
                      bottom: 12,
                      top: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DefaultTextStyle(
                          style: titleStyle,
                          child: title ?? const SizedBox.shrink(),
                        ),
                        // A row may carry both a current value and an
                        // explanation. The old `else if` silently dropped the
                        // explanation whenever a value was present.
                        if (value != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: DefaultTextStyle(
                              style: supportingStyle,
                              child: value!,
                            ),
                          ),
                        if (description != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: DefaultTextStyle(
                              style: supportingStyle,
                              child: description!,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (trailing != null && tileType == SettingsTileType.switchTile)
                  Row(
                    children: [
                      trailing!,
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: Switch(
                          value: initialValue,
                          // A disabled switch takes its own disabled paint and
                          // announces itself as disabled.
                          onChanged: enabled ? onToggle : null,
                          activeThumbColor: activeSwitchColor,
                        ),
                      ),
                    ],
                  )
                else if (tileType == SettingsTileType.switchTile)
                  Padding(
                    padding:
                        const EdgeInsetsDirectional.only(start: 16, end: 8),
                    child: Switch(
                      value: initialValue,
                      onChanged: enabled ? onToggle : null,
                      activeThumbColor: activeSwitchColor,
                    ),
                  )
                else if (tileType == SettingsTileType.navigationTile)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: trailing ??
                        Icon(
                          Icons.chevron_right,
                          color: enabled
                              ? scheme.onSurfaceVariant
                              : theme.disabledColor,
                        ),
                  )
                else if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: trailing!,
                  )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomSettingsTile extends AbstractSettingsTile {
  const CustomSettingsTile({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// A settings row whose control is too wide to sit beside the title: a
/// slider, a segmented button, a group of chips.
///
/// It exists because those rows were built from bare [ListTile]s. A ListTile
/// indents its title to 56, an [AndroidSettingsTile] to 42, and some of the
/// rows carried no leading icon at all, so one section could hold three
/// different left edges and two different title sizes. This keeps the metrics
/// and the type of the row beside it.
class SettingsControlTile extends AbstractSettingsTile {
  const SettingsControlTile({
    required this.title,
    required this.control,
    this.leading,
    this.description,
    super.key,
  });

  final Widget title;
  final Widget control;
  final Widget? leading;
  final Widget? description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: 8,
        end: 8,
        top: 12,
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top-aligned. Against a four-line description a centred icon
          // floated in the middle of the block, out of line with every row
          // above and below it.
          SizedBox(
            width: 24,
            child: leading == null
                ? null
                : IconTheme(
                    data: IconTheme.of(context)
                        .copyWith(color: theme.iconTheme.color),
                    child: leading!,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: (theme.textTheme.titleMedium ?? const TextStyle())
                      .copyWith(color: scheme.onSurface),
                  child: title,
                ),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: DefaultTextStyle(
                      style: (theme.textTheme.bodyMedium ?? const TextStyle())
                          .copyWith(color: scheme.onSurfaceVariant),
                      child: description!,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: control,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
