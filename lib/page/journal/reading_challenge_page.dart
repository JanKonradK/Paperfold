import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/dao/challenge.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/journal/book_review_page.dart';
import 'package:paperfold/providers/reading_challenge.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';

/// Annual progress and the real books behind it, using the app's own surfaces.
class ReadingChallengePage extends ConsumerWidget {
  const ReadingChallengePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final challenge = ref.watch(readingChallengeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.challengeTitle)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: challenge.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _ChallengeMessage(
                  title: l10n.commonLoadFailedTitle,
                  body: l10n.commonLoadFailedBody,
                  actionLabel: l10n.commonRetry,
                  onAction: () =>
                      ref.read(readingChallengeProvider.notifier).refresh(),
                ),
              ),
              data: (data) => _ChallengeView(data: data),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _editTarget(
  BuildContext context,
  WidgetRef ref,
  ReadingChallengeData data,
) =>
    showDialog<void>(
      context: context,
      builder: (_) => _TargetDialog(
        target: data.target,
        onSave: (value) async {
          await ref.read(readingChallengeProvider.notifier).setTarget(value);
        },
      ),
    );

class _TargetDialog extends StatefulWidget {
  const _TargetDialog({required this.target, required this.onSave});

  final int target;
  final Future<void> Function(int) onSave;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late String _text = widget.target.toString();
  String? _error;
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving) return;
    final value = int.tryParse(_text.trim());
    if (value == null ||
        value < ChallengeDao.minimumTarget ||
        value > ChallengeDao.maximumTarget) {
      setState(() => _error = L10n.of(context).challengeTargetRange);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(value);
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      AnxLog.warning('Could not save reading target', error, stackTrace);
      if (mounted) {
        setState(() => _error = L10n.of(context).challengeSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(l10n.challengeSetTarget),
        content: TextFormField(
          key: const ValueKey<String>('challenge-target-field'),
          initialValue: widget.target.toString(),
          enabled: !_saving,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            labelText: l10n.challengeTargetLabel,
            helperText: l10n.challengeTargetRange,
            helperMaxLines: 3,
            errorText: _error,
            errorMaxLines: 3,
          ),
          onChanged: (value) {
            _text = value;
            if (_error != null) setState(() => _error = null);
          },
          onFieldSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

class _ChallengeView extends ConsumerWidget {
  const _ChallengeView({required this.data});

  final ReadingChallengeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedYear = ref.watch(trackedChallengeYearProvider);
    final currentYear = DateTime.now().year;
    final over = data.finishedCount - data.target;
    final pace = data.paceDelta;
    final paceLabel = pace > 0
        ? l10n.challengePaceAhead(pace)
        : pace < 0
            ? l10n.challengePaceBehind(-pace)
            : l10n.challengePaceOnTrack;
    final bookCount = data.finished.length + data.readingNow.length;

    void stepYear(int amount) {
      ref.read(trackedChallengeYearProvider.notifier).state =
          selectedYear + amount;
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(readingChallengeProvider.notifier).refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        itemCount: 1 + bookCount,
        itemBuilder: (context, index) {
          if (index > 0) {
            final Book book = data.bookForSlot(index)!;
            final finished = index <= data.finishedCount;
            final status = finished
                ? l10n.challengeLegendFinished
                : l10n.challengeLegendReading;
            final firstInSection =
                index == 1 || index == data.finishedCount + 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (firstInSection)
                  Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 8),
                    child: Text(status, style: theme.textTheme.titleLarge),
                  ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: ExcludeSemantics(
                    child: BookCover(book: book, width: 36, height: 54),
                  ),
                  title: Text(book.title,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: book.author.isEmpty ? null : Text(book.author),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => BookReviewPage(book: book),
                    ),
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey<String>('challenge-previous-year'),
                    icon: const Icon(Icons.chevron_left),
                    tooltip: l10n.challengePreviousYear,
                    onPressed: selectedYear > 1 ? () => stepYear(-1) : null,
                  ),
                  Expanded(
                    child: Text(
                      data.year.toString(),
                      semanticsLabel:
                          l10n.challengeYearTitle(data.year.toString()),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey<String>('challenge-next-year'),
                    icon: const Icon(Icons.chevron_right),
                    tooltip: l10n.challengeNextYear,
                    onPressed:
                        selectedYear < currentYear ? () => stepYear(1) : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DecoratedBox(
                key: const ValueKey<String>('challenge-progress'),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.challengeProgress(data.finishedCount, data.target),
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: data.progress.clamp(0.0, 1.0),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(3),
                        semanticsLabel: l10n.challengeProgress(
                            data.finishedCount, data.target),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            pace < 0
                                ? Icons.trending_down
                                : pace > 0
                                    ? Icons.trending_up
                                    : Icons.trending_flat,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(paceLabel,
                                    style: theme.textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.challengePaceExpected(
                                      data.expectedFinished),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                if (over > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(l10n.challengeOverTarget(over)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.flag_outlined),
                        label: Text(l10n.challengeSetTarget),
                        onPressed: () => _editTarget(context, ref, data),
                      ),
                    ],
                  ),
                ),
              ),
              if (bookCount == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: _ChallengeMessage(
                    title: l10n.challengeEmptyTitle,
                    body: l10n.challengeEmptyBody,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChallengeMessage extends StatelessWidget {
  const _ChallengeMessage({
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
        ],
      ],
    );
  }
}
