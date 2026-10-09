import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/book_notes_page.dart';
import 'package:paperfold/providers/notes_page_current_book.dart';
import 'package:paperfold/providers/notes_statistics.dart';
import 'package:paperfold/utils/date/convert_seconds.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/common/container/filled_container.dart';
import 'package:paperfold/widgets/common/load_failure.dart';
import 'package:paperfold/widgets/highlight_digit.dart';
import 'package:paperfold/widgets/tips/notes_tips.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key, this.controller});

  final ScrollController? controller;

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  late final ScrollController _scrollController =
      widget.controller ?? ScrollController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            return Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      notesStatistic(),
                      bookNotesList(false),
                    ],
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                const Expanded(
                  flex: 2,
                  child: NotesDetail(),
                ),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                notesStatistic(),
                bookNotesList(true),
              ],
            );
          }
        },
      ),
    );
  }

  Widget notesStatistic() {
    final notesStats = ref.watch(notesStatisticsProvider);
    final theme = Theme.of(context);

    // Material roles. These carried a hardcoded `SourceHanSerif`, which set
    // the Journal's own statistics in a CJK serif in every language and
    // ignored the Paperfold text theme. The theme already substitutes a
    // Chinese face where one is needed.
    final TextStyle digitStyle = theme.textTheme.headlineSmall!.copyWith(
      fontWeight: FontWeight.bold,
    );
    final TextStyle textStyle = theme.textTheme.titleMedium!;

    return notesStats.when(
      data: (data) {
        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              highlightDigit(
                context,
                L10n.of(context).notesNotesAcross(data['numberOfNotes']!),
                textStyle,
                digitStyle,
              ),
              highlightDigit(
                context,
                L10n.of(context).notesBooks(data['numberOfBooks']!),
                textStyle,
                digitStyle,
              ),
            ]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => LoadFailure.inline(
        title: L10n.of(context).notesLoadFailed,
        error: error,
      ),
    );
  }

  Widget bookNotesList(bool isMobile) {
    final bookIdAndNotes = ref.watch(bookIdAndNotesProvider);

    return bookIdAndNotes.when(
      data: (data) {
        return data.isEmpty
            ? const Expanded(child: Center(child: NotesTips()))
            : Expanded(
                child: ListView.builder(
                    // The Journal's note list is pushed as its own route with
                    // its own app bar. Nothing floats over its foot, so the
                    // 80 logical pixels reserved here were dead space.
                    padding: const EdgeInsets.only(bottom: 12),
                    controller: _scrollController,
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      return bookNotesItem(
                        book: data[index]['book']!,
                        numberOfNotes: data[index]['numberOfNotes']!,
                        isMobile: isMobile,
                        readingTime: data[index]['readingTime']!,
                      );
                    }),
              );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => LoadFailure.inline(
        title: L10n.of(context).notesLoadFailed,
        error: error,
      ),
    );
  }

  Widget bookNotesItem({
    required Book book,
    required int numberOfNotes,
    required bool isMobile,
    required int readingTime,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final TextStyle digitStyle = theme.textTheme.headlineSmall!.copyWith(
      fontWeight: FontWeight.bold,
    );
    final TextStyle textStyle = theme.textTheme.titleMedium!;
    final TextStyle titleStyle = theme.textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.bold,
      overflow: TextOverflow.ellipsis,
    );
    // `Colors.grey` measures 2.49:1 on the light paper ground, under the
    // 4.5:1 minimum in DESIGN.md. The role measures 7.77:1.
    final TextStyle readingTimeStyle = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );

    void open() {
      if (isMobile) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => BookNotesPage(
                    book: book,
                    numberOfNotes: numberOfNotes,
                    isMobile: true,
                  )),
        );
      } else {
        ref
            .read(notesPageCurrentBookProvider.notifier)
            .setData(book, numberOfNotes);
      }
    }

    // A GestureDetector stood here: no ink, no focus, and no button role, so
    // a screen reader read the row as loose text with nothing to activate.
    return Semantics(
      button: true,
      label: book.title,
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(12),
        child: FilledContainer(
          margin: const EdgeInsetsDirectional.only(top: 8, start: 15, end: 15),
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    highlightDigit(
                      context,
                      L10n.of(context).notesNotes(numberOfNotes),
                      textStyle,
                      digitStyle,
                    ),
                    const SizedBox(height: 8),
                    Text(book.title, style: titleStyle),
                    const SizedBox(height: 18),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            convertSeconds(readingTime),
                            style: readingTimeStyle,
                          ),
                          Text(' | ', style: readingTimeStyle),
                          Icon(Icons.bar_chart,
                              size: 16, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            '${(book.readingPercentage * 100).toStringAsFixed(1)}%',
                            style: readingTimeStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Hero(
                tag: isMobile
                    ? book.coverFullPath
                    : '${book.coverFullPath}notMobile',
                child: BookCover(
                  book: book,
                  height: 130,
                  width: 90,
                  // DESIGN.md gives cover art a 10 dp radius. 20 rounded the
                  // corners off a book.
                  radius: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotesDetail extends ConsumerWidget {
  const NotesDetail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(notesPageCurrentBookProvider).when(
          data: (current) {
            return BookNotesPage(
                isMobile: false,
                book: current.book,
                numberOfNotes: current.numberOfNotes);
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => NotesTips(),
        );
  }
}
