import 'dart:math';

import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/providers/dashboard_tiles_provider.dart';
import 'package:paperfold/service/vibration_service.dart';
import 'package:paperfold/widgets/common/container/filled_container.dart';
import 'package:paperfold/widgets/common/fitted_text.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_detail_view.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_metadata.dart';
import 'package:paperfold/widgets/statistic/dashboard_tiles/dashboard_tile_registry.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroine/heroine.dart';
import 'package:staggered_reorderable/staggered_reorderable.dart';

/// Base class for all statistics dashboard tiles.
abstract class StatisticsDashboardTileBase {
  const StatisticsDashboardTileBase();

  StatisticsDashboardTileMetadata get metadata;

  StatisticsDashboardTileType get type => metadata.type;

  /// Builds the tile body with access to BuildContext and WidgetRef.
  Widget buildContent(BuildContext context, WidgetRef ref);

  /// Called when the tile is removed from the dashboard.
  /// Override this method to perform cleanup or additional actions.
  void onRemove(BuildContext context, WidgetRef ref) {}

  L10n get l10nLocal => L10n.of(navigatorKey.currentContext!);

  /// One statistic, in as little furniture as it takes to hold it.
  ///
  /// Two things went. The filled block, which made a screen of tiles read as a
  /// wall of boxes rather than as a set of numbers; it is a quiet surface with
  /// a hairline now, so the figures carry the contrast. And the giant rotated
  /// icon bleeding out of the bottom corner at ten percent opacity, which was
  /// decoration standing where content should be, and which every tile paid
  /// for in a second layer and a clip.
  Widget buildTile(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return FilledContainer(
      width: double.infinity,
      height: double.infinity,
      radius: 16,
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: ClipRect(child: buildContent(context, ref)),
          ),
        ],
      ),
    );
  }

  String get title => '';

  bool get canFlip => true;

  double get flipSquareSize => 120;

  double get flipTitleSize => 100;

  /// How much taller a tile must be to hold text at the reader's size.
  ///
  /// Every tile box here is a fixed number of logical pixels. Raising the
  /// system font size grows the text inside those boxes but not the boxes, so
  /// the content ran past the bottom edge. The cap keeps a tile from eating
  /// the screen at the largest settings.
  double _textScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);

  Size tileSize(BuildContext context) {
    final scale = _textScale(context);
    final width = min(flipSquareSize * metadata.columnSpan,
        MediaQuery.sizeOf(context).width * 0.9);
    final height = min(flipSquareSize * metadata.rowSpan * scale,
        MediaQuery.sizeOf(context).height * 0.8);
    return Size(width, height);
  }

  Size flipSize(BuildContext context) {
    final scale = _textScale(context);
    final width = min(max(flipSquareSize * metadata.columnSpan, 300.0),
        MediaQuery.sizeOf(context).width * 0.9);

    final height = min(
        (flipSquareSize * metadata.rowSpan + flipTitleSize) * scale,
        MediaQuery.sizeOf(context).height * 0.8);

    return Size(width, height);
  }

  Widget buildFlipSide(BuildContext context, WidgetRef ref) {
    return flipScaffold(
      context,
      ref,
      buildTile(context, ref),
    );
  }

  void onTap(BuildContext context, WidgetRef ref) {}

  Widget flipScaffold(BuildContext context, WidgetRef ref, Widget flipContent) {
    final theme = Theme.of(context);
    final spacing = 8.0;

    return FilledContainer(
      color: theme.scaffoldBackgroundColor,
      width: flipSize(context).width,
      height: flipSize(context).height,
      // The content takes whatever the header leaves rather than a fixed
      // number of pixels, so a tile clips its own overflow instead of
      // painting past its edge.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledContainer(
            radius: 29,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.primaryContainer,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      metadata.icon,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FittedText(
                        metadata.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                        maxHeight: 25,
                      ),
                    ),
                  ],
                ),
                Text(
                  metadata.description,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(height: spacing),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRect(child: flipContent),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns the [ReorderableItem] used by the reorderable grid.
  ReorderableItem buildReorderableItem({required BuildContext context}) {
    return ReorderableItem(
      trackingNumber: type.index,
      id: type.name,
      crossAxisCellCount: metadata.columnSpan,
      mainAxisCellCount: metadata.rowSpan,
      child: DashboardTileShell(
        tileType: type,
        tile: this,
        buildContent: buildContent,
      ),
      placeholder: Opacity(
        opacity: 0.5,
        child: DashboardTileShell(
          tileType: type,
          tile: this,
          buildContent: buildContent,
        ),
      ),
    );
  }
}

class DashboardTileShell extends ConsumerWidget {
  const DashboardTileShell({
    super.key,
    required this.buildContent,
    required this.tileType,
    required this.tile,
  });

  final Widget Function(BuildContext context, WidgetRef ref) buildContent;
  final StatisticsDashboardTileType tileType;
  final StatisticsDashboardTileBase tile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardTilesProvider);
    final showRemoveButton = state.isEditing && state.workingTiles.length > 1;

    final notifier = ref.read(dashboardTilesProvider.notifier);
    final heroTag = 'dashboard_tile_${tileType.name}';

    return Heroine(
      tag: heroTag,
      flightShuttleBuilder: const FlipShuttleBuilder(
        axis: Axis.vertical,
        halfFlips: 1,
      ),
      motion: Motion.bouncySpring(
        snapToEnd: true,
        duration: const Duration(milliseconds: 500),
      ),
      child: GestureDetector(
        onTap: () {
          if (!tile.canFlip) {
            tile.onTap(context, ref);
            return;
          }
          VibrationService.medium();
          Navigator.of(context)
              .push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, animation, secondaryAnimation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return DashboardTileDetailView(
                      tile: tile,
                      heroTag: heroTag,
                      animationValue: animation.value,
                    );
                  },
                );
              },
            ),
          )
              .then((_) {
            VibrationService.rigid();
          });
        },
        child: Stack(
          children: [
            tile.buildTile(context, ref),
            if (showRemoveButton)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton.filledTonal(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: L10n.of(context).commonRemove,
                  onPressed: () {
                    notifier.removeTile(tileType);
                    tile.onRemove(context, ref);
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
