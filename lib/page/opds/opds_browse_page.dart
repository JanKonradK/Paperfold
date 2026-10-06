import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/opds_catalog.dart';
import 'package:paperfold/providers/opds.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/service/opds/opds.dart';
import 'package:paperfold/service/opds/opds_client.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:paperfold/widgets/ornament.dart';

/// One feed of one catalog.
///
/// A feed holds shelves, books, or both. Following a shelf pushes another one
/// of these, so Back walks the catalog the way Back walks anything else.
class OpdsBrowsePage extends ConsumerWidget {
  const OpdsBrowsePage(
      {super.key, required this.catalog, this.url, this.title});

  final OpdsCatalog catalog;

  /// Null means the catalog's own address.
  final Uri? url;

  /// The row the reader followed to get here, which is a better title than the
  /// feed's own until the feed arrives.
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = L10n.of(context);
    final OpdsFeedRequest request = OpdsFeedRequest(catalog, url);
    final AsyncValue<OpdsFeed> feed = ref.watch(opdsFeedProvider(request));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          feed.valueOrNull?.title.isNotEmpty ?? false
              ? feed.requireValue.title
              : (title ?? catalog.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => _FeedError(
          message: _messageFor(l10n, error),
          onRetry: () => ref.invalidate(opdsFeedProvider(request)),
        ),
        data: (OpdsFeed data) {
          if (data.isEmpty) {
            return _FeedError(
              message: l10n.opdsFeedEmpty,
              onRetry: () => ref.invalidate(opdsFeedProvider(request)),
            );
          }
          return _FeedList(catalog: catalog, feed: data);
        },
      ),
    );
  }

  /// The failure the reader can act on, in words.
  ///
  /// A wrong password is theirs to fix. A server that is down is not. An
  /// address that answers with a web page usually points at the site rather
  /// than at its catalog, and only the message can say so.
  static String _messageFor(L10n l10n, Object error) {
    if (error is! OpdsException) {
      return l10n.opdsErrorNetwork;
    }
    return switch (error.failure) {
      OpdsFailure.network => l10n.opdsErrorNetwork,
      OpdsFailure.unauthorized => l10n.opdsErrorUnauthorized,
      OpdsFailure.notFound => l10n.opdsErrorNotFound,
      OpdsFailure.server => l10n.opdsErrorServer,
      OpdsFailure.notAFeed => l10n.opdsErrorNotAFeed,
    };
  }
}

class _FeedList extends ConsumerWidget {
  const _FeedList({required this.catalog, required this.feed});

  final OpdsCatalog catalog;
  final OpdsFeed feed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final L10n l10n = L10n.of(context);

    return ListView(
      padding: EdgeInsets.only(
        bottom: 96 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: <Widget>[
        for (final OpdsLink shelf in feed.navigation)
          ListTile(
            minTileHeight: 56,
            leading: const Icon(Icons.folder_outlined),
            title: Text(shelf.title ?? shelf.href.toString()),
            subtitle: shelf.numberOfItems == null
                ? null
                : Text('${shelf.numberOfItems}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => OpdsBrowsePage(
                  catalog: catalog,
                  url: shelf.href,
                  title: shelf.title,
                ),
              ),
            ),
          ),
        for (final OpdsEntry entry in feed.publications)
          _PublicationTile(catalog: catalog, entry: entry),
        if (feed.nextHref case final Uri next?)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              // A page, not an infinite scroll. A catalog can be very large,
              // and the reader decides how much of it to pull.
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => OpdsBrowsePage(
                    catalog: catalog,
                    url: next,
                    title: feed.title,
                  ),
                ),
              ),
              child: Text(l10n.opdsNextPage),
            ),
          ),
      ],
    );
  }
}

class _PublicationTile extends ConsumerStatefulWidget {
  const _PublicationTile({required this.catalog, required this.entry});

  final OpdsCatalog catalog;
  final OpdsEntry entry;

  @override
  ConsumerState<_PublicationTile> createState() => _PublicationTileState();
}

class _PublicationTileState extends ConsumerState<_PublicationTile> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final L10n l10n = L10n.of(context);
    final List<OpdsLink> downloads = widget.entry.acquisitionLinks;

    return ListTile(
      minTileHeight: 56,
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(
        widget.entry.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: widget.entry.authors.isEmpty
          ? null
          : Text(
              widget.entry.authors.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: _downloading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: l10n.opdsDownload,
              onPressed:
                  downloads.isEmpty ? null : () => _download(downloads.first),
            ),
    );
  }

  Future<void> _download(OpdsLink link) async {
    final L10n l10n = L10n.of(context);
    setState(() => _downloading = true);
    Directory? downloadDir;

    try {
      final Directory temp = await getAnxTempDir();
      downloadDir = await temp.createTemp('opds-');
      final String path = '${downloadDir.path}/${_fileNameFor(link)}';
      if (!mounted) return;
      await ref.read(opdsClientProvider).download(
            widget.catalog,
            link.href,
            path,
          );
      // The import path already knows how to read a book file. Section 9.2
      // says to point it at the download, not to write a second one.
      if (!mounted) return;
      await importBook(File(path), ref);
      if (mounted) {
        AnxToast.show(l10n.opdsDownloaded(widget.entry.title));
      }
    } on OpdsException catch (error) {
      if (mounted) {
        AnxToast.show(OpdsBrowsePage._messageFor(l10n, error));
      }
    } catch (error, stackTrace) {
      AnxLog.severe('OPDS import failed', error, stackTrace);
      if (mounted) AnxToast.show('${l10n.commonError}: $error');
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
      if (downloadDir != null) {
        try {
          await downloadDir.delete(recursive: true);
        } on FileSystemException catch (error) {
          AnxLog.warning('Could not remove OPDS download: $error');
        }
      }
    }
  }

  /// A file name the import path can read.
  ///
  /// The last path segment is usually right, but a catalog may serve a book
  /// from a query string with no name in it at all.
  String _fileNameFor(OpdsLink link) {
    final String segment =
        link.href.pathSegments.isEmpty ? '' : link.href.pathSegments.last;
    final safeSegment =
        segment.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
    if (safeSegment.length <= 120 &&
        allowBookExtensions
            .contains(safeSegment.split('.').last.toLowerCase())) {
      return 'book-$safeSegment';
    }
    final String extension = switch (link.type) {
      'application/epub+zip' => 'epub',
      'application/pdf' => 'pdf',
      'application/x-mobipocket-ebook' => 'mobi',
      'application/vnd.amazon.ebook' => 'azw3',
      _ => 'epub',
    };
    final String safe =
        widget.entry.title.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    return 'book-${safe.runes.take(80).map(String.fromCharCode).join()}.$extension';
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Ornament(
                ornament: PaperfoldOrnament.circularWreath,
                width: 104,
                height: 104,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(L10n.of(context).commonOk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
