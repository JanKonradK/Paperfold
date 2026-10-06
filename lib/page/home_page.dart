import 'dart:async';
import 'dart:math' as math;

import 'package:paperfold/dao/database.dart';
import 'package:paperfold/enums/sync_direction.dart';
import 'package:paperfold/enums/sync_trigger.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/service/initialization_check.dart';
import 'package:paperfold/page/home_page/notes_page.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:paperfold/page/settings_page/settings_home_page.dart';
import 'package:paperfold/page/home_page/statistics_page.dart';
import 'package:paperfold/service/receive_file/receive_share.dart';
import 'package:paperfold/service/vibration_service.dart';
import 'package:paperfold/utils/check_update.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/load_default_font.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/platform_utils.dart';
import 'package:paperfold/page/journal/book_journal_page.dart';
import 'package:paperfold/page/search/search_page.dart';
import 'package:paperfold/page/journal/month_tracker_page.dart';
import 'package:paperfold/page/journal/reading_challenge_page.dart';
import 'package:paperfold/providers/journal_home.dart';
import 'package:paperfold/providers/month_tracker.dart';
import 'package:paperfold/providers/reading_challenge.dart';
import 'package:paperfold/providers/sync.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:paperfold/widgets/common/load_failure.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';
import 'package:paperfold/widgets/paperfold_logo_mark.dart';
import 'package:paperfold/widgets/paperfold_library_theme.dart';
import 'package:paperfold/widgets/settings/about.dart';
import 'package:flutter/material.dart';
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
  }

  @override
  void dispose() {
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
                        'https://developer.microsoft.com/en-us/microsoft-edge/webview2'),
                    mode: LaunchMode.externalApplication)
              },
              child: Text(L10n.of(context).webview2Install),
            ),
          ],
        ),
      );
    } else {
      webViewEnvironment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
            userDataFolder: (await getAnxTempDir()).path),
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
          canPop: _leaving &&
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              final extended = constraints.maxWidth > 1000;
              return Scaffold(
                body: Row(
                  children: [
                    SafeArea(
                      child: NavigationRail(
                        leading: Semantics(
                          button: true,
                          label: l10n.appAbout,
                          child: Tooltip(
                            message: l10n.appAbout,
                            child: InkWell(
                              onTap: openAboutDialog,
                              borderRadius: BorderRadius.circular(24),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: PaperfoldLogoMark(
                                    size: 32,
                                    tint:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        groupAlignment: 1,
                        extended: extended,
                        selectedIndex: _destination,
                        onDestinationSelected: selectDestination,
                        labelType:
                            extended ? null : NavigationRailLabelType.all,
                        destinations: [
                          for (final destination in destinations)
                            NavigationRailDestination(
                              icon: Icon(destination.icon),
                              selectedIcon: Icon(destination.selectedIcon),
                              label: Text(destination.label),
                            ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: SafeArea(
                        top: false,
                        child: pageStack,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Scaffold(
              // The bar gets its own strip of the screen and the page stops
              // above it. Under `extendBody` the shelf ran on behind the glass,
              // so a book title, a shelf name and the destinations were
              // all printed over one another at the foot of the Library.
              extendBody: false,
              body: pageStack,
              bottomNavigationBar: _SlidingNavigationBar(
                selectedIndex: _destination,
                onDestinationSelected: selectDestination,
                destinations: [
                  ...destinations,
                ],
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
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<
      ({
        IconData icon,
        IconData selectedIcon,
        String label,
      })> destinations;

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

    return LayoutBuilder(builder: (context, available) {
      final columns =
          largeText && available.maxWidth < 480 ? 2 : destinations.length;
      final rows = (destinations.length / columns).ceil();
      final barHeight = rows > 1 ? 144.0 : (largeText ? 112.0 : 72.0);
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(12, 4, 12, bottomInset + 8),
        child: SizedBox(
          height: barHeight,
          child: PaperfoldGlassSurface(
            // Nothing passes behind this bar any more: `extendBody` is off, so
            // the page stops above it and the only thing left to blur is the
            // scaffold's flat ground. The filter cost a full-width readback on
            // every frame and blurred a solid colour into the same colour.
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            allowBlur: false,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gap = largeText ? 0.0 : 8.0;
                  final slotWidth =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
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
                              : const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          top: (selectedIndex ~/ columns) * (slotHeight + gap),
                          start: (selectedIndex % columns) * (slotWidth + gap),
                          width: slotWidth,
                          height: slotHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (var index = 0;
                                index < destinations.length;
                                index++)
                              SizedBox(
                                width: slotWidth,
                                height: slotHeight,
                                child: _SlidingNavigationItem(
                                  tabIndex: index,
                                  destination: destinations[index],
                                  selected: index == selectedIndex,
                                  unselectedForeground: glass.foreground,
                                  onTap: () => onDestinationSelected(index),
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
      );
    });
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
  final ({
    IconData icon,
    IconData selectedIcon,
    String label,
  }) destination;
  final bool selected;
  final Color unselectedForeground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground =
        selected ? scheme.onPrimaryContainer : unselectedForeground;

    return Semantics(
      key: ValueKey('navigation-tab-$tabIndex'),
      role: SemanticsRole.tab,
      selected: selected,
      label: destination.label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox.expand(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal:
                    MediaQuery.textScalerOf(context).scale(12) > 18 ? 2 : 6,
              ),
              child: Flex(
                direction: Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: 6, height: 4),
                  Flexible(
                    child: Text(
                      destination.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
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
class _JournalDestination extends ConsumerWidget {
  const _JournalDestination();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final entries = ref.watch(journalHomeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navJournal),
        actions: [
          IconButton(
            tooltip: l10n.searchLibraryHint,
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SearchPage()),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: () async {
              await Future.wait([
                ref.read(journalHomeProvider.notifier).refresh(),
                ref.read(readingChallengeProvider.notifier).refresh(),
                ref.read(monthTrackerProvider.notifier).refresh(),
              ]);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  sliver: SliverList.list(children: [
                    const _JournalTools(),
                    const SizedBox(height: 28),
                    Text(l10n.journalBooks,
                        style: Theme.of(context).textTheme.titleLarge),
                  ]),
                ),
                ...entries.when(
                  loading: () => const [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (error, stackTrace) => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: LoadFailure.page(
                        title: l10n.journalLoadFailed,
                        error: error,
                        onRetry: () =>
                            ref.read(journalHomeProvider.notifier).refresh(),
                      ),
                    ),
                  ],
                  data: (data) {
                    if (data.isEmpty) {
                      return [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _DestinationEmptyState(
                            title: l10n.journalPlaceholderTitle,
                            body: l10n.journalPlaceholderBody,
                          ),
                        ),
                      ];
                    }
                    return [
                      SliverList.builder(
                        itemCount: data.length,
                        itemBuilder: (context, index) {
                          final entry = data[index];
                          final details = <String>[
                            if (entry.review != null) l10n.journalReviewed,
                            if (entry.pageCount > 0)
                              l10n.journalPagesCount(entry.pageCount),
                          ];
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            minTileHeight: 64,
                            leading: const Icon(Icons.menu_book_outlined),
                            title: Text(entry.book.title,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: details.isEmpty
                                ? null
                                : Text(details.join(' · ')),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      BookJournalPage(book: entry.book),
                                ),
                              );
                              if (context.mounted) {
                                await ref
                                    .read(journalHomeProvider.notifier)
                                    .refresh();
                              }
                            },
                          );
                        },
                      ),
                    ];
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JournalTools extends ConsumerWidget {
  const _JournalTools();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final challenge = ref.watch(readingChallengeProvider);
    final month = ref.watch(monthTrackerProvider);
    return Column(
      children: [
        _JournalTool(
          icon: Icons.local_library_outlined,
          title: l10n.challengeTitle,
          detail: challenge.hasError
              ? l10n.statisticTrackerLoadError
              : challenge.hasValue
                  ? '${challenge.requireValue.year} · '
                      '${l10n.challengeProgress(challenge.requireValue.finishedCount, challenge.requireValue.target)}'
                  : null,
          page: const ReadingChallengePage(),
        ),
        const Divider(height: 1),
        _JournalTool(
          icon: Icons.calendar_month_outlined,
          title: l10n.monthTrackerTitle,
          detail: month.hasError
              ? l10n.statisticTrackerLoadError
              : month.hasValue
                  ? '${MaterialLocalizations.of(context).formatMonthYear(DateTime(month.requireValue.year, month.requireValue.month))} · '
                      '${l10n.monthTrackerPagesTotal(month.requireValue.totalPages)}'
                  : null,
          page: const MonthTrackerPage(),
        ),
        const Divider(height: 1),
        _JournalTool(
          icon: Icons.format_quote_outlined,
          title: l10n.tileNotesTotalTitle,
          detail: l10n.journalHighlightsOverview,
          page: Scaffold(
            appBar: AppBar(title: Text(l10n.tileNotesTotalTitle)),
            body: const NotesPage(),
          ),
        ),
      ],
    );
  }
}

class _JournalTool extends StatelessWidget {
  const _JournalTool({
    required this.icon,
    required this.title,
    required this.detail,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Widget page;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 76,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: detail == null ? null : Text(detail!),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => page),
      ),
    );
  }
}

class _DestinationEmptyState extends StatelessWidget {
  const _DestinationEmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_note_outlined,
                  size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      )),
            ],
          ),
        ),
      ),
    );
  }
}
