import 'package:paperfold/page/journal/journal_photo.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';
import 'package:paperfold/widgets/common/paperfold_transition.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/service/journal/entry_draft.dart';
import 'package:paperfold/widgets/common/paperfold_pane.dart';

Future<void> showFacingPage(
  BuildContext context, {
  required Book book,
  String? locator,
  double? progress,
  int? page,
  String? label,
  Future<void> Function(JournalPage)? onOpenEntry,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: Colors.transparent,
  transitionDuration: paperfoldTransitionDuration(
    context,
    PaperfoldMotion.move,
  ),
  pageBuilder: (_, _, _) => Align(
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: PaperfoldShape.sheetShape,
        clipBehavior: Clip.antiAlias,
        child: FacingPage(
          book: book,
          locator: locator,
          progress: progress,
          page: page,
          label: label,
          onOpenEntry: onOpenEntry,
        ),
      ),
    ),
  ),
  transitionBuilder: (context, animation, secondary, child) {
    final reduced = !PaperfoldVisualPolicy.motionAllowed(context);
    final t = CurvedAnimation(parent: animation, curve: PaperfoldMotion.settle);
    return FadeTransition(
      opacity: reduced
          ? animation
          : CurvedAnimation(parent: animation, curve: const Interval(0, 0.4)),
      child: SlideTransition(
        position: Tween(
          begin: reduced ? Offset.zero : const Offset(0, 1),
          end: Offset.zero,
        ).animate(t),
        child: child,
      ),
    );
  },
);

/// Location is an immutable opening snapshot, never the reader's live state.
class FacingPage extends StatefulWidget {
  const FacingPage({
    super.key,
    required this.book,
    this.locator,
    this.progress,
    this.page,
    this.label,
    this.dao,
    this.draft,
    this.onOpenEntry,
  });

  final Book book;
  final String? locator;
  final double? progress;
  final int? page;
  final String? label;
  final JournalDao? dao;
  final EntryDraft? draft;
  final Future<void> Function(JournalPage)? onOpenEntry;
  @override
  State<FacingPage> createState() => _FacingPageState();
}

class _FacingPageState extends State<FacingPage> {
  int _entryId = -DateTime.now().microsecondsSinceEpoch;
  final _text = TextEditingController();
  late final _draft = widget.draft ?? EntryDraft();
  List<JournalPage> _entries = [];
  late String? _locator = widget.locator;
  late double? _progress = widget.progress;
  late int? _page = widget.page;
  late String? _label = widget.label;
  bool _later = false, _busy = false, _failed = false, _loaded = false;
  JournalDao get _dao => widget.dao ?? journalDao;
  @override
  void initState() {
    super.initState();
    _load();
    _recover();
  }

  Future<void> _recover() async {
    try {
      final draft = await _draft.read();
      if (!mounted) return;
      // Never consume writing from another book or from the general composer.
      if (draft != null &&
          draft['facing'] == true &&
          draft['bookId'] == widget.book.id) {
        _entryId = draft['entryId'] as int? ?? _entryId;
        _text.text = draft['text'] as String? ?? '';
        _locator = draft['locator'] as String?;
        _progress = (draft['progress'] as num?)?.toDouble();
        _page = draft['page'] as int?;
        _label = draft['label'] as String?;
      }
      _loaded =
          draft == null ||
          (draft['facing'] == true && draft['bookId'] == widget.book.id);
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _load() async {
    try {
      final entries = await _dao.entriesAt(
        widget.book.id,
        progress: widget.progress,
        page: widget.page,
        includeLater: _later,
      );
      if (mounted) setState(() => _entries = entries);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _persist(String text) async {
    try {
      await _draft.write({
        'entryId': _entryId,
        'facing': true,
        'bookId': widget.book.id,
        'text': text,
        'locator': _locator,
        'progress': _progress,
        'page': _page,
        'label': _label,
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await _persist(_text.text);
      await _dao.saveEntry(
        JournalPage(
          id: _entryId,
          bookId: widget.book.id,
          pageIndex: 0,
          body: _text.text,
          sourceLocator: _locator,
          sourceCfi: _locator,
          sourceProgress: _progress,
          sourcePage: _page,
          sourceLabel: _label,
        ),
      );
      try {
        await _draft.clear();
      } catch (_) {
        // The database commit succeeded. Do not offer a second Save.
      }
      _text.clear();
      _entryId = -DateTime.now().microsecondsSinceEpoch;
      await _load();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final media = MediaQuery.of(context);
    final available =
        media.size.height - media.viewInsets.bottom - media.padding.top;
    return PointerInterceptor(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: (available - 120).clamp(180, media.size.height * 0.65),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(PaperfoldSpace.sheetGutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.facingPage,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const CloseButton(),
                    ],
                  ),
                  if (widget.label != null)
                    Text(
                      widget.label!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final entry in _entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: PaperfoldSpace.xxs,
                            ),
                            child: PaperfoldPane(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (entry.sourceExcerpt?.isNotEmpty ?? false)
                                    Text(
                                      entry.sourceExcerpt!,
                                      style: const TextStyle(
                                        fontFamily: 'Philosopher',
                                        fontSize: 17,
                                        height: 24 / 17,
                                      ),
                                    ),
                                  if (entry.body.isNotEmpty) Text(entry.body),
                                  if (entry.photoPath != null)
                                    JournalPhoto(path: entry.photoPath!),
                                  if (entry.hasSource &&
                                      widget.onOpenEntry != null)
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.menu_book_outlined,
                                        size: PaperfoldSize.smallIcon,
                                      ),
                                      label: Text(
                                        entry.sourceLabel ??
                                            entry.sourceChapter ??
                                            l.journalOpenPassage,
                                      ),
                                      onPressed: () async {
                                        Navigator.of(context).pop();
                                        await widget.onOpenEntry!(entry);
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (!_later)
                          TextButton(
                            onPressed: () {
                              setState(() => _later = true);
                              _load();
                            },
                            child: Text(l.showLaterEntries),
                          ),
                        TextField(
                          controller: _text,
                          readOnly: _busy || !_loaded,
                          minLines: 2,
                          maxLines: null,
                          onChanged: _persist,
                          decoration: InputDecoration(
                            hintText: _loaded
                                ? l.journalPageHint
                                : l.journalSaveFailed,
                          ),
                        ),
                        if (_failed)
                          Text(
                            l.journalSaveFailed,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: PaperfoldSize.primary,
                    child: FilledButton(
                      onPressed: _busy || !_loaded ? null : _save,
                      child: Text(l.commonSave),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
