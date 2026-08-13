import 'package:paperfold/providers/sync.dart';
import 'package:paperfold/widgets/bookshelf/sync_status_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncButton extends ConsumerStatefulWidget {
  const SyncButton({super.key});

  @override
  ConsumerState createState() => _SyncButtonState();
}

class _SyncButtonState extends ConsumerState<SyncButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _syncAnimationController;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _syncAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _animation = Tween(begin: 1.0, end: 0.0).animate(_syncAnimationController);
  }

  @override
  void dispose() {
    _syncAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    // Read through select so the button rebuilds only when the syncing flag
    // itself changes, not on every field of the sync state.
    final isSyncing = ref.watch(syncProvider.select((value) => value.isSyncing));

    // Drive the controller from the flag directly. Starting it from a
    // post-frame callback re-entered the provider subscription and threw
    // LateInitializationError while the shelf home was building.
    if (isSyncing && !disableAnimations) {
      if (!_syncAnimationController.isAnimating) {
        _syncAnimationController.repeat();
      }
    } else if (_syncAnimationController.isAnimating) {
      _syncAnimationController.stop();
    }

    return IconButton(
      icon: isSyncing && !disableAnimations
          ? RepaintBoundary(
              child: RotationTransition(
                turns: _animation,
                child: const Icon(Icons.sync),
              ),
            )
          : const Icon(Icons.sync),
      onPressed: () {
        showSyncStatusBottomSheet(context);
      },
    );
  }
}
