import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/page/opds/book_web_page.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_handler/share_handler.dart';

void receiveShareIntent(WidgetRef ref) {
  final handler = ShareHandlerPlatform.instance;

  // receive sharing intent
  Future<void> handleShare(SharedMedia? media) async {
    AnxLog.info('share: Receive share intent called, ${media?.content}');
    // A link shared from a browser opens in the book browser, where a link
    // to a book file downloads and imports.
    final shared = RegExp(r'https?://\S+').stringMatch(media?.content ?? '');
    final link = shared == null ? null : parseBookLink(shared);
    if (link != null && (media!.attachments?.isEmpty ?? true)) {
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => BookWebPage(url: link)),
      );
      handler.resetInitialSharedMedia();
      return;
    }
    if (media == null ||
        media.attachments == null ||
        media.attachments!.isEmpty) {
      AnxLog.info('share: Receive share intent: no media or empty');
      return;
    }
    AnxLog.info(
        'share: Receive share intent: ${media.attachments!.map((e) => e?.path).join(', ')}');

    List<File> files = [];
    for (var item in media.attachments!) {
      if (item != null && item.path.isNotEmpty) {
        final sourceFile = File(item.path);
        files.add(sourceFile);
      }
    }
    importBookList(files, navigatorKey.currentContext!, ref);
    handler.resetInitialSharedMedia();
  }

  handler.sharedMediaStream.listen((SharedMedia media) {
    handleShare(media);
  }, onError: (err) {
    AnxLog.severe('share: Receive share intent');
  });

  handler.getInitialSharedMedia().then((media) {
    handleShare(media);
  }, onError: (err) {
    AnxLog.severe('share: Receive share intent');
  });
}
