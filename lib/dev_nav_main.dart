// Development entry point for the top-level navigation decision.
//
// THESIS: Compare three honest navigation structures around one paper journal.
// OWN-WORLD: Paperfold warm surfaces, candlelight dark mode, journal type, and
// tinted floral ornaments; Material 3 owns all chrome.
// STORY: Switch models in seconds, open the same sample journal, and test Back.
// FIRST VIEWPORT: A small lab bar sits above a complete, runnable phone model.
// FORM: Three prescribed prototypes share one runtime and the existing curl.
// FINISH: This is a throwaway decision aid, not a production navigation shell.
//
// This does not start the database, local reader server, or WebView.
//
//   flutter run -t lib/dev_nav_main.dart

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:paperfold/config/paperfold_tokens.dart';
import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/utils/color_scheme.dart';
import 'package:paperfold/utils/ui/status_bar.dart';
import 'package:paperfold/widgets/ornament.dart';
import 'package:paperfold/widgets/page_curl/page_curl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs().initPrefs();
  showStatusBarWithoutResize();
  runApp(const NavigationPrototypeApp());
}

enum _NavigationModel {
  materialShell,
  ribbonBook,
  shelfAndBook,
}

extension on _NavigationModel {
  String get number => switch (this) {
        _NavigationModel.materialShell => '1',
        _NavigationModel.ribbonBook => '2',
        _NavigationModel.shelfAndBook => '3',
      };

  String get title => switch (this) {
        _NavigationModel.materialShell => 'Material shell, paper interior',
        _NavigationModel.ribbonBook => 'One book, ribbon tabs',
        _NavigationModel.shelfAndBook => 'Shelf outside, book inside',
      };
}

class NavigationPrototypeApp extends StatelessWidget {
  const NavigationPrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Paperfold navigation prototype',
      theme: ThemeData(useMaterial3: true),
      home: const _NavigationLab(),
    );
  }
}

class _NavigationLab extends StatefulWidget {
  const _NavigationLab();

  @override
  State<_NavigationLab> createState() => _NavigationLabState();
}

class _NavigationLabState extends State<_NavigationLab> {
  _NavigationModel _model = _NavigationModel.materialShell;
  Brightness _brightness = Brightness.light;

  ThemeData _prototypeTheme(BuildContext context) {
    final ThemeData productionTheme = colorSchema(
      Prefs(),
      context,
      _brightness,
    );
    final ColorScheme scheme = PaperfoldTokens.colorScheme(_brightness);

    return productionTheme.copyWith(
      brightness: _brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: productionTheme.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      primaryTextTheme: productionTheme.primaryTextTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: productionTheme.appBarTheme.copyWith(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surfaceTint,
      ),
      navigationBarTheme: productionTheme.navigationBarTheme.copyWith(
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
      ),
      cardTheme: productionTheme.cardTheme.copyWith(
        color: scheme.surfaceContainerLow,
      ),
      dialogTheme: productionTheme.dialogTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHigh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = _prototypeTheme(context);
    final bool isDark = _brightness == Brightness.dark;

    return Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
        child: Material(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: _PrototypeToolbar(
                  model: _model,
                  brightness: _brightness,
                  onModelChanged: (model) => setState(() => _model = model),
                  onBrightnessChanged: () {
                    setState(() {
                      _brightness = isDark ? Brightness.light : Brightness.dark;
                    });
                  },
                ),
              ),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey((_model, _brightness)),
                  child: switch (_model) {
                    _NavigationModel.materialShell =>
                      const _MaterialShellModel(),
                    _NavigationModel.ribbonBook => const _RibbonBookModel(),
                    _NavigationModel.shelfAndBook => const _ShelfAndBookModel(),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrototypeToolbar extends StatelessWidget {
  const _PrototypeToolbar({
    required this.model,
    required this.brightness,
    required this.onModelChanged,
    required this.onBrightnessChanged,
  });

  final _NavigationModel model;
  final Brightness brightness;
  final ValueChanged<_NavigationModel> onModelChanged;
  final VoidCallback onBrightnessChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Text('Nav lab', style: theme.textTheme.labelLarge),
            const Spacer(),
            for (final _NavigationModel option in _NavigationModel.values) ...[
              Tooltip(
                message: 'Model ${option.number}: ${option.title}',
                child: SizedBox.square(
                  dimension: 48,
                  child: option == model
                      ? FilledButton(
                          onPressed: () => onModelChanged(option),
                          style: _squareButtonStyle(),
                          child: Text(option.number),
                        )
                      : OutlinedButton(
                          onPressed: () => onModelChanged(option),
                          style: _squareButtonStyle(),
                          child: Text(option.number),
                        ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton.filledTonal(
              tooltip: brightness == Brightness.dark
                  ? 'Inspect daylight theme'
                  : 'Inspect candlelight theme',
              onPressed: onBrightnessChanged,
              icon: Icon(
                brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ButtonStyle _squareButtonStyle() {
  return const ButtonStyle(
    padding: WidgetStatePropertyAll(EdgeInsets.zero),
    minimumSize: WidgetStatePropertyAll(Size(48, 48)),
    tapTargetSize: MaterialTapTargetSize.padded,
  );
}

class _ModelLabel extends StatelessWidget {
  const _ModelLabel(this.model);

  final _NavigationModel model;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.account_tree_outlined,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'MODEL ${model.number} · ${model.title.toUpperCase()}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MaterialShellModel extends StatefulWidget {
  const _MaterialShellModel();

  @override
  State<_MaterialShellModel> createState() => _MaterialShellModelState();
}

class _MaterialShellModelState extends State<_MaterialShellModel> {
  int _destination = 0;
  int _page = 0;
  List<int> _destinationHistory = [0];
  GlobalKey<_CurlBookState> _curlKey = GlobalKey<_CurlBookState>();

  static const List<String> _titles = [
    'Library',
    'Journal',
    'Log',
    'Settings',
  ];

  void _selectDestination(int destination) {
    if (destination == _destination) return;
    setState(() {
      _destination = destination;
      _page = 0;
      _destinationHistory = [..._destinationHistory, destination];
      _curlKey = GlobalKey<_CurlBookState>();
    });
  }

  void _handleBack(bool didPop, Object? result) {
    if (didPop || _destinationHistory.length <= 1) return;
    setState(() {
      _destinationHistory = _destinationHistory.sublist(
        0,
        _destinationHistory.length - 1,
      );
      _destination = _destinationHistory.last;
      _page = 0;
      _curlKey = GlobalKey<_CurlBookState>();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = _materialShellPages(_destination);

    return PopScope<Object?>(
      canPop: _destinationHistory.length <= 1,
      onPopInvokedWithResult: _handleBack,
      child: Scaffold(
        appBar: AppBar(title: Text(_titles[_destination])),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ModelLabel(_NavigationModel.materialShell),
                const SizedBox(height: 12),
                Expanded(
                  child: _CurlBook(
                    key: _curlKey,
                    pages: pages,
                    onIndexChanged: (index) => setState(() => _page = index),
                  ),
                ),
                const SizedBox(height: 8),
                _PageControls(
                  current: _page,
                  count: pages.length,
                  onPrevious: () => _curlKey.currentState?.turnTo(
                    (_page - 1 + pages.length) % pages.length,
                  ),
                  onNext: () => _curlKey.currentState?.turnTo(
                    (_page + 1) % pages.length,
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _destination,
          onDestinationSelected: _selectDestination,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.local_library_outlined),
              selectedIcon: Icon(Icons.local_library),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Journal',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt),
              label: 'Log',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _materialShellPages(int destination) {
  return switch (destination) {
    0 => const [
        _LibraryPaperPage(),
        _ReviewPaperPage(modelNumber: 1),
      ],
    1 => const [
        _ReviewPaperPage(modelNumber: 1),
        _WrittenEntryPage(),
      ],
    2 => const [
        _ReadingLogPaperPage(),
        _WrittenEntryPage(),
      ],
    _ => const [
        _PaperSettingsPage(),
        _ReviewPaperPage(modelNumber: 1),
      ],
  };
}

class _RibbonBookModel extends StatefulWidget {
  const _RibbonBookModel();

  @override
  State<_RibbonBookModel> createState() => _RibbonBookModelState();
}

class _RibbonBookModelState extends State<_RibbonBookModel> {
  final GlobalKey<_CurlBookState> _curlKey = GlobalKey<_CurlBookState>();
  final List<int> _history = [0];
  int _section = 0;
  bool _returningWithBack = false;

  static const List<({String label, IconData icon})> _sections = [
    (label: 'Library', icon: Icons.local_library_outlined),
    (label: 'Journal', icon: Icons.menu_book_outlined),
    (label: 'Log', icon: Icons.list_alt_outlined),
    (label: 'Settings', icon: Icons.settings_outlined),
  ];

  Future<void> _goTo(int section, {bool fromBack = false}) async {
    if (section == _section) return;
    _returningWithBack = fromBack;
    if (!fromBack) {
      _history.add(section);
    }
    await _curlKey.currentState?.turnTo(section);
    _returningWithBack = false;
  }

  void _onSectionChanged(int section) {
    setState(() => _section = section);
  }

  void _handleBack(bool didPop, Object? result) {
    if (didPop || _history.length <= 1 || _returningWithBack) return;
    _history.removeLast();
    unawaited(_goTo(_history.last, fromBack: true));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return PopScope<Object?>(
      canPop: _history.length <= 1,
      onPopInvokedWithResult: _handleBack,
      child: Scaffold(
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Stack(
              children: [
                Positioned.fill(
                  right: 52,
                  child: _CurlBook(
                    key: _curlKey,
                    pages: const [
                      _RibbonSectionPage(child: _LibraryPaperPage()),
                      _RibbonSectionPage(
                        child: _ReviewPaperPage(modelNumber: 2),
                      ),
                      _RibbonSectionPage(child: _ReadingLogPaperPage()),
                      _RibbonSectionPage(child: _PaperSettingsPage()),
                    ],
                    interactive: false,
                    onIndexChanged: _onSectionChanged,
                  ),
                ),
                Positioned(
                  top: 72,
                  right: 0,
                  child: Column(
                    children: [
                      for (int index = 0;
                          index < _sections.length;
                          index++) ...[
                        _RibbonTab(
                          label: _sections[index].label,
                          icon: _sections[index].icon,
                          selected: index == _section,
                          onTap: () => _goTo(index),
                        ),
                        if (index < _sections.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 68,
                  bottom: 16,
                  child: Material(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'System Back retraces visited ribbons. At Library, '
                        'Back exits the prototype.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
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

class _RibbonSectionPage extends StatelessWidget {
  const _RibbonSectionPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: _ModelLabel(_NavigationModel.ribbonBook),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RibbonTab extends StatelessWidget {
  const _RibbonTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 52,
            height: 56,
            child: Icon(
              icon,
              color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShelfAndBookModel extends StatelessWidget {
  const _ShelfAndBookModel();

  void _openBook(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Theme(
          data: theme,
          child: const _FullScreenBook(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            tooltip: 'Search library',
            onPressed: () {},
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const _ModelLabel(_NavigationModel.shelfAndBook),
            const SizedBox(height: 20),
            Text('Reading now', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            _ShelfBookRow(
              title: 'The Cartographer’s Garden',
              author: 'Mara Venn',
              status: 'Review and journal pages ready',
              onTap: () => _openBook(context),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _ShelfBookRow(
              title: 'Salt in the Lantern',
              author: 'Ivo Marr',
              status: 'Reading',
              onTap: () {},
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            _ShelfBookRow(
              title: 'A House of Small Weather',
              author: 'Nell Arden',
              status: 'Finished',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfBookRow extends StatelessWidget {
  const _ShelfBookRow({
    required this.title,
    required this.author,
    required this.status,
    required this.onTap,
  });

  final String title;
  final String author;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 112),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const SizedBox(
                width: 68,
                height: 96,
                child: _MiniBookCover(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      author,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(status, style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullScreenBook extends StatefulWidget {
  const _FullScreenBook();

  @override
  State<_FullScreenBook> createState() => _FullScreenBookState();
}

class _FullScreenBookState extends State<_FullScreenBook> {
  final GlobalKey<_CurlBookState> _curlKey = GlobalKey<_CurlBookState>();
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    const List<Widget> pages = [
      _ReviewPaperPage(modelNumber: 3),
      _WrittenEntryPage(),
      _DotJournalPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('The Cartographer’s Garden'),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              const _ModelLabel(_NavigationModel.shelfAndBook),
              const SizedBox(height: 12),
              Expanded(
                child: _CurlBook(
                  key: _curlKey,
                  pages: pages,
                  onIndexChanged: (index) => setState(() => _page = index),
                ),
              ),
              const SizedBox(height: 8),
              _PageControls(
                current: _page,
                count: pages.length,
                onPrevious: () => _curlKey.currentState?.turnTo(
                  (_page - 1 + pages.length) % pages.length,
                ),
                onNext: () => _curlKey.currentState?.turnTo(
                  (_page + 1) % pages.length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurlBook extends StatefulWidget {
  const _CurlBook({
    super.key,
    required this.pages,
    required this.onIndexChanged,
    this.interactive = true,
  });

  final List<Widget> pages;
  final ValueChanged<int> onIndexChanged;
  final bool interactive;

  @override
  State<_CurlBook> createState() => _CurlBookState();
}

class _CurlBookState extends State<_CurlBook> {
  final PageCurlController _controller = PageCurlController();
  int _current = 0;
  int _target = 1;
  bool _turning = false;

  Future<void> turnTo(int index) async {
    if (_turning ||
        index == _current ||
        index < 0 ||
        index >= widget.pages.length) {
      return;
    }
    setState(() {
      _turning = true;
      _target = index;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    _controller.jumpTo(0);
    await _controller.animate(
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleSettled(bool completed) {
    if (!mounted) return;
    if (!completed) {
      setState(() => _turning = false);
      return;
    }

    final int next = _target;
    _controller.jumpTo(0);
    setState(() {
      _current = next;
      _target = (_current + 1) % widget.pages.length;
      _turning = false;
    });
    widget.onIndexChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: WidgetPageCurl(
          controller: _controller,
          front: widget.pages[_current],
          back: widget.pages[_target],
          textDirection: Directionality.of(context),
          interactive: widget.interactive && !_turning,
          reduceMotion: reduceMotion,
          onSettled: _handleSettled,
        ),
      ),
    );
  }
}

class _PageControls extends StatelessWidget {
  const _PageControls({
    required this.current,
    required this.count,
    required this.onPrevious,
    required this.onNext,
  });

  final int current;
  final int count;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton.outlined(
          tooltip: 'Previous page',
          onPressed: onPrevious,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 16),
        Text('${current + 1} of $count'),
        const SizedBox(width: 16),
        IconButton.filled(
          tooltip: 'Turn page',
          onPressed: onNext,
          icon: const Icon(Icons.arrow_forward),
        ),
      ],
    );
  }
}

class _PaperSheet extends StatelessWidget {
  const _PaperSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: IgnorePointer(
                child: Ornament(
                  ornament: PaperfoldOrnament.rectangularVineFrame,
                  tint: scheme.primary.withValues(alpha: 0.32),
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(30, 32, 30, 36),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewPaperPage extends StatelessWidget {
  const _ReviewPaperPage({required this.modelNumber});

  final int modelNumber;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return _PaperSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Book review', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'THE CARTOGRAPHER’S GARDEN',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text('Mara Venn', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          const _RatingRow(),
          const SizedBox(height: 24),
          Text('Favourite quote', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '“Maps do not show where we are lost; they show where we '
                  'began looking.”',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('What stayed with me', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'The garden is less a puzzle than a record of care. Every path '
            'changes because somebody walked it, neglected it, or returned.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'The quiet final chapter earns its hope. It does not erase the '
            'years before it.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Text(
            'Prototype page · Model $modelNumber',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: [
        for (int index = 0; index < 5; index++) ...[
          Icon(
            index < 4 ? Icons.star : Icons.star_outline,
            color: theme.colorScheme.primary,
            size: 22,
          ),
          if (index < 4) const SizedBox(width: 4),
        ],
        const SizedBox(width: 12),
        Text('4 of 5', style: theme.textTheme.labelLarge),
      ],
    );
  }
}

class _WrittenEntryPage extends StatelessWidget {
  const _WrittenEntryPage();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return _PaperSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('After the last page', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '11 AUGUST',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'I kept thinking about the map folded into the greenhouse wall. '
            'At first it looked like a solution. By the end it felt more like '
            'an invitation to pay attention.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'Venn lets each clue arrive through work: pruning, copying names, '
            'walking the boundary after rain. That patience is the book’s real '
            'mystery.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Text(
            'I would read it again in winter, when the green parts feel '
            'furthest away.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Icon(Icons.bookmark_outline, color: scheme.primary),
              const SizedBox(width: 8),
              Text('Kept for later', style: theme.textTheme.labelLarge),
            ],
          ),
        ],
      ),
    );
  }
}

class _LibraryPaperPage extends StatelessWidget {
  const _LibraryPaperPage();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _PaperSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('My library', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 20),
          const _PaperBookLine(
            title: 'The Cartographer’s Garden',
            author: 'Mara Venn',
            icon: Icons.auto_stories,
          ),
          const SizedBox(height: 16),
          const _PaperBookLine(
            title: 'Salt in the Lantern',
            author: 'Ivo Marr',
            icon: Icons.menu_book_outlined,
          ),
          const SizedBox(height: 16),
          const _PaperBookLine(
            title: 'A House of Small Weather',
            author: 'Nell Arden',
            icon: Icons.book_outlined,
          ),
        ],
      ),
    );
  }
}

class _PaperBookLine extends StatelessWidget {
  const _PaperBookLine({
    required this.title,
    required this.author,
    required this.icon,
  });

  final String title;
  final String author;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: [
        SizedBox.square(
          dimension: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              Text(author, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReadingLogPaperPage extends StatelessWidget {
  const _ReadingLogPaperPage();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _PaperSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reading log', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 20),
          const _LogLine(
            date: '11 Aug',
            title: 'The Cartographer’s Garden',
            rating: 4,
          ),
          const Divider(height: 32),
          const _LogLine(
            date: '29 Jul',
            title: 'A House of Small Weather',
            rating: 5,
          ),
          const Divider(height: 32),
          const _LogLine(
            date: '18 Jul',
            title: 'Salt in the Lantern',
            rating: 3,
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({
    required this.date,
    required this.title,
    required this.rating,
  });

  final String date;
  final String title;
  final int rating;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: 56, child: Text(date, style: theme.textTheme.labelLarge)),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 4),
            Text('$rating'),
          ],
        ),
      ],
    );
  }
}

class _PaperSettingsPage extends StatelessWidget {
  const _PaperSettingsPage();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _PaperSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Book settings', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 20),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.dark_mode_outlined),
            title: Text('Candlelight theme'),
            subtitle: Text('Use the lab control above to inspect it.'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.animation_outlined),
            title: Text('Page motion'),
            subtitle: Text('Follows the system animation setting.'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.text_fields),
            title: Text('Text size'),
            subtitle: Text('Follows the Android text scale.'),
          ),
        ],
      ),
    );
  }
}

class _DotJournalPage extends StatelessWidget {
  const _DotJournalPage();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: CustomPaint(
        painter: _DotPaperPainter(scheme.outlineVariant),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 32, 30, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notes', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'A free page after the review',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Ornament(
                  ornament: PaperfoldOrnament.cornerSpray,
                  tint: scheme.primary.withValues(alpha: 0.6),
                  width: 104,
                  height: 104,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DotPaperPainter extends CustomPainter {
  const _DotPaperPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.46)
      ..strokeWidth = 1;
    const double spacing = 20;
    for (double y = 72; y < size.height - 28; y += spacing) {
      for (double x = 30; x < size.width - 28; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPaperPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MiniBookCover extends StatelessWidget {
  const _MiniBookCover();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PaperfoldTokens.cover.ground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Ornament(
          ornament: PaperfoldOrnament.circularWreath,
          tint: PaperfoldTokens.cover.foil,
        ),
      ),
    );
  }
}
