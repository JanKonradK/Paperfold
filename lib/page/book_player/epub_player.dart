import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/dao/book_note.dart';
import 'package:paperfold/enums/book_status.dart';
import 'package:paperfold/enums/page_turn_mode.dart';
import 'package:paperfold/enums/reading_info.dart';
import 'package:paperfold/enums/translation_mode.dart';
import 'package:paperfold/enums/writing_mode.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/book.dart';
import 'package:paperfold/models/book_style.dart';
import 'package:paperfold/models/bookmark.dart';
import 'package:paperfold/models/font_model.dart';
import 'package:paperfold/models/read_theme.dart';
import 'package:paperfold/models/reading_rules.dart';
import 'package:paperfold/models/search_result_model.dart';
import 'package:paperfold/models/toc_item.dart';
import 'package:paperfold/page/book_player/image_viewer.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/page/reading_page.dart';
import 'package:paperfold/providers/book_list.dart';
import 'package:paperfold/providers/book_toc.dart';
import 'package:paperfold/providers/bookmark.dart';
import 'package:paperfold/providers/chapter_content_bridge.dart';
import 'package:paperfold/providers/current_reading.dart';
import 'package:paperfold/service/book_player/book_player_server.dart';
import 'package:paperfold/providers/toc_search.dart';
import 'package:paperfold/utils/coordinates_to_part.dart';
import 'package:paperfold/utils/js/convert_dart_color_to_js.dart';
import 'package:paperfold/utils/platform_utils.dart';
import 'package:paperfold/models/book_note.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/webView/gererate_url.dart';
import 'package:paperfold/utils/webView/webview_console_message.dart';
import 'package:paperfold/widgets/book_opening_page.dart';
import 'package:paperfold/widgets/context_menu/context_menu.dart';
import 'package:paperfold/widgets/page_curl/page_curl.dart';
import 'package:paperfold/widgets/reading_page/more_settings/page_turning/diagram.dart';
import 'package:paperfold/widgets/reading_page/more_settings/page_turning/types_and_icons.dart';
import 'package:paperfold/widgets/reading_page/style_widget.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import 'minute_clock.dart';

class EpubPlayer extends ConsumerStatefulWidget {
  final Book book;
  final String? cfi;
  final Function showOrHideAppBarAndBottomBar;
  final Function onLoadEnd;
  final List<ReadTheme> initialThemes;
  final Function updateParent;

  const EpubPlayer(
      {super.key,
      required this.showOrHideAppBarAndBottomBar,
      required this.book,
      this.cfi,
      required this.onLoadEnd,
      required this.initialThemes,
      required this.updateParent});

  @override
  ConsumerState<EpubPlayer> createState() => EpubPlayerState();
}

class EpubPlayerState extends ConsumerState<EpubPlayer>
    with TickerProviderStateMixin {
  late InAppWebViewController webViewController;
  late ContextMenu contextMenu;
  String cfi = '';
  double percentage = 0.0;
  String chapterTitle = '';
  String chapterHref = '';
  int chapterCurrentPage = 0;
  int chapterTotalPages = 0;
  OverlayEntry? contextMenuEntry;

  /// Fades the opening page off once the text is genuinely there.
  AnimationController? _animationController;
  Animation<double>? _animation;

  /// Turns the mark on the opening page while the book is being read in.
  AnimationController? _waitingController;

  /// True once the reader has reported that it has laid the text out, or once
  /// the fallback has given up waiting for it to say so.
  bool _textReady = false;
  Timer? _openingFallback;
  Timer? _settleTimer;

  /// When the opening page went up, so a book that was already warm does not
  /// flash a page at the reader and take it away again.
  final Stopwatch _openingShown = Stopwatch();

  /// The reader says it has laid the text out before that text has been
  /// painted. Lifting the page on the signal itself uncovers a frame or two of
  /// half-drawn book, which is the flicker this delay exists to swallow.
  static const Duration _settleDelay = Duration(milliseconds: 480);

  /// The least time the page stays up once it is up.
  static const Duration _minimumDwell = Duration(milliseconds: 900);

  /// How long the page takes to turn off the screen.
  static const Duration _turnAway = PaperfoldMotion.leafLift;
  bool showHistory = false;
  bool canGoBack = false;
  bool canGoForward = false;
  late Book book;
  String? backgroundColor;
  String? textColor;
  Timer? styleTimer;
  String bookmarkCfi = '';
  bool bookmarkExists = false;
  WritingModeEnum writingMode = WritingModeEnum.horizontalTb;
  String? _lastSelectionContextText;
  bool _selectionClearLocked = false;
  bool _selectionClearPending = false;

  // Scroll wheel debounce
  Timer? _scrollDebounceTimer;
  double _accumulatedScrollDelta = 0;
  static const double _scrollThreshold = 50.0;

  // Write-behind for the reading position. See saveReadingProgress.
  Timer? _progressSaveTimer;
  bool _progressDirty = false;
  String? _passageReturnCfi;
  String? _resumeAtCfi;
  bool _passageNavigating = false;

  // The page-curl turn.
  //
  // The shader needs pixels, and a WebView capture always stalls a frame
  // (docs/paperfold/webview-capture-cost.md). So the page is captured while
  // nothing is animating, and the turn itself spends nothing: the frozen
  // capture curls away while the WebView, hidden underneath it, jumps to the
  // destination with its own animation switched off. The page below the leaf is
  // handed in as one transparent pixel, so what the turn uncovers is the live
  // WebView already showing the destination, with the roll's shadow on it.
  //
  // A tap turns on a clock. A swipe is turned by the finger: the drag comes out
  // of JavaScript, because the finger is on the WebView and never touches a
  // Flutter widget, and the leaf is let go of into a spring.
  //
  // A capture that no longer matches the reading position is not shown. Turning
  // faster than the capture can keep up gives a plain turn for those pages
  // rather than the wrong page curling away.
  final PageCurlController _curlController = PageCurlController();
  ui.Image? _curlFront;
  ui.Image? _curlVerso;
  String _curlFrontCfi = '';
  bool _curlTurning = false;
  bool _showCurl = false;
  TextDirection _curlDirection = TextDirection.ltr;
  Timer? _curlCaptureTimer;

  // The footer battery reading. A FutureBuilder over Battery().batteryLevel
  // asked the platform channel again on every rebuild, so every page turn paid
  // a channel round trip and the glyph blinked out while the future was
  // pending. A charge level does not change inside a page turn.
  int? _batteryLevel;
  Timer? _batteryTimer;

  // to know anytime if we are on top of navigation stack
  bool get _isTopOfNavigationStack =>
      ModalRoute.of(context)?.isCurrent ?? false;

  void prevPage() {
    if (Prefs().pageTurnStyle.isShaderCurl) {
      unawaited(_turnWithCurl(forward: false));
      return;
    }
    webViewController.evaluateJavascript(source: 'prevPage()');
  }

  void nextPage() {
    if (Prefs().pageTurnStyle.isShaderCurl) {
      unawaited(_turnWithCurl(forward: true));
      return;
    }
    webViewController.evaluateJavascript(source: 'nextPage()');
  }

  void prevChapter() {
    webViewController.evaluateJavascript(source: '''
      prevSection()
      ''');
  }

  void nextChapter() {
    webViewController.evaluateJavascript(source: '''
      nextSection()
      ''');
  }

  void setTranslationMode(TranslationModeEnum mode) {
    webViewController.evaluateJavascript(source: '''
      if (typeof reader.view !== 'undefined' && reader.view.setTranslationMode) {
        reader.view.setTranslationMode('${mode.code}');
      }
      ''');
  }

  Future<void> goToPercentage(double value) async {
    await webViewController.evaluateJavascript(source: '''
      goToPercent($value); 
      ''');
  }

  void setSelectionClearLocked(bool locked) {
    _selectionClearLocked = locked;
    if (!locked && _selectionClearPending) {
      _selectionClearPending = false;
      _lastSelectionContextText = null;
      removeOverlay();
    }
  }

  void changeTheme(ReadTheme readTheme) {
    textColor = readTheme.textColor;
    backgroundColor = readTheme.backgroundColor;

    String bc = convertDartColorToJs(readTheme.backgroundColor);
    String tc = convertDartColorToJs(readTheme.textColor);

    webViewController.evaluateJavascript(source: '''
      changeStyle({
        backgroundColor: '#$bc',
        fontColor: '#$tc',
      })
      ''');
  }

  void changeStyle(BookStyle? bookStyle) {
    styleTimer?.cancel();
    String bgimgUrl = Prefs().bgimg.getEffectiveUrl(
          isDarkMode: isDarkMode,
          autoAdjust: Prefs().autoAdjustReadingTheme,
        );

    styleTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      BookStyle style = bookStyle ?? Prefs().bookStyle;
      webViewController.evaluateJavascript(source: '''
      changeStyle({
        fontSize: ${style.fontSize},
        spacing: ${style.lineHeight},
        fontWeight: ${style.fontWeight},
        paragraphSpacing: ${style.paragraphSpacing},
        topMargin: ${style.topMargin},
        bottomMargin: ${style.bottomMargin},
        sideMargin: ${style.sideMargin},
        letterSpacing: ${style.letterSpacing},
        textIndent: ${style.indent},
        maxColumnCount: ${style.maxColumnCount},
        columnThreshold: ${style.columnThreshold},
        writingMode: '${Prefs().writingMode.code}',
        textAlign: '${Prefs().textAlignment.code}',
        backgroundImage: '$bgimgUrl',
        bgimgBlur: ${Prefs().bgimg.blur},
        bgimgOpacity: ${Prefs().bgimg.opacity},
        bgimgFit: '${Prefs().bgimgFit.code}',
        customCSS: `${Prefs().customCSS.replaceAll('`', '\\`')}`,
        customCSSEnabled: ${Prefs().customCSSEnabled},
        useBookStyles: ${Prefs().useBookStyles},
        headingFontSize: ${style.headingFontSize},
        codeHighlightTheme: '${Prefs().codeHighlightTheme.code}',
      })
      ''');
    });
  }

  void changeBgimgEffect() {
    if (!mounted) return;
    final bgimg = Prefs().bgimg;
    final bgimgUrl = bgimg.getEffectiveUrl(
      isDarkMode: isDarkMode,
      autoAdjust: Prefs().autoAdjustReadingTheme,
    );
    webViewController.evaluateJavascript(source: '''
      changeStyle({
        backgroundImage: '$bgimgUrl',
        bgimgBlur: ${bgimg.blur},
        bgimgOpacity: ${bgimg.opacity},
        bgimgFit: '${Prefs().bgimgFit.code}',
      })
    ''');
  }

  void changeReadingRules(ReadingRules readingRules) {
    webViewController.evaluateJavascript(source: '''
      readingFeatures({
        convertChineseMode: '${readingRules.convertChineseMode.name}',
      })
    ''');
  }

  void changeFont(FontModel font) {
    webViewController.evaluateJavascript(source: '''
      changeStyle({
        fontName: '${font.name}',
        fontPath: '${font.path}',
      })
    ''');
  }

  void changePageTurnStyle(PageTurn pageTurnStyle) {
    webViewController.evaluateJavascript(source: '''
      changeStyle({
        pageTurnStyle: '${pageTurnStyle.name}',
      })
    ''');
    if (pageTurnStyle.isShaderCurl) {
      // Compile the shader now. Doing it on the first turn would stall the
      // frame the curl starts on, which is the one frame it cannot afford.
      unawaited(PageCurl.warmUp());
      _scheduleCurlCapture();
    } else {
      _curlCaptureTimer?.cancel();
      _curlFront?.dispose();
      _curlFront = null;
      _curlFrontCfi = '';
    }
  }

  void goToHref(String href) =>
      webViewController.evaluateJavascript(source: "goToHref('$href')");

  Future<void> goToCfi(String cfi) async {
    await webViewController.evaluateJavascript(
      source: 'goToCfi(${jsonEncode(cfi)})',
    );
  }

  /// Visits a journal source without replacing the main reading position.
  Future<void> previewPassage(String targetCfi) async {
    if (_passageNavigating || !mounted) return;
    setState(() => _passageNavigating = true);
    try {
      if (_passageReturnCfi == null && widget.cfi == null) {
        if (cfi.isEmpty) throw StateError('The reader is not ready');
        await saveReadingProgress(immediate: true);
        if (!mounted) return;
        setState(() => _passageReturnCfi = cfi);
      }
      _resumeAtCfi = null;
      await _goToPassage(targetCfi);
    } finally {
      if (mounted) setState(() => _passageNavigating = false);
    }
  }

  Future<String> _goToPassage(String targetCfi) async {
    // evaluateJavascript does not await the renderer's navigation Promise.
    final result = await webViewController.callAsyncJavaScript(
      arguments: {'targetCfi': targetCfi},
      functionBody: '''
        const view = reader.view;
        const resolved = await view.resolveNavigation(targetCfi);
        if (!resolved) throw new Error('The passage cannot be resolved');
        const moved = await goToCfi(targetCfi);
        const location = view.lastLocation;
        const content = view.renderer.getContents()
          .find(entry => entry.index === resolved.index);
        if (!moved || !location || !location.cfi || !content) {
          throw new Error('The passage is not available');
        }
        const anchor = typeof resolved.anchor === 'function'
          ? resolved.anchor(content.doc) : null;
        if (anchor && anchor.startContainer && location.range &&
            !location.range.isPointInRange(anchor.startContainer, anchor.startOffset)) {
          throw new Error('The passage is not visible');
        }
        return location.cfi;
      ''',
    );
    if (result?.error != null || result?.value is! String) {
      throw StateError('Could not navigate to the passage: ${result?.error}');
    }
    return result!.value as String;
  }

  Future<void> returnToReading() async {
    final targetCfi = _passageReturnCfi;
    if (targetCfi == null || _passageNavigating || !mounted) return;
    setState(() => _passageNavigating = true);
    try {
      final returnedCfi = await _goToPassage(targetCfi);
      if (!mounted) return;
      // The platform may deliver onRelocated before or after the JS result.
      // Keep preview writes disabled until both confirm the return location.
      _resumeAtCfi = returnedCfi;
      _finishPassageReturn(cfi);
    } catch (error, stackTrace) {
      AnxLog.warning(
          'Could not return to the reading position', error, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).journalPassageOpenFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _passageNavigating = false);
    }
  }

  void _finishPassageReturn(String locationCfi) {
    if (_resumeAtCfi != null && _resumeAtCfi == locationCfi) {
      setState(() {
        _passageReturnCfi = null;
        _resumeAtCfi = null;
        showHistory = false;
      });
    }
  }

  void addAnnotation(BookNote bookNote) {
    final noteContent =
        (bookNote.content).replaceAll('\n', ' ').replaceAll("'", "\\'");
    webViewController.evaluateJavascript(source: '''
      addAnnotation({
        id: ${bookNote.id},
        type: '${bookNote.type}',
        value: '${bookNote.cfi}',
        color: '#${bookNote.color}',
        note: '$noteContent',
      })
      ''');
  }

  void addBookmark(BookmarkModel bookmark) {
    webViewController.evaluateJavascript(source: '''
      addAnnotation({
        id: ${bookmark.id},
        type: 'bookmark',
        value: '${bookmark.cfi}',
        color: '#000000',
        note: 'None',
      })
      ''');
  }

  void addBookmarkHere() {
    webViewController.evaluateJavascript(source: '''
      addBookmarkHere()
      ''');
  }

  void removeAnnotation(String cfi) =>
      webViewController.evaluateJavascript(source: "removeAnnotation('$cfi')");

  void clearSearch() {
    ref.read(tocSearchProvider.notifier).clear();
    _clearSearchHighlights();
  }

  void search(String text) {
    final sanitized = text.trim();
    if (sanitized.isEmpty) {
      clearSearch();
      return;
    }
    _clearSearchHighlights();
    ref.read(tocSearchProvider.notifier).start(sanitized);
    webViewController.evaluateJavascript(source: '''
      search('$sanitized', {
        'scope': 'book',
        'matchCase': false,
        'matchDiacritics': false,
        'matchWholeWords': false,
      })
    ''');
  }

  void _clearSearchHighlights() {
    webViewController.evaluateJavascript(source: "clearSearch()");
  }

  Future<bool> isFootNoteOpen() async => (await webViewController
      .evaluateJavascript(source: "window.isFootNoteOpen()"));

  void backHistory() {
    webViewController.evaluateJavascript(source: "back()");
  }

  void forwardHistory() {
    webViewController.evaluateJavascript(source: "forward()");
  }

  void refreshToc() {
    webViewController.evaluateJavascript(source: "refreshToc()");
  }

  Future<String> theChapterContent() async =>
      await webViewController.evaluateJavascript(
        source: "theChapterContent()",
      );

  Future<String> previousContent(int count) async =>
      await webViewController.evaluateJavascript(
        source: "previousContent($count)",
      );

  Future<String> _getCurrentChapterContent({int? maxCharacters}) async {
    final raw = await theChapterContent();
    return _normalizeChapterContent(raw, maxCharacters);
  }

  Future<String> _getChapterContentByHref(
    String href, {
    int? maxCharacters,
  }) async {
    if (href.isEmpty) {
      return '';
    }

    final result = await webViewController.callAsyncJavaScript(
      functionBody:
          'return await getChapterContentByHref("${href.replaceAll('"', '\\"')}")',
    );

    final value = result?.value;
    if (value is String) {
      return _normalizeChapterContent(value, maxCharacters);
    }
    return '';
  }

  String _normalizeChapterContent(String? content, int? maxCharacters) {
    if (content == null || content.isEmpty) {
      return '';
    }
    final trimmed = content.trim();
    if (maxCharacters != null &&
        maxCharacters > 0 &&
        trimmed.length > maxCharacters) {
      return trimmed.substring(0, maxCharacters);
    }
    return trimmed;
  }

  void _registerChapterContentBridge() {
    ref.read(chapterContentBridgeProvider.notifier).state =
        ChapterContentHandlers(
      fetchCurrentChapter: ({int? maxCharacters}) =>
          _getCurrentChapterContent(maxCharacters: maxCharacters),
      fetchChapterByHref: (href, {int? maxCharacters}) =>
          _getChapterContentByHref(href, maxCharacters: maxCharacters),
    );
  }

  Future<void> _handleExternalLink(dynamic rawLink) async {
    String? normalizeExternalLink(dynamic raw) {
      if (raw == null) {
        return null;
      }
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
      if (raw is Map && raw['href'] is String) {
        final href = raw['href'].toString().trim();
        return href.isEmpty ? null : href;
      }
      return null;
    }

    final link = normalizeExternalLink(rawLink);
    if (!mounted || link == null) {
      return;
    }

    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme.isEmpty || uri.scheme == 'javascript') {
      AnxLog.warning('Ignored invalid external link: $link');
      return;
    }

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = L10n.of(dialogContext);
        return AlertDialog(
          title: Text(l10n.readingPageOpenExternalLinkTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.readingPageOpenExternalLinkMessage),
              const SizedBox(height: 8),
              SelectableText(link),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.readingPageOpenExternalLinkAction),
            ),
          ],
        );
      },
    );

    if (shouldOpen != true) {
      return;
    }

    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      AnxLog.warning('Failed to open external link: $link');
    }
  }

  void onClick(Map<String, dynamic> location) {
    readingPageKey.currentState?.resetAwakeTimer();
    if (contextMenuEntry != null) {
      removeOverlay();
      return;
    }
    final x = location['x'];
    final y = location['y'];
    final part = coordinatesToPart(x, y);

    PageTurningType action;
    final pageTurnMode = PageTurnMode.fromCode(Prefs().pageTurnMode);

    if (pageTurnMode == PageTurnMode.simple) {
      // Use predefined page turning types
      final currentPageTurningType = Prefs().pageTurningType;
      final pageTurningType = pageTurningTypes[currentPageTurningType];
      action = pageTurningType[part];

      // Apply swap if enabled
      if (Prefs().swapPageTurnArea) {
        if (action == PageTurningType.prev) {
          action = PageTurningType.next;
        } else if (action == PageTurningType.next) {
          action = PageTurningType.prev;
        }
      }
    } else {
      // Use custom configuration
      final customConfig = Prefs().customPageTurnConfig;
      action = PageTurningType.values[customConfig[part]];
    }

    // Disable mouse/touch page turning when keyboard shortcuts are enabled
    if (Prefs().keyboardShortcutTurnPage) {
      // Only allow menu action, disable prev/next page turning
      if (action == PageTurningType.prev || action == PageTurningType.next) {
        return;
      }
    }

    switch (action) {
      case PageTurningType.prev:
        prevPage();
        break;
      case PageTurningType.next:
        nextPage();
        break;
      case PageTurningType.menu:
        widget.showOrHideAppBarAndBottomBar(true);
        break;
      case PageTurningType.none:
        break;
    }
  }

  Future<void> renderAnnotations(InAppWebViewController controller) async {
    List<BookNote> annotationList =
        await bookNoteDao.selectBookNotesByBookId(widget.book.id);
    String allAnnotations =
        jsonEncode(annotationList.map((e) => e.toJson()).toList())
            .replaceAll('\'', '\\\'');
    controller.evaluateJavascript(source: '''
     const allAnnotations = $allAnnotations
     renderAnnotations()
    ''');
  }

  void getThemeColor() {
    if (Prefs().autoAdjustReadingTheme) {
      List<ReadTheme> themes = widget.initialThemes;
      final isDayMode = !isDarkMode;
      backgroundColor =
          isDayMode ? themes[0].backgroundColor : themes[1].backgroundColor;
      textColor = isDayMode ? themes[0].textColor : themes[1].textColor;
    } else {
      backgroundColor = Prefs().readTheme.backgroundColor;
      textColor = Prefs().readTheme.textColor;
    }
  }

  /// True once the opening page has faded right off and need not be built.
  bool get _openingPageGone =>
      _textReady && (_animationController?.isCompleted ?? false);

  /// Takes the opening page off, once.
  ///
  /// Called by the reader when it has laid the text out, and by the fallbacks
  /// if it never says so. The page does not come off on the signal itself: it
  /// waits out [_settleDelay] so the first page is painted behind it, and it
  /// stays at least [_minimumDwell] so a book that was already warm does not
  /// show a page for three frames and snatch it away.
  void _revealText() {
    if (_textReady || !mounted) return;
    _textReady = true;
    _openingFallback?.cancel();

    final shown = _openingShown.elapsed;
    final remaining = _minimumDwell - shown;
    final wait = remaining > _settleDelay ? remaining : _settleDelay;
    _settleTimer?.cancel();
    _settleTimer = Timer(wait, () {
      if (!mounted) return;
      _animationController?.forward().whenComplete(() {
        if (mounted) {
          _waitingController?.stop();
          setState(() {});
        }
      });
    });
  }

  Future<void> setHandler(InAppWebViewController controller) async {
    controller.addJavaScriptHandler(
        handlerName: 'onLoadEnd',
        callback: (args) {
          _revealText();
          widget.onLoadEnd();
        });

    controller.addJavaScriptHandler(
        handlerName: 'onRelocated',
        callback: (args) {
          if (!mounted) return;
          Map<String, dynamic> location = args[0];
          _finishPassageReturn(location['cfi'] ?? '');
          if (cfi == location['cfi']) return;
          // if (chapterHref != location['chapterHref']) {
          //   refreshToc();
          // }
          setState(() {
            cfi = location['cfi'] ?? '';
            percentage =
                double.tryParse(location['percentage'].toString()) ?? 0.0;
            chapterTitle = location['chapterTitle'] ?? '';
            chapterHref = location['chapterHref'] ?? '';
            chapterCurrentPage = location['chapterCurrentPage'] ?? 0;
            chapterTotalPages = location['chapterTotalPages'] ?? 0;
            bookmarkExists = location['bookmark']['exists'] ?? false;
            bookmarkCfi = location['bookmark']['cfi'] ?? '';
            writingMode =
                WritingModeEnum.fromCode(location['writingMode'] ?? '');
          });
          ref.read(currentReadingProvider.notifier).update(
                cfi: cfi,
                percentage: percentage,
                chapterTitle: chapterTitle,
                chapterHref: chapterHref,
                chapterCurrentPage: chapterCurrentPage,
                chapterTotalPages: chapterTotalPages,
              );
          widget.updateParent();
          saveReadingProgress();
          _scheduleCurlCapture();
          readingPageKey.currentState?.resetAwakeTimer();
        });
    controller.addJavaScriptHandler(
        handlerName: 'onClick',
        callback: (args) {
          Map<String, dynamic> location = args[0];
          onClick(location);
        });
    // The swipe that turns a page with the curl. It arrives from JavaScript
    // because the page lives in the WebView, so the finger never lands on a
    // Flutter widget at all.
    controller.addJavaScriptHandler(
      handlerName: 'onPageDragStart',
      callback: (args) {
        final data = args[0] as Map<dynamic, dynamic>;
        unawaited(_onPageDragStart(
          (data['dx'] as num).toDouble(),
          (data['y'] as num).toDouble(),
        ));
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onPageDragUpdate',
      callback: (args) {
        final data = args[0] as Map<dynamic, dynamic>;
        _onPageDragUpdate(
          (data['dx'] as num).toDouble(),
          (data['y'] as num).toDouble(),
        );
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onPageDragEnd',
      callback: (args) {
        final data = args[0] as Map<dynamic, dynamic>;
        _onPageDragEnd(
          (data['velocityX'] as num).toDouble(),
          (data['dx'] as num?)?.toDouble() ?? 0.0,
        );
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onExternalLink',
      callback: (args) async {
        final payload = args.isNotEmpty ? args.first : null;
        await _handleExternalLink(payload);
      },
    );
    controller.addJavaScriptHandler(
        handlerName: 'onSetToc',
        callback: (args) {
          List<dynamic> t = args[0];
          final toc = t.map((i) => TocItem.fromJson(i)).toList();
          ref.read(bookTocProvider.notifier).setToc(toc);
        });
    controller.addJavaScriptHandler(
        handlerName: 'onSelectionEnd',
        callback: (args) {
          removeOverlay();
          Map<String, dynamic> location = args[0];
          String cfi = location['cfi'];
          String text = location['text'];
          bool footnote = location['footnote'];
          final rawContextText = location['contextText']?.toString();
          _lastSelectionContextText =
              (rawContextText?.trim().isEmpty ?? true) ? null : rawContextText;
          double left = (location['pos']['left'] as num).toDouble();
          double top = (location['pos']['top'] as num).toDouble();
          double right = (location['pos']['right'] as num).toDouble();
          double bottom = (location['pos']['bottom'] as num).toDouble();
          showContextMenu(
            context,
            left,
            top,
            right,
            bottom,
            text,
            cfi,
            null,
            footnote,
            writingMode.isVertical ? Axis.vertical : Axis.horizontal,
            contextText: _lastSelectionContextText,
          );
        });
    controller.addJavaScriptHandler(
        handlerName: 'onSelectionCleared',
        callback: (args) {
          if (_selectionClearLocked) {
            _selectionClearPending = true;
            return;
          }
          _lastSelectionContextText = null;
          removeOverlay();
        });
    controller.addJavaScriptHandler(
        handlerName: 'onAnnotationClick',
        callback: (args) {
          Map<String, dynamic> annotation = args[0];

          if (annotation['annotation'] == null) {
            // Nothing to open: the tap did not land on a stored annotation.
            return;
          }

          int id = annotation['annotation']['id'];
          String cfi = annotation['annotation']['value'];
          String note = annotation['annotation']['note'];
          final rawContextText = annotation['contextText']?.toString();
          _lastSelectionContextText =
              (rawContextText?.trim().isEmpty ?? true) ? null : rawContextText;
          double left = (annotation['pos']['left'] as num).toDouble();
          double top = (annotation['pos']['top'] as num).toDouble();
          double right = (annotation['pos']['right'] as num).toDouble();
          double bottom = (annotation['pos']['bottom'] as num).toDouble();
          showContextMenu(
            context,
            left,
            top,
            right,
            bottom,
            note,
            cfi,
            id,
            false,
            writingMode.isVertical ? Axis.vertical : Axis.horizontal,
            contextText: _lastSelectionContextText,
          );
        });
    controller.addJavaScriptHandler(
      handlerName: 'onSearch',
      callback: (args) {
        Map<String, dynamic> search = args[0];
        setState(() {
          final tocSearch = ref.read(tocSearchProvider.notifier);
          if (search['process'] != null) {
            final progress = search['process'].toDouble();
            tocSearch.updateProgress(progress);
          } else {
            tocSearch.addResult(SearchResultModel.fromJson(search));
          }
        });
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'renderAnnotations',
      callback: (args) {
        renderAnnotations(controller);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onPushState',
      callback: (args) {
        Map<String, dynamic> state = args[0];
        if (!mounted) return;
        setState(() {
          canGoBack = state['canGoBack'];
          canGoForward = state['canGoForward'];
          showHistory = canGoBack || canGoForward;
        });
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onImageClick',
      callback: (args) {
        String image = args[0];
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ImageViewer(
                      image: image,
                      bookName: widget.book.title,
                    )));
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onFootnoteClose',
      callback: (args) {
        removeOverlay();
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'onPullUp',
      callback: (args) {
        widget.showOrHideAppBarAndBottomBar(true);
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'handleBookmark',
      callback: (args) async {
        Map<String, dynamic> detail = args[0]['detail'];
        bool remove = args[0]['remove'];
        String cfi = detail['cfi'] ?? '';
        double percentage = double.parse(detail['percentage'].toString());
        String content = detail['content'];

        if (remove) {
          ref.read(bookmarkProvider(widget.book.id).notifier).removeBookmark(
                cfi: cfi,
              );
          bookmarkCfi = '';
          bookmarkExists = false;
        } else {
          BookmarkModel bookmark = await ref
              .read(BookmarkProvider(widget.book.id).notifier)
              .addBookmark(
                BookmarkModel(
                  bookId: widget.book.id,
                  cfi: cfi,
                  percentage: percentage,
                  content: content,
                  chapter: chapterTitle,
                  updateTime: DateTime.now(),
                  createTime: DateTime.now(),
                ),
              );
          bookmarkCfi = cfi;
          bookmarkExists = true;
          addBookmark(bookmark);
        }
        widget.updateParent();
        setState(() {});
      },
    );
    controller.addJavaScriptHandler(
      handlerName: 'translateText',
      callback: (args) async {
        try {
          String text = args[0];
          final service = Prefs().fullTextTranslateService;
          final from = Prefs().fullTextTranslateFrom;
          final to = Prefs().fullTextTranslateTo;

          return await service.provider
              .translateTextOnly(text, from, to, isFullText: true);
        } catch (e) {
          AnxLog.severe('Translation error: $e');
          return 'Translation error: $e';
        }
      },
    );
  }

  Future<void> onWebViewCreated(InAppWebViewController controller) async {
    if (AnxPlatform.isAndroid) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
    // The document is up. The reader still has to lay the text out and say so,
    // and it usually does within a few hundred milliseconds, but a book whose
    // script never reports must not hold the page for the whole of the long
    // fallback. This is the short one, armed only once there is a document.
    _openingFallback?.cancel();
    _openingFallback = Timer(
      const Duration(milliseconds: 1400),
      () => _revealText(),
    );
    webViewController = controller;
    setHandler(controller);
    _registerChapterContentBridge();

    // Initialize translation mode based on book-specific settings
    Future.delayed(const Duration(milliseconds: 300), () {
      setTranslationMode(Prefs().getBookTranslationMode(widget.book.id));
    });
  }

  void removeOverlay() {
    _selectionClearLocked = false;
    _selectionClearPending = false;
    if (contextMenuEntry == null || contextMenuEntry?.mounted == false) return;
    contextMenuEntry?.remove();
    contextMenuEntry = null;
  }

  Future<void> _handlePointerEvents(PointerEvent event) async {
    if (await isFootNoteOpen() || Prefs().pageTurnStyle == PageTurn.scroll) {
      return;
    }
    // Disable scroll wheel page turning when keyboard shortcuts are enabled
    if (Prefs().keyboardShortcutTurnPage) {
      return;
    }
    if (event is PointerScrollEvent) {
      _accumulatedScrollDelta += event.scrollDelta.dy;

      _scrollDebounceTimer?.cancel();
      _scrollDebounceTimer = Timer(const Duration(milliseconds: 80), () {
        if (_accumulatedScrollDelta.abs() >= _scrollThreshold) {
          if (_accumulatedScrollDelta > 0) {
            nextPage();
          } else {
            prevPage();
          }
        }
        _accumulatedScrollDelta = 0;
      });
    }
  }

  /// The reader URL, built once.
  ///
  /// It carries the whole style block as query parameters, so recomputing it
  /// meant re-reading and re-encoding every preference. It was rebuilt on
  /// every relocate, which is every page turn, and the WebView only ever reads
  /// it at load.
  late final String _readerUrl;

  @override
  void initState() {
    book = widget.book;
    getThemeColor();
    _readerUrl = generateUrl(
      'http://127.0.0.1:${Server().port}'
      '/book/${Uri.encodeComponent(widget.book.fileFullPath)}',
      widget.cfi ?? widget.book.lastReadPosition,
      backgroundColor: backgroundColor,
      textColor: textColor,
      isDarkMode: isDarkMode,
    );

    contextMenu = ContextMenu(
      settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: true),
      onCreateContextMenu: (hitTestResult) async {
        // webViewController.evaluateJavascript(source: "showContextMenu()");
      },
      onHideContextMenu: () {
        // removeOverlay();
      },
    );
    _readBatteryLevel();
    _batteryTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _readBatteryLevel(),
    );
    // The page the book opened onto is already on screen when this route
    // arrives: the shelf raised it, and the reader draws the same thing. It
    // comes off when the text is laid out and not a moment before. It used to
    // be a second copy of the cover, fading on a fixed six hundred
    // milliseconds that had nothing to do with whether the book had loaded, so
    // it could uncover a blank page or sit over a page that was ready.
    _openingShown.start();
    _animationController = AnimationController(
      duration: _turnAway,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController!,
      // A leaf on its way out of the book, not a thing easing to a stop: it
      // starts from rest and is gone. `easeInOutCubic` spent the last third of
      // the movement setting down a sheet the reader can no longer see.
      curve: PaperfoldMotion.depart,
    );
    _waitingController = AnimationController(
      duration: const Duration(milliseconds: 2600),
      vsync: this,
    )..repeat();
    // A reader that never reports back must not leave the page up for good.
    _openingFallback = Timer(
      const Duration(seconds: 8),
      () => _revealText(),
    );
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  /// Records the reading position.
  ///
  /// A relocate arrives on every page turn. Writing the book row and then
  /// rebuilding the whole library there cost a stutter exactly when the turn
  /// animation needed the frame: `BookList.refresh` re-reads every book, reads
  /// the tag tables, pinyin-sorts and regroups. None of that is visible while
  /// the reader is on screen, so a turn now only marks the position dirty. The
  /// row is written after the reader has been still for a moment, and the
  /// library is rebuilt once, when the reader leaves.
  /// Whether a swipe is currently holding a leaf open.
  bool _curlDragActive = false;

  /// True once the curl is on screen and ready to be moved by the finger.
  bool _curlDragReady = false;

  /// The last movement reported while the curl was still being got ready.
  Offset? _curlDragPending;

  /// Which way the swipe was going, so a spring back can be undone.
  bool _curlDragForward = true;

  /// The edge of the sheet the finger is pulling from.
  double _curlDragEdgeX = 0;

  /// Takes hold of a leaf. The finger is on the WebView, not on any widget.
  ///
  /// The WebView is sent to the destination page straight away, before the leaf
  /// has moved. At zero the curl covers the screen with the captured page, so
  /// nothing of the jump is visible - and it means what the leaf uncovers as it
  /// peels is the real next page rather than a blank sheet.
  Future<void> _onPageDragStart(double dx, double y) async {
    final front = _curlFront;
    if (_curlTurning ||
        _curlDragActive ||
        front == null ||
        _curlFrontCfi != cfi ||
        !mounted) {
      return;
    }

    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = (dx < 0) != rtl;

    _curlTurning = true;
    _curlDragActive = true;
    _curlDragReady = false;
    _curlDragForward = forward;
    _curlDragPending = null;
    _curlFront = null;

    _curlVerso ??= await _makeVerso();
    if (!mounted || !_curlDragActive) {
      front.dispose();
      _curlTurning = false;
      _curlDragActive = false;
      return;
    }

    final width = MediaQuery.sizeOf(context).width;
    // A page is pulled from its free edge, which is the side the reader turns
    // from. The finger may have landed anywhere, so what is forwarded is how
    // far it has travelled and the edge supplies the rest.
    final direction = (forward != rtl) ? TextDirection.ltr : TextDirection.rtl;
    _curlDragEdgeX = direction == TextDirection.ltr ? width : 0.0;

    setState(() {
      _showCurl = true;
      _curlFront = front;
      _curlDirection = direction;
    });

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_curlDragActive) return;
    webViewController.evaluateJavascript(
      source: forward ? 'nextPage()' : 'prevPage()',
    );

    if (!_curlController.isAttached) return;
    _curlController.dragBegin(Offset(_curlDragEdgeX, y));
    _curlDragReady = true;
    // Everything the finger did while this was being got ready.
    final pending = _curlDragPending;
    if (pending != null) {
      _curlDragPending = null;
      _curlController.dragUpdate(
        Offset(_curlDragEdgeX + pending.dx, pending.dy),
      );
    }
  }

  void _onPageDragUpdate(double dx, double y) {
    if (!_curlDragActive) return;
    if (!_curlDragReady) {
      _curlDragPending = Offset(dx, y);
      return;
    }
    if (!_curlController.isAttached) return;
    _curlController.dragUpdate(Offset(_curlDragEdgeX + dx, y));
  }

  /// Lets the leaf go. The spring decides where it lands, not this method.
  void _onPageDragEnd(double velocityX, double dx) {
    if (!_curlDragActive) {
      // This drag was never taken up - most often because the capture the curl
      // needs was stale, which is the case for a moment after every turn. The
      // WebView's own paging is switched off while the curl owns the gesture,
      // so without this the swipe would do nothing at all and the reader would
      // be swiping at a page that refuses to move.
      _turnPlainlyFromDrag(velocityX, dx);
      return;
    }
    if (!_curlDragReady || !_curlController.isAttached) {
      // Let go before the leaf was ever lifted. Put everything back.
      _abandonCurlDrag(completed: false);
      return;
    }
    _curlController.dragEnd(velocityX);
  }

  /// Turns the page without a curl, for a swipe the curl could not take.
  void _turnPlainlyFromDrag(double velocityX, double dx) {
    if (!mounted) return;
    final width = MediaQuery.sizeOf(context).width;
    if (width <= 0) return;
    final travelled = dx.abs() / width;
    final flung = velocityX.abs() / width >= PaperfoldMotion.flickVelocity;
    if (travelled < 0.2 && !flung) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = (dx < 0) != rtl;
    webViewController.evaluateJavascript(
      source: forward ? 'nextPage()' : 'prevPage()',
    );
    _scheduleCurlCapture();
  }

  /// Called when the spring has finished, whichever end it reached.
  void _onCurlSettled(bool completed) {
    if (!_curlDragActive) return;
    _abandonCurlDrag(completed: completed);
  }

  void _abandonCurlDrag({required bool completed}) {
    if (!_curlDragActive) return;
    _curlDragActive = false;
    _curlDragReady = false;
    _curlDragPending = null;

    // The page sprang back, so the WebView has to go back with it. This is
    // done under a curl still covering the screen at zero, so the return jump
    // is no more visible than the outward one was.
    if (!completed) {
      webViewController.evaluateJavascript(
        source: _curlDragForward ? 'prevPage()' : 'nextPage()',
      );
    }

    final front = _curlFront;
    if (mounted) {
      setState(() {
        _showCurl = false;
        _curlFront = null;
      });
    }
    front?.dispose();
    _curlTurning = false;
    _scheduleCurlCapture();
  }

  /// Turns the page with the curl shader, or plainly when no usable capture is
  /// on hand.
  Future<void> _turnWithCurl({required bool forward}) async {
    void turnInWebView() {
      webViewController.evaluateJavascript(
        source: forward ? 'nextPage()' : 'prevPage()',
      );
    }

    final front = _curlFront;
    if (_curlTurning || front == null || _curlFrontCfi != cfi || !mounted) {
      turnInWebView();
      return;
    }

    _curlTurning = true;
    _curlFront = null;
    _curlVerso ??= await _makeVerso();
    if (!mounted) {
      front.dispose();
      _curlTurning = false;
      return;
    }

    // A page turned in an RTL interface leaves from the other side.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    setState(() {
      _showCurl = true;
      _curlFront = front;
      _curlDirection = (forward != rtl) ? TextDirection.ltr : TextDirection.rtl;
    });

    // The capture must be on screen before the WebView jumps underneath it,
    // or the reader sees the destination page for one frame.
    await WidgetsBinding.instance.endOfFrame;
    turnInWebView();

    try {
      if (_curlController.isAttached) {
        await _curlController.animate(
          to: 1.0,
          duration: PaperfoldMotion.pageTurn,
          curve: PaperfoldMotion.turn,
        );
      }
    } catch (e) {
      AnxLog.warning('Page curl did not run: $e');
    }

    if (mounted) {
      setState(() {
        _showCurl = false;
        _curlFront = null;
      });
    }
    front.dispose();
    _curlTurning = false;
    _scheduleCurlCapture();
  }

  /// What the turning leaf uncovers: nothing, so that the reader shows through.
  ///
  /// This used to be a solid rectangle of the reading background, which meant
  /// the whole turn uncovered *blank paper* and the next page only appeared
  /// once the curl had finished and the overlay was taken away. A tap could get
  /// away with that at three hundred milliseconds. A drag cannot: the reader
  /// holds the leaf half open, looks at the page they are turning to, and finds
  /// an empty sheet.
  ///
  /// One transparent pixel instead. The WebView is already underneath this
  /// overlay and has already been sent to the destination, so what the leaf
  /// uncovers is the real next page, live, with the roll's shadow falling
  /// across it.
  Future<ui.Image> _makeVerso() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0x00000000),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    picture.dispose();
    return image;
  }

  /// Captures the page once the reader has been still for a moment.
  ///
  /// Idle is the only safe time: the capture stalls a frame, so taking it
  /// during a turn would cost exactly the smoothness the curl is meant to add.
  void _scheduleCurlCapture() {
    _curlCaptureTimer?.cancel();
    if (!Prefs().pageTurnStyle.isShaderCurl) return;
    _curlCaptureTimer = Timer(const Duration(milliseconds: 400), _capturePage);
  }

  Future<void> _capturePage() async {
    if (!mounted || _curlTurning || !Prefs().pageTurnStyle.isShaderCurl) return;
    try {
      final bytes = await webViewController.takeScreenshot(
        screenshotConfiguration: ScreenshotConfiguration(
          compressFormat: CompressFormat.JPEG,
          quality: 80,
        ),
      );
      if (bytes == null || !mounted) return;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted || _curlTurning) {
        frame.image.dispose();
        return;
      }
      _curlFront?.dispose();
      _curlFront = frame.image;
      _curlFrontCfi = cfi;
    } catch (e) {
      AnxLog.warning('Page capture for the curl failed: $e');
    }
  }

  Future<void> _readBatteryLevel() async {
    try {
      final level = await Battery().batteryLevel;
      if (!mounted || level == _batteryLevel) return;
      setState(() => _batteryLevel = level);
    } catch (e) {
      AnxLog.warning('Battery level unavailable: $e');
    }
  }

  Future<void> saveReadingProgress({bool immediate = false}) async {
    if (cfi == '' || widget.cfi != null || _passageReturnCfi != null) return;
    _progressDirty = true;
    if (!immediate) {
      _progressSaveTimer?.cancel();
      _progressSaveTimer = Timer(
        const Duration(seconds: 3),
        () => _flushReadingProgress(refreshLibrary: false),
      );
      return;
    }
    _progressSaveTimer?.cancel();
    _progressSaveTimer = null;
    await _flushReadingProgress(refreshLibrary: true);
  }

  Future<void> _flushReadingProgress({required bool refreshLibrary}) async {
    if (!_progressDirty || _passageReturnCfi != null) return;
    _progressDirty = false;
    Book book = widget.book;
    book.lastReadPosition = cfi;
    book.readingPercentage = percentage;
    if (percentage >= 1) {
      book.status = BookStatus.finished;
      book.startedOn ??= DateTime.now();
      book.finishedOn ??= DateTime.now();
    } else if (percentage > 0 && book.status == BookStatus.notStarted) {
      book.status = BookStatus.reading;
      book.startedOn ??= DateTime.now();
    }
    await bookDao.updateBook(book);
    if (refreshLibrary && mounted) {
      ref.invalidate(bookListProvider);
    }
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    _progressSaveTimer?.cancel();
    _batteryTimer?.cancel();
    _curlCaptureTimer?.cancel();
    _curlFront?.dispose();
    _curlVerso?.dispose();
    _openingFallback?.cancel();
    _settleTimer?.cancel();
    _waitingController?.dispose();
    _animationController?.dispose();
    // The library reload belongs to pushToReadingPage, which still holds a
    // live ref once this route has gone. sqflite keeps queued work in order,
    // so this write lands before the reload reads the row back.
    _flushReadingProgress(refreshLibrary: false);
    removeOverlay();
    super.dispose();
  }

  InAppWebViewSettings initialSettings = InAppWebViewSettings(
    supportZoom: false,
    transparentBackground: true,
    isInspectable: kDebugMode,
    useHybridComposition: true,
  );

  bool get isDarkMode {
    // App chrome can be burgundy even when the reader uses a light page.
    final prefs = Prefs();
    if (prefs.eInkMode) return false;
    return switch (prefs.themeMode) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
  }

  void changeReadingInfo() {
    setState(() {});
  }

  Widget _buildHistoryCapsule() {
    final l10n = L10n.of(context);
    final buttonColor = Theme.of(context).colorScheme.onSurface;

    // Common button style for all history navigation buttons
    final buttonStyle = TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(32),
      ),
    );

    // Helper method to create history navigation buttons
    Widget createHistoryButton(
        IconData icon, String label, VoidCallback? onPressed) {
      return TextButton.icon(
        icon: Icon(icon, size: 18, color: buttonColor),
        label: Text(label, style: TextStyle(color: buttonColor, fontSize: 14)),
        onPressed: onPressed,
        style: buttonStyle,
      );
    }

    // Build buttons list
    final List<Widget> buttons = [];

    if (_passageReturnCfi != null) {
      buttons.add(createHistoryButton(
        Icons.keyboard_return,
        l10n.journalReturnToReading,
        _passageNavigating ? null : returnToReading,
      ));
    } else {
      if (canGoBack) {
        buttons.add(createHistoryButton(
          Icons.arrow_back,
          l10n.historyBack,
          backHistory,
        ));
      }

      buttons.add(createHistoryButton(
        Icons.close,
        l10n.historyClose,
        () => setState(() => showHistory = false),
      ));

      if (canGoForward) {
        buttons.add(createHistoryButton(
          Icons.arrow_forward,
          l10n.historyForward,
          forwardHistory,
        ));
      }
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 0.5,
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: buttons,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget readingInfoWidget() {
    if (chapterCurrentPage == 0 && percentage == 0.0) {
      return const SizedBox();
    }

    final readingInfoColor = Color(int.parse('0x$textColor')).withAlpha(150);
    final iconColor = Color(int.parse('0x$textColor'));

    Widget getWidget(ReadingInfoEnum readingInfoEnum, TextStyle textStyle) {
      final batteryTextStyle = TextStyle(
        color: iconColor,
        fontSize: (textStyle.fontSize ?? 10) - 1,
      );
      final batteryIconSize = (textStyle.fontSize ?? 10) * 2.7;

      final chapterTitleWidget = Text(
        (chapterCurrentPage == 1 ? widget.book.title : chapterTitle),
        style: textStyle,
      );

      final chapterProgressWidget = Text(
        '$chapterCurrentPage/$chapterTotalPages',
        style: textStyle,
      );

      final bookProgressWidget =
          Text('${(percentage * 100).toStringAsFixed(2)}%', style: textStyle);

      final timeWidget = MinuteClock(textStyle: textStyle);

      final batteryWidget = _batteryLevel == null
          ? const SizedBox()
          : Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      0, (textStyle.fontSize ?? 10) * 0.08, 2, 0),
                  child: Text('$_batteryLevel', style: batteryTextStyle),
                ),
                Icon(
                  HeroIcons.battery_0,
                  size: batteryIconSize,
                  color: iconColor,
                ),
              ],
            );

      Widget batteryAndTimeWidget() => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              batteryWidget,
              const SizedBox(width: 5),
              timeWidget,
            ],
          );

      switch (readingInfoEnum) {
        case ReadingInfoEnum.chapterTitle:
          return chapterTitleWidget;
        case ReadingInfoEnum.chapterProgress:
          return chapterProgressWidget;
        case ReadingInfoEnum.bookProgress:
          return bookProgressWidget;
        case ReadingInfoEnum.battery:
          return batteryWidget;
        case ReadingInfoEnum.time:
          return timeWidget;
        case ReadingInfoEnum.batteryAndTime:
          return batteryAndTimeWidget();
        case ReadingInfoEnum.none:
          return const SizedBox(width: 30);
      }
    }

    final readingInfo = Prefs().readingInfo;

    final headerTextStyle = TextStyle(
      color: readingInfoColor,
      fontSize: readingInfo.header.fontSize,
    );
    final footerTextStyle = TextStyle(
      color: readingInfoColor,
      fontSize: readingInfo.footer.fontSize,
    );

    List<Widget> headerWidgets = [
      getWidget(readingInfo.header.left, headerTextStyle),
      getWidget(readingInfo.header.center, headerTextStyle),
      getWidget(readingInfo.header.right, headerTextStyle),
    ];

    List<Widget> footerWidgets = [
      getWidget(readingInfo.footer.left, footerTextStyle),
      getWidget(readingInfo.footer.center, footerTextStyle),
      getWidget(readingInfo.footer.right, footerTextStyle),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: readingInfo.header.verticalMargin,
            left: readingInfo.header.leftMargin,
            right: readingInfo.header.rightMargin,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: headerWidgets,
          ),
        ),
        const Spacer(),
        Padding(
          padding: EdgeInsets.only(
            bottom: readingInfo.footer.verticalMargin,
            left: readingInfo.footer.leftMargin,
            right: readingInfo.footer.rightMargin,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: footerWidgets,
          ),
        ),
      ],
    );
  }

  Widget buildWebviewWithIOSWorkaround(BuildContext context) {
    final webView = InAppWebView(
      webViewEnvironment: webViewEnvironment,
      initialUrlRequest: URLRequest(url: WebUri(_readerUrl)),
      initialSettings: initialSettings,
      contextMenu: contextMenu,
      onLoadStop: (controller, uri) => onWebViewCreated(controller),
      onConsoleMessage: webviewConsoleMessage,
    );

    if (!AnxPlatform.isIOS) {
      return SizedBox.expand(child: webView);
    }

    return SizedBox.expand(
      child: Stack(
        children: [
          webView,
          Positioned.fill(
            child: PointerInterceptor(
              intercepting: !_isTopOfNavigationStack,
              debug: false,
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        _handlePointerEvents(event);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            buildWebviewWithIOSWorkaround(context),
            if (_showCurl && _curlFront != null && _curlVerso != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: PageCurl(
                    frontImage: _curlFront!,
                    backImage: _curlVerso!,
                    textDirection: _curlDirection,
                    controller: _curlController,
                    // The finger is on the WebView underneath, so this widget
                    // never sees a pointer. The drag reaches it from
                    // JavaScript through the controller instead.
                    interactive: false,
                    onSettled: _onCurlSettled,
                    reduceMotion: MediaQuery.of(context).disableAnimations,
                  ),
                ),
              ),
            readingInfoWidget(),
            if (showHistory || _passageReturnCfi != null)
              _buildHistoryCapsule(),
            if (!_openingPageGone)
              Positioned.fill(
                child: IgnorePointer(
                  child: _TurningLeaf(
                    progress: _animation!,
                    mirror: Directionality.of(context) == TextDirection.rtl,
                    child: BookOpeningPage(
                      title: book.title,
                      author: book.author,
                      turn: _waitingController,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Turns the opening page off the screen, the way the first leaf of a book is
/// turned.
///
/// A fade would have been cheaper and would have read as the page dissolving,
/// which is not a thing paper does. This swings the sheet about its bound edge
/// under a little perspective, darkening as it goes over, so the text that was
/// loading behind it is uncovered by the page moving rather than by the page
/// disappearing.
class _TurningLeaf extends StatelessWidget {
  const _TurningLeaf({
    required this.progress,
    required this.mirror,
    required this.child,
  });

  /// 0 while the page is up, 1 once it has turned right off.
  final Animation<double> progress;

  /// Right to left, a book is bound on the other side and the leaf turns the
  /// other way.
  final bool mirror;

  final Widget child;

  /// How far the leaf swings. Short of a right angle: past that it is edge on
  /// and there is nothing left to see, so the rest of the travel is spent on
  /// nothing.
  static const double _sweep = 1.45;

  /// How far through the turn the sheet stays completely solid.
  static const double _solidUntil = 0.78;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      // No motion asked for: the page simply stops being there.
      return FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(progress),
        child: child,
      );
    }
    return AnimatedBuilder(
      animation: progress,
      builder: (context, leaf) {
        final turned = progress.value;
        if (turned >= 1) return const SizedBox.shrink();
        // The sheet swings about its bound edge, so the far edge is the one
        // travelling and the light leaves it first.
        final shade = Curves.easeIn.transform(turned);
        return Transform(
          alignment: mirror ? Alignment.centerRight : Alignment.centerLeft,
          transform: Matrix4.identity()
            // The near edge of the leaf comes toward the reader as it lifts.
            ..setEntry(3, 2, 0.0011)
            ..rotateY(mirror ? turned * _sweep : -turned * _sweep),
          child: Opacity(
            // Opaque for almost the whole turn. Fading it from the start let
            // the chapter page show straight through a sheet that was still
            // nearly square on, which reads as a ghost rather than as paper.
            // It only goes once it is edge on and there is nothing left of it
            // to see anyway.
            opacity: turned <= _solidUntil
                ? 1
                : (1 - (turned - _solidUntil) / (1 - _solidUntil))
                    .clamp(0.0, 1.0),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                leaf!,
                // The face of the leaf turns away from the light as it goes
                // over, which is what makes it read as a solid sheet moving
                // rather than a picture being taken away.
                //
                // Graded across the sheet, not flat. A single even wash over
                // the whole page is the one thing a rotating surface cannot
                // produce: the edge swinging toward the reader stays lit while
                // the bound edge goes into shadow, and it is that difference,
                // not the darkening, that says the sheet has a shape.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: mirror
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        end: mirror
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.52 * shade),
                          Colors.black.withValues(alpha: 0.30 * shade),
                          Colors.black.withValues(alpha: 0.10 * shade),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: child,
    );
  }
}
