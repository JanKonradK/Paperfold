import 'package:paperfold/widgets/common/paperfold_transition.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/paperfold_visual_policy.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/service/cover_image.dart';
import 'package:paperfold/service/journal/entry_draft.dart';
import 'package:paperfold/service/journal/page_photo.dart';
import 'package:paperfold/service/quick_capture.dart';
import 'package:paperfold/widgets/bookshelf/physical_progress_sheet.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';
import 'package:paperfold/page/journal/journal_photo.dart';

Future<bool> showNewEntrySheet(
  BuildContext context, {
  QuickCaptureRequest? request,
  Rect? origin,
}) async {
  final reduced = !PaperfoldVisualPolicy.motionAllowed(context);
  return await Navigator.of(context).push<bool>(
        PageRouteBuilder<bool>(
          opaque: false,
          barrierDismissible: true,
          barrierLabel: MaterialLocalizations.of(context)
              .modalBarrierDismissLabel,
          barrierColor: Theme.of(context).colorScheme.scrim
              .withValues(alpha: 0.32),
          transitionDuration: paperfoldTransitionDuration(
            context,
            reduced ? PaperfoldMotion.tick : PaperfoldMotion.move,
          ),
          reverseTransitionDuration: paperfoldTransitionDuration(
            context,
            reduced ? PaperfoldMotion.tick : PaperfoldMotion.move,
          ),
          pageBuilder: (_, animation, secondary) =>
              NewEntrySheet(request: request),
          transitionsBuilder: (context, animation, secondary, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final end = Rect.fromLTWH(
                  0,
                  constraints.maxHeight * 0.12,
                  constraints.maxWidth,
                  constraints.maxHeight * 0.88,
                );
                final start =
                    origin ??
                    Rect.fromLTWH(
                      end.left,
                      constraints.maxHeight,
                      end.width,
                      0,
                    );
                return AnimatedBuilder(
                  animation: animation,
                  builder: (_, _) {
                    final t = PaperfoldMotion.settle.transform(animation.value);
                    final rect = reduced ? end : Rect.lerp(start, end, t)!;
                    return Stack(
                      children: [
                        Positioned.fromRect(
                          rect: rect,
                          child: ClipRRect(
                            borderRadius: BorderRadius.lerp(
                              PaperfoldShape.controlRadius,
                              PaperfoldShape.sheetRadius,
                              t,
                            )!,
                            child: ColoredBox(
                              color: Theme.of(context).colorScheme.surface,
                              child: OverflowBox(
                                alignment: Alignment.topCenter,
                                minWidth: end.width,
                                maxWidth: end.width,
                                minHeight: end.height,
                                maxHeight: end.height,
                                child: Opacity(
                                  opacity: reduced
                                      ? animation.value
                                      : const Interval(
                                          0.6,
                                          1,
                                        ).transform(animation.value),
                                  child: child,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ) ??
      false;
}

class NewEntrySheet extends StatefulWidget {
  const NewEntrySheet({
    super.key,
    this.request,
    this.dao,
    this.draft,
    this.books,
  });
  final QuickCaptureRequest? request;
  final JournalDao? dao;
  final EntryDraft? draft;
  final List<Book>? books;
  @override
  State<NewEntrySheet> createState() => _NewEntrySheetState();
}

class _NewEntrySheetState extends State<NewEntrySheet> {
  late final _draft = widget.draft ?? EntryDraft();
  int _entryId = -DateTime.now().microsecondsSinceEpoch;
  final _text = TextEditingController();
  final _location = TextEditingController();
  final _total = TextEditingController();
  final _focus = FocusNode();
  List<Book> _books = [];
  int _bookId = 0;
  QuickCaptureKind _kind = QuickCaptureKind.note;
  String? _photo;
  String? _locator;
  double? _progress;
  bool _ready = false, _busy = false, _failed = false, _invalid = false;
  Book? get _book => _books.where((b) => b.id == _bookId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final books = widget.books ?? await bookDao.selectNotDeleteBooks();
      final draft = await _draft.read();
      _entryId = draft?['entryId'] as int? ?? _entryId;
      if (!mounted) return;
      _books = books;
      _bookId =
          draft?['bookId'] as int? ?? (books.isEmpty ? 0 : books.first.id);
      _kind =
          QuickCaptureKind.values
              .where((k) => k.name == draft?['kind'])
              .firstOrNull ??
          QuickCaptureKind.note;
      _text.text = draft?['text'] as String? ?? '';
      _location.text = draft?['location'] as String? ?? '';
      _total.text = draft?['total'] as String? ?? '';
      _photo = draft?['photo'] as String?;
      _locator = draft?['locator'] as String?;
      _progress = (draft?['progress'] as num?)?.toDouble();
      if (draft?['facing'] == true)
        _location.text =
            draft?['label'] as String? ?? '${draft?['page'] ?? ''}';
      if (widget.request case final request?) {
        // Preserve a recovered draft rather than silently replacing its writing.
        _kind = request.kind;
        _bookId = request.bookId ?? _bookId;
        if (request.text?.isNotEmpty ?? false)
          _text.text = [
            _text.text,
            request.text!,
          ].where((s) => s.isNotEmpty).join('\n');
      }
      if (_book == null) _bookId = 0;
      for (final controller in [_text, _location, _total]) {
        controller.addListener(_persist);
      }
      setState(() => _ready = true);
      await _persist();
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route?.animation?.status == AnimationStatus.forward) {
        void listener(AnimationStatus status) {
          if (status == AnimationStatus.completed) {
            route?.animation?.removeStatusListener(listener);
            if (mounted) _focus.requestFocus();
          }
        }

        route?.animation?.addStatusListener(listener);
      } else {
        _focus.requestFocus();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _persist() async {
    if (!_ready) return;
    try {
      await _draft.write({
        'entryId': _entryId,
        'bookId': _bookId,
        'kind': _kind.name,
        'text': _text.text,
        'location': _location.text,
        'total': _total.text,
        'photo': _photo,
        'locator': _locator,
        'progress': _progress,
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _takePhoto() async {
    setState(() => _busy = true);
    try {
      final source = canTakeCoverPhoto
          ? await takeCoverPhoto()
          : await chooseCoverFile();
      if (source != null) {
        final path = await savePagePhoto(source);
        if (!mounted) return;
        setState(() => _photo = path);
        await _persist();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final page = int.tryParse(_location.text.trim());
    final total = _total.text.isEmpty
        ? _book?.totalPages
        : int.tryParse(_total.text);
    final progress = _kind == QuickCaptureKind.progress;
    if (progress &&
        (_book?.isPhysical != true ||
            page == null ||
            !validPhysicalProgress(page, total) ||
            (_total.text.isNotEmpty && total == null))) {
      setState(() => _invalid = true);
      return;
    }
    final entry = JournalPage(
      id: _entryId,
      bookId: _bookId,
      pageIndex: 0,
      entryKind: _kind.name,
      body: _kind == QuickCaptureKind.quote ? '' : _text.text,
      sourceExcerpt: _kind == QuickCaptureKind.quote ? _text.text : null,
      sourcePage: page,
      sourceLocator: _locator,
      sourceProgress: _progress,
      sourceLabel: _location.text.isEmpty ? null : _location.text,
      photoPath: _photo,
    );
    if (entry.isEmpty) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await _persist();
      await (widget.dao ?? journalDao).saveEntry(
        entry,
        physicalPage: progress ? page : null,
        totalPages: total,
      );
      try {
        await _draft.clear();
      } catch (_) {
        // The database commit succeeded. Do not offer a second Save.
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted)
        setState(() {
          _failed = true;
          _busy = false;
        });
    }
  }

  @override
  void dispose() {
    for (final controller in [_text, _location, _total]) {
      controller.dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final labels = [
      l.entryNote,
      l.entryQuote,
      l.bookshelfProgress,
      l.entryPhoto,
    ];
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(PaperfoldSpace.sm),
                child: PaperfoldGlassSurface(
                  child: Row(
                    children: [
                      const CloseButton(),
                      Expanded(
                        child: Text(
                          l.newEntry,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: !_ready
                    ? Center(
                        child: _failed
                            ? TextButton(
                                onPressed: _load,
                                child: Text(l.commonFailed),
                              )
                            : const CircularProgressIndicator(),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PaperfoldSpace.sheetGutter,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<int>(
                              initialValue: _bookId,
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(
                                  value: 0,
                                  child: Text(l.entryUnassigned),
                                ),
                                ..._books.map(
                                  (book) => DropdownMenuItem(
                                    value: book.id,
                                    child: Text(
                                      book.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (id) {
                                      setState(() {
                                        _bookId = id ?? 0;
                                        _locator = null;
                                        _progress = null;
                                      });
                                      _persist();
                                    },
                            ),
                            const SizedBox(height: PaperfoldSpace.sm),
                            Wrap(
                              spacing: PaperfoldSpace.xs,
                              children: [
                                for (final kind in QuickCaptureKind.values)
                                  ChoiceChip(
                                    label: Text(labels[kind.index]),
                                    selected: kind == _kind,
                                    onSelected: _busy
                                        ? null
                                        : (_) {
                                            setState(() => _kind = kind);
                                            _persist();
                                          },
                                  ),
                              ],
                            ),
                            TextField(
                              controller: _text,
                              focusNode: _focus,
                              readOnly: _busy,
                              minLines: 4,
                              maxLines: null,
                              style: const TextStyle(
                                fontFamily: 'SourceSans3',
                                fontSize: 18,
                                height: 28 / 18,
                              ),
                              decoration: InputDecoration(
                                hintText: l.journalPageHint,
                                border: InputBorder.none,
                              ),
                            ),
                            TextField(
                              controller: _location,
                              readOnly: _busy,
                              decoration: InputDecoration(
                                labelText: l.entryLocation,
                                errorText: _invalid
                                    ? l.physicalBookPagesInvalid
                                    : null,
                              ),
                            ),
                            if (_kind == QuickCaptureKind.progress &&
                                _book?.totalPages == null)
                              TextField(
                                controller: _total,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: l.physicalBookTotalPages,
                                ),
                              ),
                            const SizedBox(height: PaperfoldSpace.sm),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _takePhoto,
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: Text(l.entryPhoto),
                            ),
                            if (_photo != null) JournalPhoto(path: _photo!),
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
              ),
              Padding(
                padding: const EdgeInsets.all(PaperfoldSpace.sheetGutter),
                child: SizedBox(
                  height: PaperfoldSize.primary,
                  child: FilledButton(
                    onPressed: _ready && !_busy ? _save : null,
                    child: Text(l.commonSave),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
