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
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            PaperfoldSpace.gutter,
            0,
            PaperfoldSpace.gutter,
            bottom + PaperfoldSize.fab + PaperfoldSpace.xl,
          ),
          children: [
            Text(
              '${DateFormat.MMMMEEEEd(Localizations.localeOf(context).toLanguageTag()).format(now)}${today == null ? '' : ' · ${l.pagesToday(today)}'}',
            ),
            const SizedBox(height: PaperfoldSpace.md),
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
              ...entries.when(
                data: (items) => items
                    .map(
                      (entry) => ListTile(
                        title: Text(entry.book.title),
                        subtitle: Text(l.journalPagesCount(entry.pageCount)),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BookJournalPage(book: entry.book),
                          ),
                        ),
                      ),
                    )
                    .toList(),
                error: (_, _) => [Text(l.journalLoadFailed)],
                loading: () => [const LinearProgressIndicator()],
              )
            else ...[
              for (var i = 0; i < _pages.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: PaperfoldSpace.sm),
                  child: i == featured && _books[_pages[i].bookId] != null
                      ? BookLight(
                          coverPath: _books[_pages[i].bookId]!.coverFullPath,
                          fallback: Theme.of(context).colorScheme.primary,
                          borderRadius: PaperfoldShape.paneRadius,
                          fade: false,
                          child: Padding(
                            padding: const EdgeInsets.all(PaperfoldSpace.sm),
                            child: PaperfoldGlassSurface(
                              tier: PaperfoldGlassTier.glassine,
                              borderRadius: PaperfoldShape.controlRadius,
                              child: _entry(_pages[i]),
                            ),
                          ),
                        )
                      : _entry(_pages[i]),
                ),
              if (_pages.isEmpty && !_loading && !_failed)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: PaperfoldSpace.xl,
                  ),
                  child: Text(l.journalPlaceholderTitle),
                ),
              if (_loading) const Center(child: CircularProgressIndicator()),
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
            const SizedBox(height: PaperfoldSpace.lg),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                children: [
                  for (final record in [
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
                  ])
                    SizedBox(
                      width:
                          constraints.maxWidth /
                          (MediaQuery.textScalerOf(context).scale(1) > 1.5
                              ? 1
                              : 3),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (_) => record.$3),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: PaperfoldSpace.xs,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(record.$1),
                              const SizedBox(height: PaperfoldSpace.xs),
                              Text(record.$2, textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entry(JournalPage page) {
    final book = _books[page.bookId];
    return Padding(
      padding: const EdgeInsets.all(PaperfoldSpace.pane),
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
              child: Text(page.body),
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
