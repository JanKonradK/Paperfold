import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/widgets/bookshelf/book_spine.dart';
import 'package:material_ui/material_ui.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.height,
    this.width,
    this.radius,
  });

  final Book book;
  final double? height;
  final double? width;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final double effectiveRadius = radius ?? 3;
    final BorderRadius borderRadius = BorderRadius.circular(effectiveRadius);
    final fallback = LayoutBuilder(
      builder: (context, constraints) {
        final coverWidth = constraints.maxWidth;

        // Calculate responsive sizes based on width
        final titleFontSize = coverWidth * 0.12;
        final authorFontSize = coverWidth * 0.08;
        final padding = coverWidth * 0.08;

        final visual = BookSpine.resolveVisual(
            'book-${book.id}', Theme.of(context).colorScheme);
        final backgroundColor = visual.background;
        final textColor = visual.foreground;

        final showTitle = Prefs().showBookTitleOnDefaultCover;
        final showAuthor = Prefs().showAuthorOnDefaultCover;

        return Container(
          color: backgroundColor,
          child: Stack(
            children: [
              // Text content (title at top, author at bottom)
              if (showTitle || showAuthor)
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title at top
                      if (showTitle)
                        Text(
                          book.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontFamily: PaperfoldTypeTokens.journalFamily,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            height: 1.2,
                          ),
                        ),
                      const Spacer(),
                      // Author at bottom
                      if (showAuthor)
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: authorFontSize,
                            fontWeight: FontWeight.w300,
                            color: textColor,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );

    final RoundedSuperellipseBorder borderShape = RoundedSuperellipseBorder(
      borderRadius: borderRadius,
      side: BorderSide(
        width: 0.3,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );

    return SizedBox(
      height: height,
      width: width,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: ShapeDecoration(
          shape: borderShape,
        ),
        child: ClipRSuperellipse(
          borderRadius: borderRadius,
          child: BookCoverImage(
            path: book.coverPath.isEmpty ? null : book.coverFullPath,
            fallback: fallback,
          ),
        ),
      ),
    );
  }
}

/// Decode a cover at its display width, and keep missing or damaged art usable.
class BookCoverImage extends StatefulWidget {
  const BookCoverImage({super.key, required this.path, required this.fallback});

  final String? path;
  final Widget fallback;

  @override
  State<BookCoverImage> createState() => _BookCoverImageState();
}

class _BookCoverImageState extends State<BookCoverImage> {
  bool _failed = false;
  int _attempt = 0;

  @override
  void didUpdateWidget(covariant BookCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A library refresh can restore a missing cover at the same path.
    // Resolve a failed stream again without checking files during layout.
    if (_failed) {
      _attempt++;
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    if (kIsWeb || path == null || path.isEmpty) return widget.fallback;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.hasBoundedWidth ? constraints.maxWidth : 400.0;
      final pixels = (width * MediaQuery.devicePixelRatioOf(context))
          .ceil()
          .clamp(96, 1200);
      return Image.file(
        File(path),
        key: ValueKey((path, _attempt)),
        fit: BoxFit.cover,
        cacheWidth: pixels,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            frame == null ? widget.fallback : child,
        errorBuilder: (context, error, stackTrace) {
          _failed = true;
          return widget.fallback;
        },
      );
    });
  }
}
