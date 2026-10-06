import 'dart:async';
import 'dart:io';

import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/theme.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/enums/sync_direction.dart';
import 'package:paperfold/enums/sync_trigger.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/current_reading_state.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/providers/chapter_content_bridge.dart';
import 'package:paperfold/providers/current_reading.dart';
import 'package:paperfold/providers/sync.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/toc_search.dart';
import 'package:paperfold/service/convert_to_epub/txt/convert_from_txt.dart';
import 'package:paperfold/service/md5_service.dart';
import 'package:paperfold/utils/webView/anx_headless_webview.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/page/reading_page.dart';
import 'package:paperfold/utils/import_book.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:paperfold/utils/webView/gererate_url.dart';
import 'package:paperfold/utils/webView/webview_console_message.dart';
import 'package:paperfold/widgets/bookshelf/book_binding_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import 'book_player/book_player_server.dart';

Future<void> _metadataQueue = Future<void>.value();
final allowBookExtensions = ["epub", "mobi", "azw3", "fb2", "txt", "pdf"];

/// Imports copies of the selected files. The source files remain untouched.
void importBookList(List<File> fileList, BuildContext context, WidgetRef ref) {
  AnxLog.info('importBook fileList: ${fileList.toString()}');

  List<File> supportedFiles = fileList.where((file) {
    return allowBookExtensions
        .contains(file.path.split('.').last.toLowerCase());
  }).toList();

  List<File> unsupportedFiles = fileList.where((file) {
    return !allowBookExtensions
        .contains(file.path.split('.').last.toLowerCase());
  }).toList();

  _checkDuplicatesAndShowDialog(
    supportedFiles,
    unsupportedFiles,
    fileList,
    context,
    ref,
  );
}

void _checkDuplicatesAndShowDialog(
    List<File> supportedFiles,
    List<File> unsupportedFiles,
    List<File> fileList,
    BuildContext context,
    WidgetRef ref) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final progressRoute = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(L10n.of(context).md5Calculating),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(L10n.of(context).md5Calculating),
              ],
            ),
          ));
    },
  );

  navigator.push(progressRoute);
  void closeProgress() {
    if (progressRoute.isActive) navigator.removeRoute(progressRoute);
  }

  try {
    final filePaths = supportedFiles.map((f) => f.path).toList();
    final checkResults = await MD5Service.checkImportFiles(filePaths);

    closeProgress();
    if (!ref.context.mounted) return;

    List<File> duplicateFiles = [];
    List<File> uniqueFiles = [];
    Map<String, Book> duplicateInfo = {};

    for (int i = 0; i < supportedFiles.length; i++) {
      final file = supportedFiles[i];
      final result = checkResults[i];

      if (result.isDuplicate && result.duplicateBook != null) {
        duplicateFiles.add(file);
        duplicateInfo[file.path] = result.duplicateBook!;
      } else {
        uniqueFiles.add(file);
      }
    }

    _showImportDialog(
      uniqueFiles,
      duplicateFiles,
      duplicateInfo,
      unsupportedFiles,
      fileList,
      ref,
    );
  } catch (e) {
    closeProgress();
    AnxLog.severe('MD5 check failed: $e');
    if (!ref.context.mounted) return;
    _showImportDialog(
      supportedFiles,
      [],
      {},
      unsupportedFiles,
      fileList,
      ref,
    );
  }
}

void _showImportDialog(
  List<File> uniqueFiles,
  List<File> duplicateFiles,
  Map<String, Book> duplicateInfo,
  List<File> unsupportedFiles,
  List<File> fileList,
  WidgetRef ref,
) {
  BuildContext context = navigatorKey.currentContext!;

  Widget bookItem(
    String filePath,
    Widget icon, {
    bool isDuplicate = false,
    String? duplicateTitle,
    String? errorMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: icon,
            ),
            Expanded(
              child: Text(
                path.basename(filePath),
                style: TextStyle(
                  fontWeight: FontWeight.w300,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (errorMessage != null)
              IconButton(
                icon: const Icon(Icons.info_outline, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(L10n.of(context).commonError),
                      content: SelectableText(errorMessage),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(L10n.of(context).commonOk),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
        if (isDuplicate && duplicateTitle != null)
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 2),
            child: Text(
              L10n.of(context).duplicateOf(duplicateTitle),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 2),
            child: Text(
              'Error: ${errorMessage.length > 50 ? "${errorMessage.substring(0, 50)}..." : errorMessage}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ),
      ],
    );
  }

  bool skipDuplicates = true;

  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String currentHandlingFile = '';
        List<String> errorFiles = [];
        bool finished = false;
        bool importing = false;
        Map<String, String> errorMessages = {};

        // The books that arrived in this run. They are asked about after the
        // import dialog has gone, not over the top of it: two modal surfaces at
        // once is one surface too many, and the reader has not finished reading
        // the import report yet.
        List<Book> arrived = const [];

        return StatefulBuilder(builder: (context, setState) {
          return PopScope(
            canPop: !importing,
            child: AlertDialog(
              title:
                  Text(L10n.of(context).importNBooksSelected(fileList.length)),
              contentPadding: const EdgeInsets.all(16),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L10n.of(context)
                        .importSupportTypes(allowBookExtensions.join(' / '))),

                    const SizedBox(height: 10),

                    // show unique files
                    for (var file in uniqueFiles)
                      file.path == currentHandlingFile
                          ? bookItem(
                              file.path,
                              Container(
                                padding: const EdgeInsets.all(3),
                                width: 20,
                                height: 20,
                                child: const CircularProgressIndicator(),
                              ))
                          : bookItem(
                              file.path,
                              errorFiles.contains(file.path)
                                  ? const Icon(Icons.error)
                                  : const Icon(Icons.done),
                              errorMessage: errorFiles.contains(file.path)
                                  ? errorMessages[file.path]
                                  : null,
                            ),

                    // show unsupported files
                    if (unsupportedFiles.isNotEmpty) ...[
                      Divider(),
                      SizedBox(height: 10),
                      Text(L10n.of(context)
                          .importNBooksNotSupport(unsupportedFiles.length))
                    ],
                    for (var file in unsupportedFiles)
                      bookItem(file.path, const Icon(Icons.error)),

                    // show duplicate files
                    if (duplicateFiles.isNotEmpty) ...[
                      Divider(),
                      const SizedBox(height: 10),
                      Text(L10n.of(context).duplicateFile),
                    ],
                    for (var file in duplicateFiles)
                      if (skipDuplicates)
                        bookItem(
                          file.path,
                          const Icon(Icons.double_arrow_rounded),
                          isDuplicate: true,
                          duplicateTitle: duplicateInfo[file.path]?.title,
                        )
                      else
                        file.path == currentHandlingFile
                            ? bookItem(
                                file.path,
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  width: 20,
                                  height: 20,
                                  child: const CircularProgressIndicator(),
                                ),
                                isDuplicate: true,
                                duplicateTitle: duplicateInfo[file.path]?.title,
                              )
                            : bookItem(
                                file.path,
                                errorFiles.contains(file.path)
                                    ? const Icon(Icons.error)
                                    : const Icon(Icons.done),
                                isDuplicate: true,
                                duplicateTitle: duplicateInfo[file.path]?.title,
                                errorMessage: errorFiles.contains(file.path)
                                    ? errorMessages[file.path]
                                    : null,
                              ),

                    // select skip duplicates
                    if (duplicateFiles.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Checkbox(
                            value: skipDuplicates,
                            onChanged: importing || finished
                                ? null
                                : (value) {
                                    setState(() {
                                      skipDuplicates = value ?? true;
                                    });
                                  },
                          ),
                          Expanded(
                            child: Text(L10n.of(context).skipDuplicateFiles),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: importing
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: Text(L10n.of(context).commonCancel),
                ),
                if (uniqueFiles.isNotEmpty ||
                    (duplicateFiles.isNotEmpty && !skipDuplicates))
                  TextButton(
                      onPressed: importing
                          ? null
                          : () async {
                              if (finished) {
                                Navigator.of(context).pop('dialog');
                                if (arrived.isEmpty) return;
                                final host = navigatorKey.currentContext;
                                if (host == null || !host.mounted) return;
                                // How a book is bound decides the shape of the object
                                // that stands on the shelf, and the metadata is often
                                // silent about it. Asked once per book, here, while the
                                // reader still has the book in mind.
                                await askBookBindings(host, arrived);
                                ref.read(bookListProvider.notifier).refresh();
                                return;
                              }

                              setState(() => importing = true);
                              try {
                                List<File> filesToImport = [...uniqueFiles];
                                if (!skipDuplicates) {
                                  filesToImport.addAll(duplicateFiles);
                                }

                                // Which books the library already had, so the ones that
                                // arrive can be told apart afterwards and asked about.
                                // Nothing in the import chain hands the new row back.
                                final before = {
                                  for (final book
                                      in await bookDao.selectAllBooks())
                                    book.id,
                                };

                                for (var file in filesToImport) {
                                  AnxToast.show(path.basename(file.path));
                                  setState(() {
                                    currentHandlingFile = file.path;
                                  });
                                  try {
                                    await importBook(file, ref);
                                    setState(() {
                                      currentHandlingFile = '';
                                    });
                                  } catch (e, stackTrace) {
                                    AnxLog.severe(
                                        'Failed to import ${file.path}: $e');
                                    AnxLog.severe('Stack trace: $stackTrace');
                                    setState(() {
                                      errorFiles.add(file.path);
                                      errorMessages[file.path] = e.toString();
                                    });
                                  }
                                }

                                ref.read(syncProvider.notifier).syncData(
                                    SyncDirection.upload, ref,
                                    trigger: SyncTrigger.auto);

                                arrived = [
                                  for (final book
                                      in await bookDao.selectAllBooks())
                                    if (!before.contains(book.id) &&
                                        !book.isDeleted)
                                      book,
                                ];
                              } catch (error, stackTrace) {
                                AnxLog.severe(
                                    'Import failed', error, stackTrace);
                                if (context.mounted) {
                                  AnxToast.show(error.toString());
                                }
                              } finally {
                                if (context.mounted) {
                                  setState(() {
                                    importing = false;
                                    currentHandlingFile = '';
                                    finished = true;
                                  });
                                }
                              }
                            },
                      child: Text(finished
                          ? L10n.of(context).commonOk
                          : L10n.of(context).importImportNBooks(
                              uniqueFiles.length +
                                  (skipDuplicates ? 0 : duplicateFiles.length) -
                                  errorFiles.length))),
              ],
            ),
          );
        });
      });
}

Future<void> importBook(File file, WidgetRef ref) async {
  String? md5 = await MD5Service.calculateFileMd5(file.path);

  if (path.extension(file.path).toLowerCase() == '.txt') {
    final tempFile = await convertFromTxt(file);
    try {
      await getBookMetadata(tempFile, md5: md5);
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  } else {
    await getBookMetadata(file, md5: md5);
  }
  if (ref.context.mounted) ref.read(bookListProvider.notifier).refresh();
}

Future<void> pushToReadingPage(
  WidgetRef ref,
  BuildContext context,
  Book book, {
  String? cfi,
  String? heroTag,
}) async {
  if (book.isDeleted) {
    AnxToast.show(L10n.of(context).bookDeleted);
    return;
  }

  if (!File(book.fileFullPath).existsSync()) {
    ref.read(syncProvider.notifier).downloadBook(book);
    return;
  }

  final initialThemes = await themeDao.selectThemes();
  ref.read(currentReadingProvider.notifier).start(
        CurrentReadingState(
          book: book,
          cfi: cfi,
        ),
      );

  final currentReading = ref.read(currentReadingProvider.notifier);
  final chapterContentBridge = ref.read(chapterContentBridgeProvider.notifier);
  final tocSearch = ref.read(tocSearchProvider.notifier);

  await Navigator.push(
    navigatorKey.currentContext!,
    // A fade, not a slide. The shelf has already raised the page the book
    // opened onto and this route draws the same page underneath, so there is
    // nothing for a slide to reveal: it only added a third distinct screen
    // between the tap and the first line of text. Faded, the handover from one
    // route to the other cannot be seen at all.
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => ReadingPage(
        key: readingPageKey,
        book: book,
        cfi: cfi,
        initialThemes: initialThemes,
        heroTag: heroTag,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  ).then((_) {
    AnxLog.info('ReadingPage: poped: ${book.title}');
    currentReading.finish();
    chapterContentBridge.state = null;
    tocSearch.clear();
    // The reader no longer rebuilds the library on every page turn, so the
    // shelves pick up the new position here instead, once.
    ref.read(bookListProvider.notifier).refresh();
    AnxLog.info('Pop successfully ReadingPage: ${book.title}');
  });
}

void updateBookRating(Book book, double rating) {
  book.rating = rating;
  bookDao.updateBook(book);
}

Future<void> resetBookCover(Book book) async {
  File file = File(book.fileFullPath);
  await getBookMetadata(file, book: book, md5: book.md5);
}

Future<void> saveBook(
  File file,
  String title,
  String author,
  String description,
  String? md5,
  String cover, {
  Book? provideBook,
  BookDao? dao,
}) async {
  dao ??= bookDao;
  if (md5 != null) {
    provideBook ??= await dao.getBookByMd5(md5);
  }
  // Extract original filename (without extension)
  final fileNameWithoutExt = path.basenameWithoutExtension(file.path);

  // Use original filename if title is invalid
  final effectiveTitle =
      (title == 'Unknown' || title.trim().isEmpty) ? fileNameWithoutExt : title;

  final newBookName =
      '${effectiveTitle.length > 20 ? effectiveTitle.substring(0, 20) : effectiveTitle}-${DateTime.now().microsecondsSinceEpoch}'
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
          .replaceAll('\n', '')
          .replaceAll('\r', '')
          .trim();

  final extension = path.extension(file.path).toLowerCase();

  final alreadyStored = provideBook != null &&
      path.equals(
          path.absolute(file.path), path.absolute(provideBook.fileFullPath));
  final dbFilePath =
      alreadyStored ? provideBook.filePath : 'file/$newBookName$extension';
  final filePath = getBasePath(dbFilePath);
  String dbCoverPath = 'cover/$newBookName';

  if (!alreadyStored) await file.copy(filePath);

  dbCoverPath = await saveImageToLocal(cover, dbCoverPath);

  Book book = Book(
      id: provideBook != null ? provideBook.id : -1,
      title: provideBook?.title ?? effectiveTitle,
      coverPath:
          dbCoverPath.isEmpty ? provideBook?.coverPath ?? '' : dbCoverPath,
      filePath: dbFilePath,
      lastReadPosition: provideBook?.lastReadPosition ?? '',
      readingPercentage: provideBook?.readingPercentage ?? 0,
      author: provideBook?.author ?? author,
      description: provideBook?.description ?? description,
      groupId: provideBook?.groupId ?? 0,
      isDeleted: false,
      rating: provideBook?.rating ?? 0.0,
      md5: md5 ?? provideBook?.md5,
      status: provideBook?.status ?? BookStatus.notStarted,
      startedOn: provideBook?.startedOn,
      finishedOn: provideBook?.finishedOn,
      createTime: provideBook?.createTime ?? DateTime.now(),
      updateTime: DateTime.now());

  book.id = await dao.insertBook(book);
}

Future<void> getBookMetadata(
  File file, {
  Book? book,
  String? md5,
}) {
  // ponytail: one import WebView at a time; use per-import server routes if
  // parallel metadata extraction is needed.
  final operation = _metadataQueue.then(
    (_) => _getBookMetadata(file, book: book, md5: md5),
  );
  _metadataQueue = operation.catchError((Object _) {});
  return operation;
}

Future<void> _getBookMetadata(File file, {Book? book, String? md5}) async {
  String serverFileName = Server().setTempFile(file);
  final result = Completer<Map<String, dynamic>>();
  String bookUrl = "http://127.0.0.1:${Server().port}/$serverFileName";
  AnxLog.info("import start: book url: $bookUrl");

  AnxHeadlessWebView webview = AnxHeadlessWebView(
    webViewEnvironment: webViewEnvironment,
    initialUrlRequest: URLRequest(
        url: WebUri(generateUrl(
      bookUrl,
      '',
      importing: true,
    ))),
    onWebViewCreated: (controller) {
      controller.addJavaScriptHandler(
          handlerName: 'onMetadata',
          callback: (args) {
            if (result.isCompleted) return;
            try {
              result.complete(Map<String, dynamic>.from(args.single as Map));
            } catch (error, stackTrace) {
              result.completeError(error, stackTrace);
            }
          });
    },
    onConsoleMessage: (controller, consoleMessage) {
      if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR &&
          !result.isCompleted) {
        result.completeError(Exception('Webview: ${consoleMessage.message}'));
      }
      webviewConsoleMessage(controller, consoleMessage);
    },
    onLoadError: (controller, url, code, message) {
      if (!result.isCompleted) result.completeError(Exception(message));
    },
    onLoadHttpError: (controller, url, statusCode, description) {
      if (!result.isCompleted) {
        result.completeError(Exception('HTTP $statusCode: $description'));
      }
    },
  );

  try {
    unawaited(webview.run().catchError((Object error, StackTrace stackTrace) {
      if (!result.isCompleted) result.completeError(error, stackTrace);
    }));
    final metadata = await result.future.timeout(const Duration(seconds: 30));
    final authorData = metadata['author'];
    final author = authorData is List
        ? authorData
            .map((value) => value is Map ? value['name'] : value)
            .whereType<String>()
            .join(', ')
        : authorData is String
            ? authorData
            : 'Unknown';
    await saveBook(
      file,
      metadata['title'] as String? ?? 'Unknown',
      author,
      metadata['description'] as String? ?? '',
      md5,
      metadata['cover'] as String? ?? '',
      provideBook: book,
    );
  } finally {
    if (!result.isCompleted) result.complete(<String, dynamic>{});
    await webview.dispose();
    Server().clearTempFile();
  }
}
