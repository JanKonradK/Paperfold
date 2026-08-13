import 'dart:io';
import 'dart:math';

import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/dao/shelf.dart';
import 'package:paperfold/enums/hint_key.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/page/book_detail.dart';
import 'package:paperfold/providers/sync.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/enums/sync_direction.dart';
import 'package:paperfold/providers/sync_status.dart';
import 'package:paperfold/providers/shelf_home.dart';
import 'package:paperfold/service/convert_to_epub/txt/convert_from_txt.dart';
import 'package:paperfold/page/journal/book_review_page.dart';
import 'package:paperfold/service/md5_service.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/share_file.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:paperfold/widgets/bookshelf/book_cover.dart';
import 'package:paperfold/widgets/delete_confirm.dart';
import 'package:paperfold/widgets/icon_and_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:path/path.dart' as p;

class BookBottomSheet extends ConsumerWidget {
  const BookBottomSheet({
    super.key,
    required this.book,
  });

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> handleDelete(BuildContext context) async {
      Navigator.pop(context);
      await bookDao.deleteBook(book.id);
      ref.read(bookListProvider.notifier).refresh();
      File(book.fileFullPath).delete();
      File(book.coverFullPath).delete();
    }

    void handleDetail(BuildContext context) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BookDetail(book: book),
        ),
      );
    }

    void handleUpload(BuildContext context) {
      Future<void> core() async {
        await ref.read(syncProvider.notifier).releaseBook(book);
        ref.read(syncStatusProvider.notifier).refresh();
      }

      if (Prefs().shouldShowHint(HintKey.releaseLocalSpace)) {
        SmartDialog.show(
          builder: (context) => AlertDialog(
            title: Text(L10n.of(context).bookSyncStatusReleaseSpaceDialogTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(L10n.of(context).bookSyncStatusReleaseSpaceDialogContent),
                Row(
                  children: [
                    StatefulBuilder(builder: (context, setState) {
                      return Checkbox(
                          value: !Prefs()
                              .shouldShowHint(HintKey.releaseLocalSpace),
                          onChanged: (value) {
                            value = !(value ?? false);
                            Prefs()
                                .setShowHint(HintKey.releaseLocalSpace, value);
                            setState(() {});
                          });
                    }),
                    Text(L10n.of(context).bookSyncStatusDoNotShowAgain),
                  ],
                )
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  SmartDialog.dismiss();
                },
                child: Text(L10n.of(context).commonCancel),
              ),
              TextButton(
                onPressed: () {
                  SmartDialog.dismiss();
                  core();
                },
                child: Text(L10n.of(context).commonConfirm),
              ),
            ],
          ),
        );
      } else {
        ref.read(syncProvider.notifier).releaseBook(book);
      }
    }

    Future<void> handleShare() async {
      await shareFile(
        title: '${book.title}.${book.filePath.split('.').last}',
        filePath: book.fileFullPath,
      );
    }

    String formatSize(int bytes) {
      if (bytes <= 0) return '0 B';
      const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
      var i = (log(bytes) / log(1024)).floor();
      return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
    }

    Future<void> handleReplace(BuildContext context) async {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null) return;
      PlatformFile newFile = result.files.first;
      String extension =
          p.extension(newFile.name).replaceAll('.', '').toLowerCase();
      if (!allowBookExtensions.contains(extension)) {
        AnxToast.show(
            L10n.of(context).bookBottomSheetUnsupportedFileFormat(extension));
        return;
      }

      File newFileObj = File(newFile.path!);

      if (!context.mounted) return;

      int newSize = await newFileObj.length();
      int oldSize = 0;
      if (await File(book.fileFullPath).exists()) {
        oldSize = await File(book.fileFullPath).length();
      }

      bool? confirm = await SmartDialog.show(
        builder: (context) => AlertDialog(
          title: Text(L10n.of(context).commonAttention),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(L10n.of(context)
                  .bookBottomSheetOriginalFileSize(formatSize(oldSize))),
              Text(L10n.of(context)
                  .bookBottomSheetNewFileSize(formatSize(newSize))),
              const SizedBox(height: 10),
              Text(
                L10n.of(context).bookBottomSheetReplaceWarning,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                SmartDialog.dismiss(result: false);
              },
              child: Text(L10n.of(context).commonCancel),
            ),
            TextButton(
              onPressed: () {
                SmartDialog.dismiss(result: true);
              },
              child: Text(L10n.of(context).commonConfirm),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      try {
        String extension = p.extension(newFile.name);
        File fileToProcess = newFileObj;

        // Convert TXT to EPUB if needed
        if (extension.toLowerCase() == '.txt') {
          fileToProcess = await convertFromTxt(newFileObj);
          extension = '.epub';
        }

        String title = book.title;
        String nameWithoutExtension =
            '${title.length > 20 ? title.substring(0, 20) : title}-${DateTime.now().millisecondsSinceEpoch}'
                .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
                .replaceAll('\n', '')
                .replaceAll('\r', '')
                .trim();
        String newFileName = '$nameWithoutExtension$extension';
        String newRelativePath = 'file/$newFileName';
        String newDestPath = getBasePath(newRelativePath);

        // Copy new file
        await fileToProcess.copy(newDestPath);

        // Calculate MD5
        String? newMd5 = await MD5Service.calculateFileMd5(newDestPath);

        // Update DB
        await bookDao.updateBook(book.copyWith(
          filePath: newRelativePath,
          md5: newMd5,
          updateTime: DateTime.now(),
        ));

        // Delete old file if path is different
        if (book.fileFullPath != newDestPath) {
          final oldFile = File(book.fileFullPath);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        }

        // Clean up temporary file if TXT conversion happened
        if (fileToProcess != newFileObj) {
          if (await fileToProcess.exists()) {
            await fileToProcess.delete();
          }
        }

        ref.read(bookListProvider.notifier).refresh();
        if (context.mounted) Navigator.pop(context);

        if (Prefs().webdavStatus) {
          ref.read(syncProvider.notifier).syncData(SyncDirection.upload, ref);
        }
      } catch (e) {
        AnxToast.show(
            L10n.of(context).bookBottomSheetReplaceFailed(e.toString()));
      }
    }

    // The journal has to be reachable from the book itself. The Journal
    // destination lists only books that already hold writing, so without this
    // route a book could never get its first review.
    void handleJournal(BuildContext context) {
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => BookReviewPage(book: book),
        ),
      );
    }

    final actions = [
      {
        "icon": EvaIcons.book_open,
        "text": L10n.of(context).navJournal,
        "onTap": () => handleJournal(context)
      },
      {
        "icon": EvaIcons.share,
        "text": L10n.of(context).shareFile,
        "onTap": () => handleShare()
      },
      {
        "icon": EvaIcons.refresh,
        "text": L10n.of(context).bookBottomSheetReplaceFile,
        "onTap": () => handleReplace(context)
      },
      {
        "icon": EvaIcons.cloud_upload,
        "text": L10n.of(context).bookSyncStatusReleaseSpace,
        "onTap": () => handleUpload(context)
      },
      {
        "icon": EvaIcons.more_vertical,
        "text": L10n.of(context).notesPageDetail,
        "onTap": () => handleDetail(context)
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BookCover(book: book, width: 40),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Text(book.title,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          DeleteConfirm(
            delete: () {
              handleDelete(context);
            },
            deleteIcon: IconAndText(
              icon: const Icon(EvaIcons.trash),
              text: L10n.of(context).commonDelete,
            ),
            confirmIcon: IconAndText(
              icon: const Icon(
                EvaIcons.checkmark_circle_2,
                color: Colors.red,
              ),
              text: L10n.of(context).commonConfirm,
            ),
          ),
          _FavouriteButton(bookId: book.id),
          PopupMenuButton(
              itemBuilder: (context) {
                return actions.map((action) {
                  return PopupMenuItem(
                      onTap: () {
                        (action["onTap"] as Function())();
                      },
                      child: Row(
                        children: [
                          Icon(action["icon"] as IconData),
                          const SizedBox(width: 8),
                          Text(action["text"] as String),
                        ],
                      ));
                }).toList();
              },
              child: IconAndText(
                icon: const Icon(EvaIcons.more_vertical),
                text: L10n.of(context).more,
              ))
        ],
      ),
    );
  }
}

class _FavouriteButton extends ConsumerStatefulWidget {
  const _FavouriteButton({required this.bookId});

  final int bookId;

  @override
  ConsumerState<_FavouriteButton> createState() => _FavouriteButtonState();
}

class _FavouriteButtonState extends ConsumerState<_FavouriteButton> {
  bool? _isFavourite;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await shelfDao.containsBook(
      shelfId: builtInFavouritesShelfId,
      bookId: widget.bookId,
    );
    if (mounted) {
      setState(() => _isFavourite = value);
    }
  }

  Future<void> _toggle() async {
    final isFavourite = _isFavourite;
    if (isFavourite == null) {
      return;
    }
    if (isFavourite) {
      await shelfDao.removeBookFromShelf(
        shelfId: builtInFavouritesShelfId,
        bookId: widget.bookId,
      );
    } else {
      await shelfDao.addBookToShelf(
        shelfId: builtInFavouritesShelfId,
        bookId: widget.bookId,
      );
    }
    if (mounted) {
      setState(() => _isFavourite = !isFavourite);
      ref.invalidate(shelfHomeProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final isFavourite = _isFavourite ?? false;
    final label = isFavourite
        ? l10n.removeFromAllTimeFavourites
        : l10n.addToAllTimeFavourites;
    return IconButton(
      tooltip: label,
      onPressed: _isFavourite == null ? null : _toggle,
      icon: Icon(isFavourite ? Icons.favorite : Icons.favorite_border),
    );
  }
}
