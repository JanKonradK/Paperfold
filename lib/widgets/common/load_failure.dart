import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/common/message_block.dart';
import 'package:paperfold/widgets/ornament.dart';

/// What the reader sees when a page cannot load its own contents.
///
/// It replaces `Text('Error: $error')`, which appeared in the Journal, the
/// bookshelf, the note lists and the statistics cards. That line printed an
/// untranslated word and a raw exception — a stack type, a file path, a SQL
/// fragment — into the middle of the page, told the reader nothing they could
/// act on, and offered no way to try again.
///
/// The exception itself is not thrown away. It goes to the debug console in a
/// debug build, and [details] can put it behind a disclosure for a reader who
/// is reporting a fault.
class LoadFailure extends StatelessWidget {
  const LoadFailure({
    super.key,
    this.title,
    this.body,
    this.error,
    this.onRetry,
    this.compact = false,
  });

  /// A page-scale failure: the standard 104 dp wreath and a 420 dp block.
  /// DESIGN.md, Empty, loading, error, and drag states.
  const LoadFailure.page({
    Key? key,
    String? title,
    String? body,
    Object? error,
    Future<void> Function()? onRetry,
  }) : this(
          key: key,
          title: title,
          body: body,
          error: error,
          onRetry: onRetry,
        );

  /// A failure inside a card or a list section, where a 104 dp ornament would
  /// be larger than the thing that failed.
  const LoadFailure.inline({
    Key? key,
    String? title,
    Object? error,
    Future<void> Function()? onRetry,
  }) : this(
          key: key,
          title: title,
          error: error,
          onRetry: onRetry,
          compact: true,
        );

  final String? title;
  final String? body;
  final Object? error;
  final Future<void> Function()? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final String heading = title ?? l10n.commonLoadFailedTitle;

    if (kDebugMode && error != null) {
      debugPrint('LoadFailure: $error');
    }

    if (compact) {
      return Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: scheme.onSurfaceVariant),
              const SizedBox(height: 8),
              Text(
                heading,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.commonRetry),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Semantics(
      liveRegion: true,
      // Through MessageBlock: an error state can land in a parent that
      // measures it with an unbounded height, where a bare scroll view takes
      // an infinite extent and overflows its parent by ~100,000 pixels.
      child: MessageBlock(
        maxWidth: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Ornament(
              ornament: PaperfoldOrnament.circularWreath,
              width: 104,
              height: 104,
              tint: scheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              heading,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              body ?? l10n.commonLoadFailedBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
