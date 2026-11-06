import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:paperfold/dao/reading_time.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/enums/book_binding.dart';
import 'package:paperfold/enums/hint_key.dart';
import 'package:paperfold/enums/sync_direction.dart';
import 'package:paperfold/enums/sync_trigger.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/reading_time.dart';
import 'package:paperfold/models/tag.dart';
import 'package:paperfold/page/book_edit_page.dart';
import 'package:paperfold/providers/sync.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/tags.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/service/book_binding.dart';
import 'package:paperfold/service/book_binding_settings.dart';
import 'package:paperfold/utils/date/convert_seconds.dart';
import 'package:paperfold/utils/color/hash_color.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/book_light.dart';
import 'package:paperfold/widgets/common/paperfold_pane.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';
import 'package:paperfold/widgets/bookshelf/book_detail_route.dart';
import 'package:paperfold/widgets/bookshelf/book_bottom_sheet.dart';
import 'package:paperfold/widgets/bookshelf/shelf_controls/shelf_book_actions.dart';
import 'package:paperfold/page/journal/book_journal_page.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/common/anx_segmented_button.dart';
import 'package:paperfold/widgets/common/async_skeleton_wrapper.dart';
import 'package:paperfold/widgets/common/container/filled_container.dart';
import 'package:paperfold/widgets/common/color_picker_sheet.dart';
import 'package:paperfold/widgets/common/tag_chip.dart';
import 'package:paperfold/widgets/highlight_digit.dart';
import 'package:paperfold/widgets/hint/hint_banner.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookDetail extends ConsumerStatefulWidget {
  const BookDetail({
    super.key,
    required this.book,
    this.wishlist = false,
    this.heroId,
  });

  final Book book;
  final bool wishlist;
  final String? heroId;

  @override
  ConsumerState<BookDetail> createState() => _BookDetailState();
}

class _BookDetailState extends ConsumerState<BookDetail> {
  late double rating;
  bool isEditing = false;
  late Book _book;
  final TextEditingController _newTagController = TextEditingController();
  Color? _pendingTagColor;

  /// The tags this book carries, when they have already loaded.
  ///
  /// The binding reads them, because "manga" is far more often a tag than a
  /// word in a description. A tag that has not arrived yet only means the
  /// first frame guesses from the description alone.
  List<String> get _tagNames {
    final state = ref.watch(bookTagEditorProvider(widget.book.id)).value;
    if (state == null) return const [];
    return [
      for (final tag in state.tags)
        if (state.isAttached(tag.id)) tag.name,
    ];
  }

  BookBindingVerdict get _verdict =>
      widget.book.bindingVerdict(tags: _tagNames);

  @override
  void initState() {
    super.initState();
    rating = widget.book.rating;
    _book = widget.book;
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final percent = _book.readingPercentage.isFinite
        ? _book.readingPercentage.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final primaryLabel = _book.isPhysical
        ? l10n.physicalBookLogProgress
        : percent > 0
        ? l10n.tileContinueReadingTitle
        : l10n.bookStartReading;
    final cover = BookCover(
      book: _book,
      width: 144,
      height: 208,
      radius: PaperfoldShape.object,
    );
    Widget buildBookBaseDetail(double width) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: PaperfoldShape.paneRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.onSurface.withValues(alpha: .08),
                  Colors.transparent,
                ],
                stops: const [0, .4],
              ),
            ),
            child: PaperfoldPane(
              tier: PaperfoldGlassTier.glassine,
              padding: const EdgeInsets.all(PaperfoldSpace.lg),
              child: BookDetailHero(
                id: widget.heroId ?? 'book-${_book.id}',
                cover: cover,
                child: cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: PaperfoldSpace.lg),
        BookDetailArrival(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _book.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: PaperfoldTypeTokens.journalFamily,
                ),
              ),
              const SizedBox(height: PaperfoldSpace.xs),
              Text(
                [
                  _book.author,
                  _book.isPhysical
                      ? l10n.physicalBookAdd
                      : _book.filePath.split('.').last.toUpperCase(),
                ].where((s) => s.isNotEmpty).join(' · '),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PaperfoldSpace.md),
              if (!widget.wishlist)
                PaperfoldPane(
                  tier: PaperfoldGlassTier.glassine,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.bookProgressThrough((percent * 100).round()),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: PaperfoldSpace.xs),
                      LinearProgressIndicator(value: percent),
                      if (_book.isPhysical)
                        Text(
                          '${l10n.physicalBookCurrentPage}: ${_book.currentPage}',
                        ),
                      if (_book.startedOn != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: PaperfoldSpace.xs,
                          ),
                          child: Text(
                            l10n.bookStartedOn(
                              MaterialLocalizations.of(context)
                                  .formatShortDate(_book.startedOn!),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: PaperfoldSpace.sm),
              if (!widget.wishlist)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BookJournalPage(book: _book),
                          ),
                        ),
                        icon: const Icon(Icons.edit_note),
                        label: Text(l10n.navJournal),
                      ),
                    ),
                    const SizedBox(width: PaperfoldSpace.xs),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => showShelfBookShelvesSheet(
                          context,
                          _book,
                          onChanged: () async {},
                        ),
                        icon: const Icon(Icons.library_books_outlined),
                        label: Text(l10n.shelfBookOptionShelves),
                      ),
                    ),
                  ],
                ),
              if (_book.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: PaperfoldSpace.lg,
                  ),
                  child: Text(_book.description!),
                ),
            ],
          ),
        ),
      ],
    );

    Widget buildEditButton() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: HintBanner(
              hintKey: HintKey.editBookDetails,
              margin: EdgeInsetsDirectional.only(end: 10),
              child: Text(L10n.of(context).bookDetailEditHint),
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit),
            label: Text(L10n.of(context).bookEditTitle),
            onPressed: () async {
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => BookEditPage(book: widget.book),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
        ],
      );
    }

    /// How this book is bound, why, and how to overrule it.
    ///
    /// The reason is on the page next to the control because the choice is a
    /// guess made from metadata the reader can edit. A guess that cannot be
    /// seen cannot be argued with, and this one is wrong often enough to need
    /// arguing with.
    Widget buildBindingSection() {
      final theme = Theme.of(context);
      final verdict = _verdict;
      final choice = Prefs().bookBindingChoice(widget.book.id);
      final explanation = switch (verdict.reason) {
        BookBindingReason.reader => L10n.of(context).bookBindingWhyReader,
        BookBindingReason.statedFormat => L10n.of(
          context,
        ).bookBindingWhyStatedFormat(verdict.evidence ?? ''),
        BookBindingReason.comicOrLightNovel => L10n.of(
          context,
        ).bookBindingWhyComic,
        BookBindingReason.modernPublication => L10n.of(
          context,
        ).bookBindingWhyModern(verdict.evidence ?? ''),
        BookBindingReason.earlyPublication => L10n.of(
          context,
        ).bookBindingWhyEarly(verdict.evidence ?? ''),
        BookBindingReason.publicDomain => L10n.of(
          context,
        ).bookBindingWhyPublicDomain,
        BookBindingReason.libraryDefault => L10n.of(
          context,
        ).bookBindingWhyDefault,
      };

      return FilledContainer(
        width: MediaQuery.of(context).size.width,
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.of(context).bookBindingSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AnxSegmentedButton<BookBindingChoice>(
                segments: [
                  SegmentButtonItem(
                    value: BookBindingChoice.automatic,
                    label: L10n.of(context).bookBindingAutomatic,
                  ),
                  SegmentButtonItem(
                    value: BookBindingChoice.hardback,
                    label: L10n.of(context).bookBindingHardback,
                  ),
                  SegmentButtonItem(
                    value: BookBindingChoice.softback,
                    label: L10n.of(context).bookBindingSoftback,
                  ),
                ],
                selected: {choice},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() {
                    Prefs().setBookBindingChoice(
                      widget.book.id,
                      selection.first,
                    );
                  });
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              explanation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildBookStatistics() {
      Widget buildNthBooksItem() {
        // `Colors.grey` measures 2.49:1 on the light paper ground, under the
        // 4.5:1 minimum in DESIGN.md. The role measures 7.77:1.
        final TextStyle textStyle = Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
        TextStyle digitStyle = const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
        );

        return Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: highlightDigit(
            context,
            L10n.of(context).bookDetailNthBook(widget.book.id),
            textStyle,
            digitStyle,
          ),
        );
      }

      Widget buildRankItem() {
        return Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: rating.toString(),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
                TextSpan(
                  text: ' / 5',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      Widget buildReadingTimeItem() {
        TextStyle digitStyle = TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge!.color,
        );
        // `Colors.grey` measures 2.49:1 on the light paper ground, under the
        // 4.5:1 minimum in DESIGN.md. The role measures 7.77:1.
        final TextStyle textStyle = Theme.of(context).textTheme.bodyMedium!
            .copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
        return FutureBuilder<int>(
          future: readingTimeDao.selectTotalReadingTimeByBookId(widget.book.id),
          builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
            if (snapshot.hasData) {
              int totalReadingTime = snapshot.data!;
              int hours = totalReadingTime ~/ 3600;
              int minutes = totalReadingTime % 3600 ~/ 60;
              return Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: Row(
                  children: [
                    highlightDigit(
                      context,
                      L10n.of(context).commonHours(hours),
                      textStyle,
                      digitStyle,
                    ),
                    highlightDigit(
                      context,
                      L10n.of(context).commonMinutes(minutes),
                      textStyle,
                      digitStyle,
                    ),
                  ],
                ),
              );
            } else {
              return const Padding(
                padding: EdgeInsets.only(left: 20, right: 20),
                child: CircularProgressIndicator(),
              );
            }
          },
        );
      }

      VerticalDivider verticalDivider = const VerticalDivider(
        color: Colors.black12,
        thickness: 1,
        indent: 15,
        endIndent: 15,
      );

      return SizedBox(
        height: 130,
        width: MediaQuery.of(context).size.width,
        child: FilledContainer(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            scrollDirection: Axis.horizontal,
            children: [
              Row(
                children: [
                  buildNthBooksItem(),
                  verticalDivider,
                  buildRankItem(),
                  verticalDivider,
                  buildReadingTimeItem(),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget buildTagEditor() {
      return FilledContainer(
        width: MediaQuery.of(context).size.width,
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(12),
        child: AsyncSkeletonWrapper(
          asyncValue: ref.watch(bookTagEditorProvider(widget.book.id)),
          // Without a mock the wrapper logs a SEVERE and drops to a spinner,
          // so every rebuild of this section flashed a loading circle where
          // the tags had just been. An empty state is the honest skeleton:
          // no tags are known yet.
          mock: const BookTagState(tags: [], attachedIds: {}),
          builder: (state, _) {
            final notifier = ref.read(
              bookTagEditorProvider(widget.book.id).notifier,
            );
            Future<void> showTagEditDialog(Tag tag) async {
              await TagChip.showEditDialog(
                context: context,
                initialName: tag.name,
                initialColor: tag.color ?? hashColor(tag.name),
                onRename: (newName) async {
                  await ref
                      .read(tagListProvider.notifier)
                      .updateTag(tag.id, newName: newName);
                  ref.read(bookListProvider.notifier).refresh();
                  ref.invalidate(bookTagEditorProvider(widget.book.id));
                },
                onColorChange: (color) async {
                  await ref
                      .read(tagListProvider.notifier)
                      .updateTag(tag.id, color: color);
                  ref.read(bookListProvider.notifier).refresh();
                  ref.invalidate(bookTagEditorProvider(widget.book.id));
                },
                onDelete: () async {
                  await ref.read(tagListProvider.notifier).deleteTag(tag.id);
                  await notifier.detach(tag);
                  ref.read(bookListProvider.notifier).refresh();
                  ref.invalidate(bookTagEditorProvider(widget.book.id));
                },
              );
            }

            Future<void> toggle(Tag tag) async {
              final currentlySelected = state.isAttached(tag.id);
              if (currentlySelected) {
                await notifier.detach(tag);
              } else {
                await notifier.attachExisting(tag);
              }
              ref.read(bookListProvider.notifier).refresh();
            }

            final attachedTags = state.tags
                .where((t) => state.isAttached(t.id))
                .toList();

            if (!isEditing) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          L10n.of(context).tagsSectionTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 18),
                        label: Text(L10n.of(context).bookDetailEdit),
                        onPressed: () => setState(() => isEditing = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  attachedTags.isEmpty
                      ? Column(
                          children: [
                            HintBanner(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              hintKey: HintKey.addTags,
                              child: Text(L10n.of(context).tagsEditHint),
                            ),
                            Text(L10n.of(context).tagsEmptyHint),
                          ],
                        )
                      : Column(
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: attachedTags
                                  .map(
                                    (tag) => TagChip(
                                      label: tag.name,
                                      color: tag.color,
                                      selected: true,
                                      dense: true,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      L10n.of(context).tagsSectionTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: TextField(
                                controller: _newTagController,
                                decoration: InputDecoration(
                                  hintText: L10n.of(context).tagNewPlaceholder,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (_) {
                                  setState(() {
                                    final text = _newTagController.text.trim();
                                    _pendingTagColor = text.isEmpty
                                        ? null
                                        : hashColor(text);
                                  });
                                },
                                onSubmitted: (value) async {
                                  if (value.trim().isEmpty) return;
                                  final color =
                                      _pendingTagColor ??
                                      hashColor(value.trim());
                                  await notifier.createAndAttach(
                                    value.trim(),
                                    color: color,
                                  );
                                  ref.read(bookListProvider.notifier).refresh();
                                  _newTagController.clear();
                                  _pendingTagColor = null;
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final currentText = _newTagController.text.trim();
                              final defaultColor =
                                  _pendingTagColor ??
                                  (currentText.isEmpty
                                      ? hashColor('tag')
                                      : hashColor(currentText));
                              return IconButton(
                                tooltip: L10n.of(context).tagColorTooltip,
                                icon: Icon(Icons.circle, color: defaultColor),
                                onPressed: currentText.isEmpty
                                    ? null
                                    : () async {
                                        final picked = await showRgbColorPicker(
                                          context: context,
                                          initialColor: defaultColor,
                                          allowAlpha: false,
                                        );
                                        if (picked != null) {
                                          setState(() {
                                            _pendingTagColor = picked;
                                          });
                                        }
                                      },
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton(
                            onPressed: () async {
                              final value = _newTagController.text.trim();
                              if (value.isEmpty) return;
                              final color =
                                  _pendingTagColor ?? hashColor(value);
                              await notifier.createAndAttach(
                                value,
                                color: color,
                              );
                              ref.read(bookListProvider.notifier).refresh();
                              _newTagController.clear();
                              _pendingTagColor = null;
                              setState(() {});
                            },
                            child: Text(L10n.of(context).tagAddButton),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (state.tags.isNotEmpty)
                  HintBanner(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    hintKey: HintKey.editOrRemoveTags,
                    child: Text(L10n.of(context).tagsEditOrRemoveHint),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: state.tags
                      .map(
                        (tag) => TagChip(
                          label: tag.name,
                          color: tag.color,
                          selected: state.isAttached(tag.id),
                          onTap: () => toggle(tag),
                          onLongPress: () => showTagEditDialog(tag),
                          dense: false,
                        ),
                      )
                      .toList(),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(L10n.of(context).bookDetailSave),
                    onPressed: () {
                      setState(() => isEditing = false);
                      Sync().syncData(
                        SyncDirection.upload,
                        ref,
                        trigger: SyncTrigger.manual,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    Widget buildMoreDetail() {
      Widget buildReadingDetail() {
        return FutureBuilder<List<ReadingTime>>(
          future: readingTimeDao.selectReadingTimeByBookId(widget.book.id),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<ReadingTime>> snapshot,
              ) {
                if (snapshot.hasData) {
                  List<ReadingTime> readingTimes = snapshot.data!;
                  return Column(
                    children: List.generate(readingTimes.length, (index) {
                      int totalReadingTime = readingTimes[index].readingTime;
                      return Row(
                        children: [
                          Text(
                            readingTimes[index].dateOnly ??
                                readingTimes[index].date ??
                                '',
                            style: const TextStyle(fontSize: 15),
                          ),
                          const Spacer(),
                          Text(
                            convertSeconds(totalReadingTime),
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      );
                    }),
                  );
                } else {
                  return const CircularProgressIndicator();
                }
              },
        );
      }

      TextStyle textStyle = const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
      );
      return SingleChildScrollView(
        child: SizedBox(
          // height: 500,
          width: MediaQuery.of(context).size.width,
          child: FilledContainer(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${L10n.of(context).bookDetailImportDate}${widget.book.createTime.toString().substring(0, 10)}',
                  style: textStyle,
                ),
                Text(
                  '${L10n.of(context).bookDetailLastReadDate}${widget.book.updateTime.toString().substring(0, 10)}',
                  style: textStyle,
                ),
                const Divider(),
                SizedBox(
                  // height: 200,
                  child: buildReadingDetail(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          if (!widget.wishlist)
            PopupMenuButton<String>(
              tooltip: l10n.more,
              onSelected: (value) {
                if (value == 'other') {
                  showModalBottomSheet<void>(
                    context: context,
                    useSafeArea: true,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => BookBottomSheet(book: _book),
                  );
                } else {
                  showModalBottomSheet<void>(
                    context: context,
                    useSafeArea: true,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (context) => SingleChildScrollView(
                      padding: const EdgeInsets.all(PaperfoldSpace.sheetGutter),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (value == 'customise') buildBindingSection(),
                          if (value == 'details') ...[
                            RatingBar.builder(
                              initialRating: rating,
                              allowHalfRating: true,
                              itemSize: 48,
                              itemBuilder: (_, _) => Icon(
                                Icons.star,
                                color: theme.colorScheme.primary,
                              ),
                              onRatingUpdate: (value) {
                                setState(() => rating = value);
                                updateBookRating(_book, value);
                              },
                            ),
                            buildTagEditor(),
                            buildEditButton(),
                            buildBookStatistics(),
                            buildMoreDetail(),
                          ],
                        ],
                      ),
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'details',
                  child: Text(l10n.shelfBookOptionDetails),
                ),
                PopupMenuItem(
                  value: 'customise',
                  child: Text(l10n.shelfBookOptionCustomise),
                ),
                PopupMenuItem(
                  value: 'other',
                  child: Text(l10n.shelfBookOptions),
                ),
              ],
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: BookLight(
        coverPath: _book.coverFullPath,
        fallback: BookSpine.resolveVisual(
          'book-${_book.id}',
          theme.colorScheme,
        ).background,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PaperfoldSpace.gutter),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: buildBookBaseDetail(MediaQuery.sizeOf(context).width),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: widget.wishlist
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(PaperfoldSpace.gutter),
                child: Center(
                  heightFactor: 1,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: FilledButton.icon(
                      key: const ValueKey('open-shelf-book'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          PaperfoldSize.primary,
                        ),
                      ),
                      onPressed: () => pushToReadingPage(ref, context, _book),
                      icon: Icon(
                        _book.isPhysical
                            ? Icons.edit_note
                            : Icons.menu_book_outlined,
                      ),
                      label: Text(primaryLabel),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
