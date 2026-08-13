import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/book_notes/book_notes_list.dart';
import 'package:paperfold/widgets/reading_page/widget_title.dart';
import 'package:flutter/material.dart';

import 'package:paperfold/models/book.dart';

class ReadingNotes extends StatelessWidget {
  const ReadingNotes({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    // The panel used to reserve screen height minus a constant, which left it
    // either clipped or floating on a screen the constant did not match. The
    // shell that holds the panel bounds it now, so it only has to fill what it
    // is given.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          widgetTitle(context, L10n.of(context).navBarNotes, null),
          Flexible(
            child:
                ListView(children: [BookNotesList(book: book, reading: true)]),
          ),
        ],
      ),
    );
  }
}
