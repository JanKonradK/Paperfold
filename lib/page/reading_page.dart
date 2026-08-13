import 'dart:async';
import 'dart:math' as math;

import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/reading_time.dart';
import 'package:paperfold/dao/theme.dart';
import 'package:paperfold/enums/sync_direction.dart';
import 'package:paperfold/enums/sync_trigger.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/read_theme.dart';
import 'package:paperfold/page/book_detail.dart';
import 'package:paperfold/page/book_player/epub_player.dart';
import 'package:paperfold/providers/sync.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:paperfold/utils/ui/status_bar.dart';
import 'package:paperfold/widgets/reading_page/notes_widget.dart';
import 'package:paperfold/widgets/reading_page/reader_chrome.dart';
import 'package:paperfold/models/reading_time.dart';
import 'package:paperfold/widgets/reading_page/progress_widget.dart';
import 'package:paperfold/widgets/reading_page/style_widget.dart';
import 'package:paperfold/widgets/reading_page/toc_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter/foundation.dart'
// show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ReadingPage extends ConsumerStatefulWidget {
  const ReadingPage({
    super.key,
    required this.book,
    this.cfi,
    required this.initialThemes,
    this.heroTag,
  });

  final Book book;
  final String? cfi;
  final List<ReadTheme> initialThemes;
  final String? heroTag;

  @override
  ConsumerState<ReadingPage> createState() => ReadingPageState();
}

final GlobalKey<ReadingPageState> readingPageKey =
    GlobalKey<ReadingPageState>();
final epubPlayerKey = GlobalKey<EpubPlayerState>();

class ReadingPageState extends ConsumerState<ReadingPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const empty = SizedBox.shrink();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late Book _book;
  late Widget _currentPage = empty;
  final Stopwatch _readTimeWatch = Stopwatch();
  DateTime? _sessionStart;
  Timer? _awakeTimer;
  bool bottomBarOffstage = true;
  ReaderTool _activeTool = ReaderTool.none;
  late String heroTag;
  bool bookmarkExists = false;

  late final FocusNode _readerFocusNode;
  // late final VolumeKeyBoard _volumeKeyBoard;
  // bool _volumeKeyListenerAttached = false;

  @override
  void initState() {
    _readerFocusNode = FocusNode(debugLabel: 'reading_page_focus');

    if (widget.book.isDeleted) {
      Navigator.pop(context);
      AnxToast.show(L10n.of(context).bookDeleted);
      return;
    }
    if (Prefs().hideStatusBar) {
      hideStatusBar();
    }

    WidgetsBinding.instance.addObserver(this);
    _readTimeWatch.start();
    _sessionStart = DateTime.now();
    setAwakeTimer(Prefs().awakeTime);

    _book = widget.book;
    heroTag = widget.heroTag ?? 'preventHeroWhenStart';
    // _volumeKeyBoard = VolumeKeyBoard.instance;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestReaderFocus();
        // _attachVolumeKeyListener();
      }
    });
    // delay 1000ms to prevent hero animation
    if (widget.heroTag == null) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          setState(() {
            heroTag = _book.coverFullPath;
          });
        }
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    Sync().syncData(SyncDirection.upload, ref, trigger: SyncTrigger.auto);
    _readTimeWatch.stop();
    _awakeTimer?.cancel();
    WakelockPlus.disable();
    showStatusBar();
    WidgetsBinding.instance.removeObserver(this);
    readingTimeDao.insertReadingTime(
      ReadingTime(
        bookId: _book.id,
        readingTime: _readTimeWatch.elapsed.inSeconds,
      ),
      startedAt: _sessionStart,
    );
    _sessionStart = null;
    // if (_volumeKeyListenerAttached) {
    //   unawaited(_volumeKeyBoard.removeListener());
    // }
    _readerFocusNode.dispose();
    super.dispose();
  }

  void _requestReaderFocus() {
    if (bottomBarOffstage && !_readerFocusNode.hasFocus) {
      _readerFocusNode.requestFocus();
    }
  }

  void _releaseReaderFocus() {
    if (_readerFocusNode.hasFocus) {
      _readerFocusNode.unfocus();
    }
  }

  // Future<void> _attachVolumeKeyListener() async {
  //   if (defaultTargetPlatform != TargetPlatform.iOS ||
  //       _volumeKeyListenerAttached) {
  //     return;
  //   }

  //   try {
  //     await _volumeKeyBoard.addListener(_handleVolumeKeyEvent);
  //     _volumeKeyListenerAttached = true;
  //   } catch (error) {
  //     debugPrint('Failed to attach volume key listener: $error');
  //   }
  // }

  // void _handleVolumeKeyEvent(VolumeKey key) {
  //   if (!Prefs().volumeKeyTurnPage || !_readerFocusNode.hasFocus) {
  //     return;
  //   }

  //   if (key == VolumeKey.up) {
  //     epubPlayerKey.currentState?.prevPage();
  //   } else if (key == VolumeKey.down) {
  //     epubPlayerKey.currentState?.nextPage();
  //   }
  // }

  KeyEventResult _handleReaderKeyEvent(FocusNode node, KeyEvent event) {
    if (!_readerFocusNode.hasFocus) {
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final logicalKey = event.logicalKey;

    if (logicalKey == LogicalKeyboardKey.arrowRight ||
        logicalKey == LogicalKeyboardKey.arrowDown ||
        logicalKey == LogicalKeyboardKey.pageDown ||
        logicalKey == LogicalKeyboardKey.space) {
      epubPlayerKey.currentState?.nextPage();
      return KeyEventResult.handled;
    }

    if (logicalKey == LogicalKeyboardKey.arrowLeft ||
        logicalKey == LogicalKeyboardKey.arrowUp ||
        logicalKey == LogicalKeyboardKey.pageUp) {
      epubPlayerKey.currentState?.prevPage();
      return KeyEventResult.handled;
    }

    if (logicalKey == LogicalKeyboardKey.enter) {
      showOrHideAppBarAndBottomBar(true);
      return KeyEventResult.handled;
    }

    // Handle Ctrl+[ and Ctrl+] for page turning when keyboard shortcut is enabled
    if (Prefs().keyboardShortcutTurnPage) {
      final isControlPressed = HardwareKeyboard.instance.isControlPressed;
      if (isControlPressed && logicalKey == LogicalKeyboardKey.bracketLeft) {
        epubPlayerKey.currentState?.prevPage();
        return KeyEventResult.handled;
      }
      if (isControlPressed && logicalKey == LogicalKeyboardKey.bracketRight) {
        epubPlayerKey.currentState?.nextPage();
        return KeyEventResult.handled;
      }
      final bool isSimulatedCtrlLeft = event.character == '\u001b';
      final bool isSimulatedCtrlRight = event.character == '\u001d';
      if (isSimulatedCtrlLeft) {
        epubPlayerKey.currentState?.prevPage();
        return KeyEventResult.handled;
      }
      if (isSimulatedCtrlRight) {
        epubPlayerKey.currentState?.nextPage();
        return KeyEventResult.handled;
      }
    }

    if (Prefs().volumeKeyTurnPage) {
      if (event.physicalKey == PhysicalKeyboardKey.audioVolumeUp) {
        epubPlayerKey.currentState?.prevPage();
        return KeyEventResult.handled;
      }
      if (event.physicalKey == PhysicalKeyboardKey.audioVolumeDown) {
        epubPlayerKey.currentState?.nextPage();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_readTimeWatch.isRunning) {
          _readTimeWatch.start();
        }
        _sessionStart ??= DateTime.now();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_readTimeWatch.isRunning) {
          _readTimeWatch.stop();
        }
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached) {
          final elapsedSeconds = _readTimeWatch.elapsed.inSeconds;
          if (elapsedSeconds > 5) {
            epubPlayerKey.currentState?.saveReadingProgress(immediate: true);
            readingTimeDao.insertReadingTime(
              ReadingTime(
                bookId: _book.id,
                readingTime: elapsedSeconds,
              ),
              startedAt: _sessionStart,
            );
          }
          _readTimeWatch.reset();
          _sessionStart = null;
        }
        break;
    }
  }

  Future<void> setAwakeTimer(int minutes) async {
    _awakeTimer?.cancel();
    _awakeTimer = null;
    WakelockPlus.enable();
    _awakeTimer = Timer.periodic(Duration(minutes: minutes), (timer) {
      WakelockPlus.disable();
      _awakeTimer?.cancel();
      _awakeTimer = null;
    });
  }

  void resetAwakeTimer() {
    setAwakeTimer(Prefs().awakeTime);
  }

  void showBottomBar() {
    setState(() {
      showStatusBarWithoutResize();
      bottomBarOffstage = false;
      _releaseReaderFocus();
    });
  }

  void hideBottomBar() {
    setState(() {
      _currentPage = empty;
      _activeTool = ReaderTool.none;
      bottomBarOffstage = true;
      if (Prefs().hideStatusBar) {
        hideStatusBar();
      }
      _requestReaderFocus();
    });
  }

  void showOrHideAppBarAndBottomBar(bool show) {
    if (show) {
      showBottomBar();
    } else {
      hideBottomBar();
    }
  }

  Future<void> tocHandler() async {
    hideBottomBar();
    _scaffoldKey.currentState?.openDrawer();
  }

  /// Opens a tool, or closes it when it is already the open one.
  void _showTool(ReaderTool tool, Widget panel) {
    setState(() {
      if (_activeTool == tool) {
        _activeTool = ReaderTool.none;
        _currentPage = empty;
        return;
      }
      _activeTool = tool;
      _currentPage = panel;
    });
  }

  void noteHandler() {
    _showTool(ReaderTool.notes, ReadingNotes(book: _book));
  }

  void progressHandler() {
    _showTool(
      ReaderTool.progress,
      ProgressWidget(
        epubPlayerKey: epubPlayerKey,
        showOrHideAppBarAndBottomBar: showOrHideAppBarAndBottomBar,
      ),
    );
  }

  Future<void> styleHandler() async {
    if (_activeTool == ReaderTool.style) {
      _showTool(ReaderTool.style, empty);
      return;
    }
    List<ReadTheme> themes = await themeDao.selectThemes();
    if (!mounted) return;
    _showTool(
      ReaderTool.style,
      StyleWidget(
        themes: themes,
        epubPlayerKey: epubPlayerKey,
        setCurrentPage: (Widget page) {
          setState(() {
            _currentPage = page;
          });
        },
        hideAppBarAndBottomBar: showOrHideAppBarAndBottomBar,
      ),
    );
  }

  void updateState() {
    if (mounted) {
      setState(() {
        bookmarkExists = epubPlayerKey.currentState!.bookmarkExists;
      });
    }
  }

  Future<void> _copyChapter() async {
    final l10n = L10n.of(context);
    try {
      var content = await epubPlayerKey.currentState?.theChapterContent();
      var len = content?.length ?? 0;
      if (len > 0) {
        await Clipboard.setData(ClipboardData(text: content!));
      }
      AnxToast.show(l10n.readingPageCopiedCharacters(len));
    } catch (e) {
      AnxToast.show(l10n.readingPageErrorCopyingContent);
    }
  }

  void _toggleBookmark() {
    if (bookmarkExists) {
      epubPlayerKey.currentState!.removeAnnotation(
        epubPlayerKey.currentState!.bookmarkCfi,
      );
    } else {
      epubPlayerKey.currentState!.addBookmarkHere();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPanel = !identical(_currentPage, empty);
    final controller = PointerInterceptor(
      intercepting: !bottomBarOffstage,
      child: ReaderChrome(
        visible: !bottomBarOffstage,
        title: _book.title,
        bookmarkExists: bookmarkExists,
        activeTool: _activeTool,
        panel: hasPanel ? _currentPage : null,
        onDismiss: () => showOrHideAppBarAndBottomBar(false),
        onBack: () => Navigator.pop(context),
        onBookmark: _toggleBookmark,
        onCopyChapter: _copyChapter,
        onBookDetails: () => Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => BookDetail(book: widget.book),
          ),
        ),
        onContents: tocHandler,
        onNotes: noteHandler,
        onProgress: progressHandler,
        onStyle: styleHandler,
      ),
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Hero(
        tag: widget.heroTag ??
            (Prefs().openBookAnimation ? _book.coverFullPath : heroTag),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: Scaffold(
              key: _scaffoldKey,
              resizeToAvoidBottomInset: false,
              drawer: PointerInterceptor(
                child: Drawer(
                  width: math.min(
                    MediaQuery.of(context).size.width * 0.8,
                    420,
                  ),
                  child: SafeArea(
                    child: TocWidget(
                      epubPlayerKey: epubPlayerKey,
                      hideAppBarAndBottomBar: showOrHideAppBarAndBottomBar,
                      closeDrawer: () {
                        _scaffoldKey.currentState?.closeDrawer();
                      },
                    ),
                  ),
                ),
              ),
              // A Scaffold gives its body loose constraints, so this Stack must
              // be told to fill them. Every child here is either positioned or
              // an Offstage that reports zero size while the toolbar is hidden,
              // which is the state the reader opens in. Without expand the Stack
              // collapses to nothing, Positioned.fill fills nothing, and the
              // WebView is laid out at 0x0: the book loads and no pixel of it is
              // ever on screen. Upstream got its size from the AI panel's
              // AxisFlex, which was a non-positioned child; removing the AI
              // subsystem removed the only thing sizing this Stack.
              body: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: MouseRegion(
                      onHover: (PointerHoverEvent detail) {
                        if (!Prefs().showMenuOnHover) return;
                        var y = detail.position.dy;
                        if (y < 30 ||
                            y > MediaQuery.of(context).size.height - 30) {
                          showOrHideAppBarAndBottomBar(true);
                        }
                      },
                      child: Focus(
                        focusNode: _readerFocusNode,
                        onKeyEvent: _handleReaderKeyEvent,
                        child: EpubPlayer(
                          key: epubPlayerKey,
                          book: _book,
                          cfi: widget.cfi,
                          showOrHideAppBarAndBottomBar:
                              showOrHideAppBarAndBottomBar,
                          onLoadEnd: () {},
                          initialThemes: widget.initialThemes,
                          updateParent: updateState,
                        ),
                      ),
                    ),
                  ),
                  controller,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
