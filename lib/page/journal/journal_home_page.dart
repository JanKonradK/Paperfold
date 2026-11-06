import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/widgets/common/paperfold_transition.dart';
import 'package:paperfold/dao/journal.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/models/journal_page.dart';
import 'package:paperfold/page/journal/book_journal_page.dart';
import 'package:paperfold/page/journal/month_tracker_page.dart';
import 'package:paperfold/page/journal/reading_challenge_page.dart';
import 'package:paperfold/page/journal/new_entry_sheet.dart';
import 'package:paperfold/page/home_page/notes_page.dart';
import 'package:paperfold/providers/journal_home.dart';
import 'package:paperfold/providers/month_tracker.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/service/quick_capture.dart';
import 'package:paperfold/utils/paperfold_layout.dart';
import 'package:paperfold/widgets/common/paperfold_grid.dart';
import 'package:paperfold/widgets/common/paperfold_pane.dart';
import 'package:paperfold/widgets/book_light.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';
import 'package:paperfold/page/journal/journal_photo.dart';
import 'package:paperfold/widgets/reading_page/facing_page.dart';

class JournalHomePage extends ConsumerStatefulWidget {
  const JournalHomePage({super.key, this.dao, this.books});
  final JournalDao? dao;
  final List<Book>? books;
  @override
  ConsumerState<JournalHomePage> createState() => _JournalHomePageState();
}

class _JournalHomePageState extends ConsumerState<JournalHomePage> {
  final _fab = GlobalKey();
  List<JournalPage> _pages = [];
  Map<int, Book> _books = {};
  bool _byBook = false,
      _loading = false,
      _more = true,
      _failed = false,
      _composing = false;
  @override
  void initState() {
    super.initState();
    _load(reset: true);
    QuickCapture.pending.addListener(_capture);
    WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
  }

  @override
  void dispose() {
    QuickCapture.pending.removeListener(_capture);
    super.dispose();
  }

  void _capture() {
    if (!mounted ||
        _composing ||
        QuickCapture.pending.value == null ||
        ModalRoute.of(context)?.isCurrent != true)
      return;
    _compose(QuickCapture.take());
  }

  Future<void> _compose([QuickCaptureRequest? request]) async {
    setState(() => _composing = true);
    final box = _fab.currentContext?.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    await showNewEntrySheet(context, request: request, origin: origin);
    if (!mounted) return;
    setState(() => _composing = false);
    ref.invalidate(journalHomeProvider);
    ref.invalidate(monthTrackerProvider);
    await _load(reset: true);
    _capture();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final source = ref.read(journalRecentSourceProvider);
      final offset = reset ? 0 : _pages.length;
      final pages = widget.dao != null
          ? await widget.dao!.recentEntries(offset: offset)
          : await source.entries(offset);
      final books = widget.books ?? await source.books();
      if (!mounted) return;
      setState(() {
        _pages = reset ? pages : [..._pages, ...pages];
        _books = {for (final book in books) book.id: book};
        _more = pages.length == 30;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final entries = ref.watch(journalHomeProvider);
    final now = DateTime.now();
    final today = ref
        .watch(monthTrackerProvider)
        .asData
        ?.value
        .pagesFor(now.day);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final currentBook = _books.values
        .where((book) => book.status == BookStatus.reading)
        .firstOrNull;
    final featured = currentBook == null
        ? -1
        : _pages.indexWhere((page) => page.bookId == currentBook.id);
    return Scaffold(
      appBar: AppBar(title: Text(l.navJournal)),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: AnimatedOpacity(
          opacity: _composing ? 0 : 1,
          duration: paperfoldTransitionDuration(context, PaperfoldMotion.tick),
          child: SizedBox(
            height: PaperfoldSize.fab,
            child: FloatingActionButton.extended(
              heroTag: 'journal-new-entry',
              key: _fab,
              onPressed: () => _compose(),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l.newEntry),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final layout = PaperfoldLayout.of(
              context,
              constraints: constraints,
            );
            final scheme = Theme.of(context).colorScheme;
            // Entries side by side only where each still reads as a page.
            final entryColumns = layout.landscape
                ? layout.columns(400, gap: 16, max: 3)
                : layout.content >= 840
                ? 2
                : 1;
            final tools = [
              (
                Icons.local_library_outlined,
                l.challengeTitle,
                const ReadingChallengePage(),
              ),
              (
                Icons.calendar_month_outlined,
                l.monthTrackerTitle,
                const MonthTrackerPage(),
              ),
              (
                Icons.format_quote_outlined,
                l.tileNotesTotalTitle,
                Scaffold(
                  appBar: AppBar(title: Text(l.tileNotesTotalTitle)),
                  body: const NotesPage(),
                ),
              ),
            ];
            return ListView(
              padding: EdgeInsets.fromLTRB(
                layout.gutter,
                0,
                layout.gutter,
                bottom + PaperfoldSize.fab + PaperfoldSpace.xl,
              ),
              children: [
                Text(
                  '${DateFormat.MMMMEEEEd(Localizations.localeOf(context).toLanguageTag()).format(now)}${today == null ? '' : ' · ${l.pagesToday(today)}'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: PaperfoldSpace.md),
                // The tools come first, so paging the feed never buries them.
                PaperfoldGrid(
                  columns: MediaQuery.textScalerOf(context).scale(1) > 1.5
                      ? 1
                      : layout.columns(160, max: 3),
                  equalHeight: true,
                  children: [
                    for (final tool in tools)
                      PaperfoldPane(
                        padding: const EdgeInsets.all(PaperfoldSpace.md),
                        color: scheme.surfaceContainerLow,
                        semanticLabel: tool.$2,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => tool.$3),
                        ),
                        child: Row(
                          children: [
                            Icon(tool.$1, color: scheme.primary),
                            const SizedBox(width: PaperfoldSpace.sm),
                            Expanded(
                              child: Text(
                                tool.$2,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: PaperfoldSpace.lg),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(l.recentEntries)),
                    ButtonSegment(value: true, label: Text(l.journalBooks)),
                  ],
                  selected: {_byBook},
                  onSelectionChanged: (value) =>
                      setState(() => _byBook = value.single),
                ),
                const SizedBox(height: PaperfoldSpace.md),
                if (_byBook)
                  entries.when(
                    data: (items) => PaperfoldGrid(
                      columns: layout.columns(280, gap: 16, max: 3),
                      gap: 16,
                      children: [
                        for (final entry in items)
                          PaperfoldPane(
                            color: scheme.surfaceContainerLow,
                            padding: EdgeInsets.all(layout.panePadding),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    BookJournalPage(book: entry.book),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.book.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(l.journalPagesCount(entry.pageCount)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    error: (_, _) => Text(l.journalLoadFailed),
                    loading: () => const LinearProgressIndicator(),
                  )
                else ...[
                  PaperfoldGrid(
                    columns: entryColumns,
                    gap: 16,
                    children: [
                      for (var i = 0; i < _pages.length; i++)
                        i == featured && _books[_pages[i].bookId] != null
                            ? BookLight(
                                coverPath:
                                    _books[_pages[i].bookId]!.coverFullPath,
                                fallback: scheme.primary,
                                borderRadius: PaperfoldShape.paneRadius,
                                fade: false,
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    PaperfoldSpace.sm,
                                  ),
                                  child: PaperfoldGlassSurface(
                                    tier: PaperfoldGlassTier.glassine,
                                    borderRadius: BorderRadius.circular(
                                      PaperfoldShape.nested(
                                        PaperfoldShape.pane,
                                        PaperfoldSpace.sm,
                                      ),
                                    ),
                                    child: _entry(_pages[i], layout),
                                  ),
                                ),
                              )
                            : PaperfoldPane(
                                color: scheme.surfaceContainerLow,
                                padding: EdgeInsets.zero,
                                child: _entry(_pages[i], layout),
                              ),
                    ],
                  ),
                  if (_pages.isEmpty && !_loading && !_failed)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: PaperfoldSpace.xl,
                      ),
                      child: Text(l.journalPlaceholderTitle),
                    ),
                  if (_loading)
                    const Center(child: CircularProgressIndicator()),
                  if (_failed)
                    TextButton(
                      onPressed: () => _load(reset: true),
                      child: Text(l.journalLoadFailed),
                    ),
                  if (_more && !_loading)
                    TextButton(
                      onPressed: _load,
                      child: const Icon(Icons.expand_more),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _entry(JournalPage page, PaperfoldLayout layout) {
    final book = _books[page.bookId];
    return Padding(
      padding: EdgeInsets.all(layout.panePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book?.title ?? L10n.of(context).entryUnassigned,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (page.updateTime != null)
            Text(
              MaterialLocalizations.of(context)
                  .formatMediumDate(page.updateTime!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (page.sourceExcerpt?.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: PaperfoldSpace.xs),
              child: Text(
                page.sourceExcerpt!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Philosopher',
                  fontSize: 17,
                  height: 24 / 17,
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
          if (page.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: PaperfoldSpace.xs),
              child: Text(
                page.body,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (page.photoPath != null) JournalPhoto(path: page.photoPath!),
          if (page.hasSource && book != null)
            TextButton.icon(
              onPressed: () async {
                try {
                  if (book.isPhysical) {
                    await showFacingPage(
                      context,
                      book: book,
                      page: page.sourcePage,
                      label: page.sourceLabel,
                    );
                  } else {
                    await pushToReadingPage(
                      ref,
                      context,
                      book,
                      cfi: page.sourceLocator ?? page.sourceCfi,
                    );
                  }
                } catch (_) {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          L10n.of(context).journalPassageOpenFailed,
                        ),
                      ),
                    );
                }
              },
              icon: const Icon(
                Icons.menu_book_outlined,
                size: PaperfoldSize.smallIcon,
              ),
              label: Text(
                [
                      page.sourceChapter,
                      page.sourceLabel ??
                          (page.sourcePage == null
                              ? null
                              : '${page.sourcePage}'),
                    ].whereType<String>().join(' · ').isEmpty
                    ? L10n.of(context).journalOpenPassage
                    : [
                        page.sourceChapter,
                        page.sourceLabel ?? '${page.sourcePage ?? ''}',
                      ].whereType<String>().join(' · '),
              ),
            ),
        ],
      ),
    );
  }
}
