import 'dart:math' as math;

import 'package:paperfold/dao/database.dart';
import 'package:paperfold/enums/sync_direction.dart';
import 'package:paperfold/enums/sync_trigger.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/service/initialization_check.dart';
import 'package:paperfold/page/home_page/notes_page.dart';
import 'package:paperfold/page/home_page/shelf_home_page.dart';
import 'package:paperfold/page/home_page/settings_page.dart';
import 'package:paperfold/page/home_page/statistics_page.dart';
import 'package:paperfold/service/receive_file/receive_share.dart';
import 'package:paperfold/service/vibration_service.dart';
import 'package:paperfold/utils/check_update.dart';
import 'package:paperfold/utils/get_path/get_temp_dir.dart';
import 'package:paperfold/utils/load_default_font.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/platform_utils.dart';
import 'package:paperfold/page/journal/book_review_page.dart';
import 'package:paperfold/page/journal/month_tracker_page.dart';
import 'package:paperfold/page/opds/opds_catalogs_page.dart';
import 'package:paperfold/page/journal/reading_challenge_page.dart';
import 'package:paperfold/providers/journal_home.dart';
import 'package:paperfold/providers/month_tracker.dart';
import 'package:paperfold/providers/reading_challenge.dart';
import 'package:paperfold/providers/sync.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:paperfold/widgets/ornament.dart';
import 'package:paperfold/widgets/paperfold_glass_surface.dart';
import 'package:paperfold/widgets/paperfold_logo_mark.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => initAnx());
  }

  Future<void> _checkWindowsWebview() async {
    final availableVersion = await WebViewEnvironment.getAvailableVersion();
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
    await Future.wait([
      widget.databaseReady,
      if (widget.startupRevealReady case final revealReady?) revealReady,
    ]);
    if (!mounted) {
      return;
    }

    AnxToast.init(context);
    checkUpdate(false);
    InitializationCheck.check();
    if (Prefs().webdavStatus) {
      await Sync().init();
      await Sync().syncData(SyncDirection.both, ref, trigger: SyncTrigger.auto);
    }
    loadDefaultFont();

    if (AnxPlatform.isWindows) {
      await _checkWindowsWebview();
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
        icon: Icons.more_horiz,
        selectedIcon: Icons.more,
        label: l10n.navMore,
      ),
    ];
    final pages = [
      const _JournalDestination(),
      const ShelfHomePage(),
      const _MorePlaceholder(),
    ];

    void selectDestination(int index) {
      VibrationService.heavy();
      if (index == _destination) {
        return;
      }
      setState(() {
        _destination = index;
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
    }

    final pageStack = IndexedStack(
      index: _destination,
      children: pages,
    );

    return PopScope<Object?>(
      canPop: _destinationHistory.length <= 1,
      onPopInvokedWithResult: handleBack,
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
                                  tint: Theme.of(context).colorScheme.secondary,
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
                      labelType: extended ? null : NavigationRailLabelType.all,
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
            extendBody: true,
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
    final bottomInset = math.max(
      mediaQuery.padding.bottom,
      mediaQuery.systemGestureInsets.bottom,
    );

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(12, 4, 12, bottomInset + 8),
      child: SizedBox(
        height: 56,
        child: PaperfoldGlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          blurSigma: 18,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 8.0;
                final slotWidth =
                    (constraints.maxWidth - gap * (destinations.length - 1)) /
                        destinations.length;
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
                        top: 0,
                        start: selectedIndex * (slotWidth + gap),
                        width: slotWidth,
                        height: 48,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var index = 0;
                              index < destinations.length;
                              index++) ...[
                            if (index > 0) const SizedBox(width: gap),
                            Expanded(
                              child: _SlidingNavigationItem(
                                tabIndex: index,
                                destination: destinations[index],
                                selected: index == selectedIndex,
                                unselectedForeground: glass.foreground,
                                onTap: () => onDestinationSelected(index),
                              ),
                            ),
                          ],
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
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      destination.label,
                      maxLines: 1,
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

/// The Journal destination: every book the reader has actually written in,
/// most recently touched first. A book with only blank pages does not appear,
/// because a blank page is not writing.
class _JournalDestination extends ConsumerWidget {
  const _JournalDestination();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final entries = ref.watch(journalHomeProvider);

    // The trackers sit above the per-book list rather than on destinations of
    // their own. The architecture is two destinations, cross-linked.
    final trackers = const SliverToBoxAdapter(child: _JournalTrackerCards());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navJournal)),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(journalHomeProvider.notifier).refresh();
          await ref.read(readingChallengeProvider.notifier).refresh();
          await ref.read(monthTrackerProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            trackers,
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
                  child: _DestinationEmptyState(
                    ornament: PaperfoldOrnament.rectangularVineFrame,
                    title: l10n.journalPlaceholderTitle,
                    body: l10n.journalPlaceholderBody,
                  ),
                ),
              ],
              data: (data) {
                if (data.isEmpty) {
                  return [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _DestinationEmptyState(
                        ornament: PaperfoldOrnament.rectangularVineFrame,
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
                        minTileHeight: 56,
                        title: Text(
                          entry.book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle:
                            details.isEmpty ? null : Text(details.join(' · ')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) =>
                                BookReviewPage(book: entry.book),
                          ),
                        ),
                      );
                    },
                  ),
                ];
              },
            ),
            // The floating glass bar overlays content, so the last row needs
            // room to clear it as well as the gesture inset.
            SliverToBoxAdapter(
              child: SizedBox(
                height: 96 + MediaQuery.viewPaddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two trackers, as summaries that open the full pages.
class _JournalTrackerCards extends ConsumerWidget {
  const _JournalTrackerCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final challenge = ref.watch(readingChallengeProvider);
    final month = ref.watch(monthTrackerProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      // Two cards, so both match the taller one. IntrinsicHeight is the cheap
      // way to do that; stretch alone asks for infinite height inside a sliver.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _TrackerCard(
                icon: Icons.local_library_outlined,
                title: l10n.challengeTitle,
                // An unread summary must not claim a number it does not have.
                detail: challenge.hasValue
                    ? l10n.challengeProgress(
                        challenge.requireValue.finishedCount,
                        challenge.requireValue.target,
                      )
                    : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const ReadingChallengePage(),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TrackerCard(
                icon: Icons.donut_large_outlined,
                title: l10n.monthTrackerTitle,
                detail: month.hasValue
                    ? l10n.monthTrackerPagesTotal(month.requireValue.totalPages)
                    : null,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const MonthTrackerPage(),
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

class _TrackerCard extends StatelessWidget {
  const _TrackerCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // 12 dp of padding on a two-line card clears 48 dp comfortably.
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(title, style: theme.textTheme.titleSmall),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _MoreRoute { catalogs, highlights, statistics, settings }

class _MorePlaceholder extends StatelessWidget {
  const _MorePlaceholder();

  void _openRoute(BuildContext context, _MoreRoute route) {
    final l10n = L10n.of(context);

    // The catalogs page carries its own scaffold, app bar and action button.
    // Wrapping it the way the three inherited screens are wrapped would give
    // it two app bars.
    if (route == _MoreRoute.catalogs) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => const OpdsCatalogsPage(),
        ),
      );
      return;
    }

    final (String title, Widget page) = switch (route) {
      _MoreRoute.highlights => (l10n.tileNotesTotalTitle, const NotesPage()),
      _MoreRoute.statistics => (l10n.navBarStatistics, const StatisticPage()),
      _MoreRoute.settings => (l10n.navBarSettings, const SettingsPage()),
      _MoreRoute.catalogs => throw StateError('handled above'),
    };
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    // The owner chose a third destination specifically so nothing would be
    // "hidden behind an icon". A popup menu in the app bar is exactly that, so
    // the three inherited screens are visible rows instead.
    final entries = <(_MoreRoute, IconData, String)>[
      (_MoreRoute.catalogs, Icons.cloud_download_outlined, l10n.opdsCatalogs),
      (
        _MoreRoute.highlights,
        Icons.format_quote_outlined,
        l10n.tileNotesTotalTitle
      ),
      (_MoreRoute.statistics, Icons.insights_outlined, l10n.navBarStatistics),
      (_MoreRoute.settings, Icons.settings_outlined, l10n.navBarSettings),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView(
        // The floating glass bar overlays the content, so the last row needs
        // room to clear it as well as the system gesture inset.
        padding: EdgeInsets.only(
          top: 8,
          bottom: 96 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          for (final (route, icon, label) in entries)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right),
              // ListTile already meets the 48 dp minimum; stated so a later
              // dense: true does not quietly break it.
              minTileHeight: 56,
              onTap: () => _openRoute(context, route),
            ),
        ],
      ),
    );
  }
}

class _DestinationEmptyState extends StatelessWidget {
  const _DestinationEmptyState({
    required this.ornament,
    required this.title,
    required this.body,
  });

  final PaperfoldOrnament ornament;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Ornament(
                  ornament: ornament,
                  width: 128,
                  height: 128,
                  tint: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 28),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
