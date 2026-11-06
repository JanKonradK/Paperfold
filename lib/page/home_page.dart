import 'package:paperfold/utils/paperfold_layout.dart';
import 'package:paperfold/service/book.dart';
import 'package:paperfold/dao/book.dart';
import 'package:paperfold/service/capture_launch.dart';
import 'package:paperfold/service/quick_capture.dart';
import 'package:paperfold/page/journal/journal_home_page.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:paperfold/dao/database.dart';
import 'package:paperfold/enums/sync_direction.dart';
import 'package:paperfold/enums/sync_trigger.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/service/initialization_check.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:paperfold/page/settings_page/settings_home_page.dart';
import 'package:paperfold/page/home_page/statistics_page.dart';
import 'package:paperfold/service/receive_file/receive_share.dart';
import 'package:paperfold/service/reading_reminder.dart';
import 'package:paperfold/service/vibration_service.dart';
import 'package:paperfold/utils/check_update.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/load_default_font.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/platform_utils.dart';
import 'package:paperfold/providers/journal_home.dart';
import 'package:paperfold/providers/month_tracker.dart';
import 'package:paperfold/providers/reading_challenge.dart';
import 'package:paperfold/providers/sync.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:paperfold/widgets/common/load_failure.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';
import 'package:paperfold/widgets/paperfold_library_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/config/paperfold_motion.dart';
import 'package:paperfold/config/paperfold_system.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

WebViewEnvironment? webViewEnvironment;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({
    super.key,
    required this.databaseReady,
    this.startupRevealReady,
  });

  /// Completes after the shared startup database connection is ready.
  final Future<void> databaseReady;

  /// Completes after any cold-start cover has gone, including an early skip.
  final Future<void>? startupRevealReady;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _destination = 1;
  final _pageKey = GlobalKey();
  List<int> _destinationHistory = [1];
  final Set<int> _visitedDestinations = {1};

  /// The Library's claim on the back gesture, so a held book goes back on its
  /// shelf before back starts walking the tab history.
  final LibraryBackHandle _libraryBack = LibraryBackHandle();
  final GlobalKey _pageStackKey = GlobalKey();

  /// True for the few seconds after the reader has been asked whether they
  /// meant to leave, during which one more back closes the application.
  ///
  /// Back on the last screen used to close Paperfold outright, which on a
  /// phone is one careless thumb away from losing the place you were at. The
  /// press before it now only says so.
  bool _leaving = false;
  Timer? _leavingTimer;
  Object? _startupError;

  static const Duration _leavingWindow = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    initAnx();
    QuickCapture.pending.addListener(_onCaptureRequest);
    CaptureLaunch.openBook.addListener(_onOpenBookRequest);
    // A cold start from a widget or notification sets these before the home
    // page exists; answer them once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onCaptureRequest();
      _onOpenBookRequest();
    });
  }

  /// Shows the destination at [index], as a tap on the bar would.
  void _goTo(int index) {
    if (!mounted || index == _destination) return;
    setState(() {
      _leaving = false;
      _leavingTimer?.cancel();
      _destination = index;
      _visitedDestinations.add(index);
      _destinationHistory = [..._destinationHistory, index];
    });
  }

  /// The composer lives in the Journal, which mounts on its first visit.
  /// Bring it up; the Journal consumes the pending request itself.
  void _onCaptureRequest() {
    if (QuickCapture.pending.value == null) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    _goTo(0);
  }

  Future<void> _onOpenBookRequest() async {
    final request = CaptureLaunch.takeOpenBook();
    if (request == null || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    final id = request.bookId;
    if (id == null) {
      // The current book's Continue pane is on the Library.
      _goTo(1);
      return;
    }
    try {
      final book = await bookDao.selectBookById(id);
      if (!mounted) return;
      if (book.isPhysical) {
        QuickCapture.request(
          QuickCaptureRequest(
            kind: QuickCaptureKind.progress,
            bookId: id,
            source: request.source,
          ),
        );
        return;
      }
      await pushToReadingPage(ref, context, book);
    } catch (e) {
      AnxLog.info('Open book request $id failed: $e');
      _goTo(1);
    }
  }

  @override
  void dispose() {
    QuickCapture.pending.removeListener(_onCaptureRequest);
    CaptureLaunch.openBook.removeListener(_onOpenBookRequest);
    _leavingTimer?.cancel();
    _libraryBack.dispose();
    super.dispose();
  }

  /// Says that one more back will leave, and forgets it again shortly.
  void _armLeaving(BuildContext context) {
    if (_leaving) return;
    setState(() => _leaving = true);
    _leavingTimer?.cancel();
    _leavingTimer = Timer(_leavingWindow, () {
      if (mounted) setState(() => _leaving = false);
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).appPressBackAgainToLeave),
          duration: _leavingWindow,
        ),
      );
  }

  Future<void> _checkWindowsWebview() async {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
    if (!mounted) return;
    AnxLog.info('WebView2 version: $availableVersion');

    if (availableVersion == null) {
      SmartDialog.show(
        builder: (context) => AlertDialog(
          title: const Icon(Icons.error),
          content: Text(L10n.of(context).webview2NotInstalled),
          actions: [
            TextButton(
              onPressed: () => {
                launchUrl(
                  Uri.parse(
                    'https://developer.microsoft.com/en-us/microsoft-edge/webview2',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
              },
              child: Text(L10n.of(context).webview2Install),
            ),
          ],
        ),
      );
    } else {
      webViewEnvironment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: (await getAnxTempDir()).path,
        ),
      );
    }
  }

  void _showDbUpdatedDialog() {
    SmartDialog.show(
      clickMaskDismiss: false,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).commonAttention),
        content: Text(L10n.of(context).dbUpdatedTip),
        actions: [
          TextButton(
            onPressed: () {
              SmartDialog.dismiss();
            },
            child: Text(L10n.of(context).commonOk),
          ),
        ],
      ),
    );
  }

  Future<void> initAnx() async {
    try {
      await Future.wait([
        widget.databaseReady,
        if (widget.startupRevealReady case final revealReady?) revealReady,
      ]);
    } catch (error, stackTrace) {
      AnxLog.severe('Could not start library services', error, stackTrace);
      if (mounted) setState(() => _startupError = error);
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }

    AnxToast.init(context);
    checkUpdate(false);
    InitializationCheck.check();
    if (Prefs().webdavStatus) {
      await Sync().init();
      if (!mounted) return;
      await Sync().syncData(SyncDirection.both, ref, trigger: SyncTrigger.auto);
      if (!mounted) return;
    }
    loadDefaultFont();

    if (AnxPlatform.isWindows) {
      await _checkWindowsWebview();
      if (!mounted) return;
    }

    if (AnxPlatform.isAndroid || AnxPlatform.isIOS || AnxPlatform.isOhos) {
      receiveShareIntent(ref);
    }
    unawaited(ReadingReminder.restore(L10n.of(context)));

    if (DBHelper.updatedDB) {
      _showDbUpdatedDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (_startupError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Paperfold')),
        body: LoadFailure.page(
          title: l10n.appStartupFailed,
          body: l10n.appStartupFailedBody,
          error: _startupError,
        ),
      );
    }
    final destinations = [
      (
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book,
        label: l10n.navJournal,
      ),
      (
        icon: Icons.local_library_outlined,
        selectedIcon: Icons.local_library,
        label: l10n.navLibrary,
      ),
      (
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights,
        label: l10n.navBarStatistics,
      ),
      (
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: l10n.navBarSettings,
      ),
    ];
    final pages = [
      const _JournalDestination(),
      ShelfHomePage(backHandle: _libraryBack),
      StatisticPage(active: _destination == 2),
      const SettingsHomePage(),
    ];

    void refreshJournalOnReturn(int index) {
      if (index != 0 || !_visitedDestinations.contains(0)) return;
      unawaited(ref.read(journalHomeProvider.notifier).refresh());
      unawaited(ref.read(readingChallengeProvider.notifier).refresh());
      unawaited(ref.read(monthTrackerProvider.notifier).refresh());
    }

    void selectDestination(int index) {
      VibrationService.heavy();
      if (index == _destination) {
        return;
      }
      refreshJournalOnReturn(index);
      setState(() {
        _leaving = false;
        _leavingTimer?.cancel();
        _destination = index;
        _visitedDestinations.add(index);
        _destinationHistory = [..._destinationHistory, index];
      });
    }

    void handleBack(bool didPop, Object? result) {
      if (didPop || _destinationHistory.length <= 1) {
        return;
      }
      setState(() {
        _destinationHistory = _destinationHistory.sublist(
          0,
          _destinationHistory.length - 1,
        );
        _destination = _destinationHistory.last;
      });
      refreshJournalOnReturn(_destination);
    }

    final pageStack = IndexedStack(
      key: _pageStackKey,
      index: _destination,
      children: [
        for (var index = 0; index < pages.length; index++)
          _visitedDestinations.contains(index)
              ? ExcludeFocus(
                  excluding: index != _destination,
                  child: TickerMode(
                    enabled: index == _destination,
                    child: pages[index],
                  ),
                )
              : const SizedBox.shrink(),
      ],
    );

    // Rebuilt whenever the Library takes or releases its claim, because
    // `canPop` is read at build time and a book leaves the shelf without this
    // page rebuilding for any other reason.
    return Theme(
      data: paperfoldLibraryTheme(Theme.of(context)),
      child: ListenableBuilder(
        listenable: _libraryBack,
        builder: (context, child) => PopScope<Object?>(
          // Only the armed second press leaves. Everything else is ours to
          // answer, so that the last back on the shelf asks before it closes the
          // application rather than closing it.
          canPop:
              _leaving &&
              _destinationHistory.length <= 1 &&
              !(_destination == 1 && _libraryBack.canTakeBack),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            // The Library first. Only one of the three may act on one press.
            if (_destination == 1 && _libraryBack.takeBack()) return;
            if (_destinationHistory.length > 1) {
              handleBack(didPop, result);
              return;
            }
            _armLeaving(context);
          },
          child: child!,
        ),
        // One design on every width: the page runs on behind the floating
        // glass bar. The Scaffold adds the bar to the body's bottom padding,
        // so a scroll view that honours MediaQuery padding stops its last
        // item above the bar.
        child: Builder(
          builder: (context) {
            // Landscape saves height: the same bar stands on the start edge.
            final side = PaperfoldLayout.of(context).sideNavigation(context);
            // The key keeps every destination's state when the device turns.
            final page = _DestinationFade(
              key: _pageKey,
              index: _destination,
              child: pageStack,
            );
            return Scaffold(
              extendBody: !side,
              body: side
                  ? Row(
                      children: [
                        SafeArea(
                          right: false,
                          child: _SlidingNavigationBar(
                            vertical: true,
                            selectedIndex: _destination,
                            onDestinationSelected: selectDestination,
                            destinations: destinations,
                          ),
                        ),
                        Expanded(
                          child: MediaQuery.removePadding(
                            context: context,
                            removeLeft: true,
                            child: page,
                          ),
                        ),
                      ],
                    )
                  : page,
              bottomNavigationBar: side
                  ? null
                  : _SlidingNavigationBar(
                      selectedIndex: _destination,
                      onDestinationSelected: selectDestination,
                      destinations: destinations,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _SlidingNavigationBar extends StatelessWidget {
  const _SlidingNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.vertical = false,
  });

  /// Standing on the start edge in landscape, where height is scarce.
  final bool vertical;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<({IconData icon, IconData selectedIcon, String label})>
  destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glass = PaperfoldGlassStyle.fromScheme(scheme);
    final mediaQuery = MediaQuery.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final largeText = MediaQuery.textScalerOf(context).scale(12) > 18;
    final bottomInset = math.max(
      mediaQuery.padding.bottom,
      mediaQuery.systemGestureInsets.bottom,
    );

    return LayoutBuilder(
      builder: (context, available) {
        final columns = vertical
            ? 1
            : largeText && available.maxWidth < 480
            ? 2
            : destinations.length;
        final rows = (destinations.length / columns).ceil();
        // The vertical bar is the same bar turned on its side: same slots,
        // same curve, same indicator.
        final slot = largeText ? 96.0 : PaperfoldSize.navigationBar;
        final barHeight = vertical
            ? rows * slot + (rows - 1) * (largeText ? 0 : 8) + 8
            : rows > 1
            ? 136.0
            : (largeText ? 104.0 : PaperfoldSize.navigationBar);
        // A tablet gets the phone's bar, centred, not a stretched one.
        return Align(
          alignment: vertical
              ? AlignmentDirectional.centerStart
              : Alignment.center,
          heightFactor: vertical ? null : 1,
          widthFactor: vertical ? 1 : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: vertical
                  ? const EdgeInsetsDirectional.only(start: 12, end: 12)
                  : EdgeInsetsDirectional.fromSTEB(12, 4, 12, bottomInset + 8),
              child: SizedBox(
                width: vertical ? (largeText ? 96 : 76) : null,
                height: barHeight,
                child: PaperfoldGlassSurface(
                  shadow: true,
                  // Nothing passes behind this bar any more: `extendBody` is off, so
                  // the page stops above it and the only thing left to blur is the
                  // scaffold's flat ground. The filter cost a full-width readback on
                  // every frame and blurred a solid colour into the same colour.
                  borderRadius: PaperfoldShape.frameRadius,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final gap = largeText ? 0.0 : 8.0;
                        final slotWidth =
                            (constraints.maxWidth - gap * (columns - 1)) /
                            columns;
                        final slotHeight =
                            (constraints.maxHeight - gap * (rows - 1)) / rows;
                        return Semantics(
                          role: SemanticsRole.tabBar,
                          explicitChildNodes: true,
                          child: Stack(
                            children: [
                              AnimatedPositionedDirectional(
                                key: const Key('sliding-navigation-indicator'),
                                duration: disableAnimations
                                    ? Duration.zero
                                    : PaperfoldMotion.move,
                                // Lands with a small overshoot under the finger.
                                curve: PaperfoldMotion.land,
                                top:
                                    (selectedIndex ~/ columns) *
                                    (slotHeight + gap),
                                start:
                                    (selectedIndex % columns) *
                                    (slotWidth + gap),
                                width: slotWidth,
                                height: slotHeight,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(
                                      PaperfoldShape.nested(
                                        PaperfoldShape.frame,
                                        4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: [
                                  for (
                                    var index = 0;
                                    index < destinations.length;
                                    index++
                                  )
                                    SizedBox(
                                      width: slotWidth,
                                      height: slotHeight,
                                      child: _SlidingNavigationItem(
                                        tabIndex: index,
                                        destination: destinations[index],
                                        selected: index == selectedIndex,
                                        unselectedForeground: glass.foreground,
                                        onTap: () =>
                                            onDestinationSelected(index),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingNavigationItem extends StatelessWidget {
  const _SlidingNavigationItem({
    required this.tabIndex,
    required this.destination,
    required this.selected,
    required this.unselectedForeground,
    required this.onTap,
  });

  final int tabIndex;
  final ({IconData icon, IconData selectedIcon, String label}) destination;
  final bool selected;
  final Color unselectedForeground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected
        ? scheme.onPrimaryContainer
        : unselectedForeground;

    return Semantics(
      key: ValueKey('navigation-tab-$tabIndex'),
      role: SemanticsRole.tab,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            PaperfoldShape.nested(PaperfoldShape.frame, 4),
          ),
          child: SizedBox.expand(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.textScalerOf(context).scale(12) > 18
                    ? 2
                    : 6,
              ),
              child: Flex(
                direction: Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.0 : 0.92,
                    duration: PaperfoldMotion.of(context, PaperfoldMotion.move),
                    curve: PaperfoldMotion.land,
                    child: AnimatedSwitcher(
                      duration: PaperfoldMotion.of(
                        context,
                        PaperfoldMotion.tick,
                      ),
                      child: Icon(
                        selected ? destination.selectedIcon : destination.icon,
                        key: ValueKey(selected),
                        size: PaperfoldSize.icon,
                        color: foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6, height: 2),
                  Flexible(
                    child: Text(
                      destination.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 12,
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reading tools and the book journals, in the same visual system as the library.
class _JournalDestination extends StatelessWidget {
  const _JournalDestination();
  @override
  Widget build(BuildContext context) => const JournalHomePage();
}

/// Fades the destination in when [index] changes, keeping the page state.
///
/// The incoming page rises from 98.5% while it fades in over 200 ms. Nothing
/// runs at rest, and Remove animations shows the page at once.
class _DestinationFade extends StatefulWidget {
  const _DestinationFade({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_DestinationFade> createState() => _DestinationFadeState();
}

class _DestinationFadeState extends State<_DestinationFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: PaperfoldMotion.shift,
    value: 1,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: PaperfoldMotion.settle,
  );

  @override
  void didUpdateWidget(_DestinationFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      if (PaperfoldMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => _controller.isCompleted
          ? child!
          : Opacity(
              opacity: _t.value,
              child: Transform.scale(
                scale: 0.985 + 0.015 * _t.value,
                child: child,
              ),
            ),
      child: widget.child,
    );
  }
}
