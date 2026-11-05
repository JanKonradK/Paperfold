import 'dart:io';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/opds_catalog.dart';
import 'package:paperfold/page/opds/open_book_website.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/opds.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/service/opds/opds.dart';
import 'package:paperfold/service/opds/opds_client.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/widgets/common/message_block.dart';

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
          feed.value?.title.isNotEmpty ?? false
              ? feed.requireValue.title
              : (title ?? catalog.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: feed.when(
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
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
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

class _PublicationTileState extends ConsumerState<_PublicationTile>
    with AutomaticKeepAliveClientMixin<_PublicationTile> {
  bool _downloading = false;
  CancelToken? _cancelToken;

  @override
  bool get wantKeepAlive => _downloading;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final L10n l10n = L10n.of(context);
    final List<OpdsLink> downloads = widget.entry.downloadLinks;
    final website = widget.entry.websiteHref;

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
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: _cancelToken == null
                        ? l10n.importing
                        : l10n.opdsDownload,
                  ),
                ),
                if (_cancelToken != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.commonCancel,
                    onPressed: () => _cancelToken?.cancel(),
                  ),
              ],
            )
          : downloads.isEmpty && website != null
              ? IconButton(
                  icon: const Icon(Icons.open_in_new),
                  tooltip: l10n.onlineOpenWebsite,
                  onPressed: () => openBookWebsite(context, website),
                )
              : IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: downloads.isEmpty
                      ? l10n.opdsUnsupportedDownload
                      : l10n.opdsDownload,
                  onPressed:
                      downloads.isEmpty ? null : () => _chooseFormat(downloads),
                ),
    );
  }

  Future<void> _chooseFormat(List<OpdsLink> downloads) async {
    if (_downloading) return;
    final selected = downloads.length == 1
        ? downloads.single
        : await showModalBottomSheet<OpdsLink>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (context) => ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.8,
                maxWidth: 640,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                children: [
                  Text(L10n.of(context).opdsChooseFormat,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(widget.entry.title),
                  const SizedBox(height: 16),
                  for (final link in downloads)
                    ListTile(
                      title: Text(link.downloadExtension!.toUpperCase()),
                      subtitle: link.title == null ? null : Text(link.title!),
                      trailing: const Icon(Icons.download_outlined),
                      onTap: () => Navigator.of(context).pop(link),
                    ),
                ],
              ),
            ),
          );
    if (selected != null && mounted) await _download(selected);
  }

  Future<void> _download(OpdsLink link) async {
    if (_downloading || !link.isDirectDownload) return;
    final L10n l10n = L10n.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final client = ref.read(opdsClientProvider);
    final cancelToken = CancelToken();
    setState(() {
      _downloading = true;
      _cancelToken = cancelToken;
    });
    updateKeepAlive();
    Directory? downloadDir;

    try {
      final Directory temp = await getAnxTempDir();
      downloadDir = await temp.createTemp('opds-');
      final String path = '${downloadDir.path}/book.${link.downloadExtension!}';
      if (!mounted || cancelToken.isCancelled) return;
      await client.download(
        widget.catalog,
        link.href,
        path,
        cancelToken: cancelToken,
      );
      if (!mounted || cancelToken.isCancelled) return;
      // Metadata import cannot be interrupted safely. Its completion must
      // refresh the library even when the reader has left this catalog.
      setState(() => _cancelToken = null);
      await importBook(File(path), ref);
      if (!mounted && rootNavigator.mounted)
        container.invalidate(bookListProvider);
      _showMessage(l10n.opdsDownloaded(widget.entry.title));
    } on DioException catch (error) {
      if (!CancelToken.isCancel(error)) {
        _showMessage(l10n.opdsImportFailed);
      }
    } on OpdsException catch (error) {
      _showMessage(OpdsBrowsePage._messageFor(l10n, error));
    } catch (_) {
      AnxLog.warning('OPDS import failed');
      _showMessage(l10n.opdsImportFailed);
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
          _cancelToken = null;
        });
        updateKeepAlive();
      }
      if (downloadDir != null) {
        try {
          await downloadDir.delete(recursive: true);
        } on FileSystemException {
          AnxLog.warning('Could not remove OPDS download');
        }
      }
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return MessageBlock(
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.menu_book_outlined, size: 40),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(L10n.of(context).commonRetry),
          ),
        ],
      ),
    );
  }
}
