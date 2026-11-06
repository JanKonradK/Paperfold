import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/widgets/common/paperfold_pane.dart';
import 'package:paperfold/widgets/settings/settings_tile.dart';

class PaperfoldListRow extends StatelessWidget {
  const PaperfoldListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.contentPadding,
    this.minTileHeight = PaperfoldSize.row,
  });
  final Widget? leading, subtitle, trailing;
  final Widget title;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;
  final double minTileHeight;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: PaperfoldSpace.xs),
    child: PaperfoldPressable(
      enabled: onTap != null,
      child: PaperfoldPane(
        padding: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ListTile(
          minTileHeight: minTileHeight,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: PaperfoldSpace.sm,
          ),
          leading: leading == null ? null : SettingsIcon(child: leading!),
          title: title,
          subtitle: subtitle,
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    ),
  );
}
