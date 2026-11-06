import 'package:paperfold/widgets/common/paperfold_modal_motion.dart';

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/opds/open_book_website.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/service/opds/opds.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

/// A book website inside Paperfold. A book file downloaded here goes through
/// the normal import, so it lands in the library instead of the Downloads
/// folder, where the reader had to find it again and import it by hand.
class BookWebPage extends ConsumerStatefulWidget {
  const BookWebPage({super.key, required this.url});

  final Uri url;

  @override
  ConsumerState<BookWebPage> createState() => _BookWebPageState();
}

class _BookWebPageState extends ConsumerState<BookWebPage> {
  InAppWebViewController? _controller;
  String _title = '';
  Uri? _current;
  bool _downloading = false;
  double? _progress;

  Future<void> _download(DownloadStartRequest request) async {
    final l10n = L10n.of(context);
    final extension = bookExtension(
      request.url,
      mimeType: request.mimeType,
      fileName: request.suggestedFilename,
    );
    if (extension == null) {
      _showMessage(l10n.bookWebNotABook);
      return;
    }
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _progress = null;
    });
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: request.url,
      );
      final base = path.basename(
        request.suggestedFilename ?? request.url.pathSegments.lastOrNull ?? '',
      );
      // Only the book extension goes: "1706.03762" and "Dr. Seuss" keep
      // the part after their dot.
      final name =
          (path.extension(base).toLowerCase() == '.$extension'
                  ? path.withoutExtension(base)
                  : base)
              .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
              .trim();
      final dir = await (await getAnxTempDir()).createTemp('web-');
      final file = File(
        path.join(
          dir.path,
          // The name becomes the title when the file carries none.
          '${name.isEmpty ? 'book' : name}.$extension',
        ),
      );
      await Dio().download(
        request.url.toString(),
        file.path,
        options: Options(
          headers: {
            if (request.userAgent != null) 'User-Agent': request.userAgent,
            if (_current != null) 'Referer': _current.toString(),
            if (cookies.isNotEmpty)
              'Cookie': cookies.map((c) => '${c.name}=${c.value}').join('; '),
          },
        ),
        onReceiveProgress: (received, total) {
          if (mounted && total > 0) {
            setState(() => _progress = received / total);
          }
        },
      );
      if (!mounted) return;
      importBookList([file], context, ref);
    } catch (e) {
      AnxLog.warning('Web book download failed: $e');
      _showMessage(l10n.opdsImportFailed);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return PopScope(
      canPop: false,
      // Back walks the site's history first, the way a browser does.
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final controller = _controller;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
        } else if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _title.isEmpty ? widget.url.host : _title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.open_in_new),
              tooltip: l10n.onlineOpenWebsite,
              onPressed: () => openBookWebsite(context, _current ?? widget.url),
            ),
          ],
          bottom: _downloading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(4),
                  child: LinearProgressIndicator(value: _progress),
                )
              : null,
        ),
        body: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri.uri(widget.url)),
          initialSettings: InAppWebViewSettings(
            isInspectable: kDebugMode,
            useOnDownloadStart: true,
            useShouldOverrideUrlLoading: true,
          ),
          onWebViewCreated: (controller) => _controller = controller,
          onTitleChanged: (_, title) => setState(() => _title = title ?? ''),
          onUpdateVisitedHistory: (_, url, _) => _current = url,
          onDownloadStarting: (_, request) {
            _download(request);
            return DownloadStartResponse(
              handled: true,
              action: DownloadStartResponseAction.CANCEL,
            );
          },
          // Store and app links leave for the app that owns them.
          shouldOverrideUrlLoading: (_, action) async {
            final uri = action.request.url;
            if (uri == null ||
                const {
                  'http',
                  'https',
                  'about',
                  'data',
                  'blob',
                  'javascript',
                }.contains(uri.scheme)) {
              return NavigationActionPolicy.ALLOW;
            }
            launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            ).catchError((_) => false);
            return NavigationActionPolicy.CANCEL;
          },
        ),
      ),
    );
  }
}

/// The book format of a download, or null when Paperfold cannot open it.
@visibleForTesting
String? bookExtension(Uri url, {String? mimeType, String? fileName}) {
  final fromType = OpdsLink(
    rels: const [],
    href: url,
    type: mimeType,
  ).downloadExtension;
  if (fromType != null) return fromType;
  final suffix = path.extension(fileName ?? '').replaceFirst('.', '');
  return allowBookExtensions.contains(suffix.toLowerCase())
      ? suffix.toLowerCase()
      : null;
}

/// A web address typed or pasted by the reader, with `https://` assumed.
Uri? parseBookLink(String text) {
  final trimmed = text.trim();
  final uri = Uri.tryParse(
    trimmed.contains('://') ? trimmed : 'https://$trimmed',
  );
  return uri != null && isOpdsWebUri(uri) ? uri : null;
}

/// Asks for a link, then opens it. A link straight to a book file downloads
/// and imports at once; any other page can be browsed to its download.
Future<void> openBookLink(BuildContext context) async {
  final url = await showDialog<Uri>(
    context: context,
    animationStyle: paperfoldModalMotion(context),
    builder: (context) => const _BookLinkDialog(),
  );
  if (url == null || !context.mounted) return;
  await Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (context) => BookWebPage(url: url)));
}

class _BookLinkDialog extends StatefulWidget {
  const _BookLinkDialog();

  @override
  State<_BookLinkDialog> createState() => _BookLinkDialogState();
}

class _BookLinkDialogState extends State<_BookLinkDialog> {
  final _controller = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final url = parseBookLink(_controller.text);
    if (url == null) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.addFromLinkTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.url,
        autocorrect: false,
        textInputAction: TextInputAction.go,
        decoration: InputDecoration(
          labelText: l10n.addFromLinkField,
          hintText: 'https://',
          errorText: _invalid ? l10n.addFromLinkInvalid : null,
          errorMaxLines: 3,
        ),
        onChanged: (_) {
          if (_invalid) setState(() => _invalid = false);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.readingPageOpenExternalLinkAction),
        ),
      ],
    );
  }
}
