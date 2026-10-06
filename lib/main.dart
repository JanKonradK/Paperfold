import 'dart:async';
import 'dart:io';

import 'package:paperfold/utils/platform_utils.dart';

import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/enums/sync_direction.dart';
import 'package:paperfold/enums/sync_trigger.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/models/window_info.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/page/migration_page.dart';
import 'package:paperfold/page/opening/opening_sequence.dart';
import 'package:paperfold/service/book_player/book_player_server.dart';
import 'package:paperfold/service/network/http_proxy_overrides.dart';
import 'package:paperfold/utils/get_path/macos_migration.dart';
import 'package:paperfold/utils/color_scheme.dart';
import 'package:paperfold/utils/error/common.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/get_path/storage_migration.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/window_position_validator.dart';
import 'package:paperfold/providers/sync.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:heroine/heroine.dart';
import 'package:provider/provider.dart' as provider;
import 'package:window_manager/window_manager.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final heroineController = HeroineController();

/// Whether macOS data migration is needed (checked at startup)
bool _needsMigration = false;
bool _storageMigrationFailed = false;
MigrationCheckResult? _migrationCheckResult;

/// This process-level flag is set once in [main] and consumed once by MyApp.
/// Widget rebuilds, configuration changes, and lifecycle resumes cannot reset
/// it, so the opening sequence is cold-start-only.
bool _coldStartOpeningPending = false;

bool _takeColdStartOpening() {
  final shouldPlay = _coldStartOpeningPending;
  _coldStartOpeningPending = false;
  return shouldPlay;
}

Future<void> _initializeStorage() async {
  if (AnxPlatform.isWindows) {
    _storageMigrationFailed = !await applyPendingStorageMigration();
  }
  await initBasePath();
  await AnxLog.init();
  AnxError.init();
}

Future<void> _startServerAfter(Future<void> storageReady) async {
  await storageReady;
  await Server().start();
}

Future<void> _startDataServices() async {
  final storageReady = _initializeStorage();
  final databaseReady = DBHelper().initDB(after: storageReady);
  await Future.wait([databaseReady, _startServerAfter(storageReady)]);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs().initPrefs();
  HttpOverrides.global = AnxHttpProxyOverrides();

  // Initialize desktop window with validated position
  if (AnxPlatform.isWindows || AnxPlatform.isMacOS) {
    await initializeDesktopWindow();
  }

  // Check if migration is needed before initializing paths
  if (AnxPlatform.isMacOS) {
    _migrationCheckResult = await checkMigrationNeeded();
    _needsMigration = _migrationCheckResult?.needsMigration ?? false;
  }

  Future<void>? databaseReady;

  // Start storage, the database, and the local reader server without waiting
  // for them before runApp. HomePage and all DAOs join databaseReady.
  if (!_needsMigration) {
    databaseReady = _startDataServices();
  }

  _coldStartOpeningPending = !_needsMigration && Prefs().openBookAnimation;

  SmartDialog.config.custom = SmartConfigCustom(
    maskColor: Colors.black.withAlpha(35),
    useAnimation: true,
    animationType: SmartAnimationType.centerFade_otherSlide,
  );

  runApp(
    ProviderScope(
      child: MyApp(databaseReady: databaseReady),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, required this.databaseReady});

  final Future<void>? databaseReady;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp>
    with WidgetsBindingObserver, WindowListener {
  static const Locale _englishFallbackLocale = Locale('en');
  late final bool _playColdStartOpening;
  late final Completer<void> _openingFinished;

  @override
  void initState() {
    super.initState();
    _playColdStartOpening = _takeColdStartOpening();
    _openingFinished = Completer<void>();
    if (!_playColdStartOpening) {
      _openingFinished.complete();
    }
    WidgetsBinding.instance.addObserver(this);
    windowManager.addListener(this);
    _showStorageMigrationFailure();
  }

  Future<void> _showStorageMigrationFailure() async {
    try {
      await widget.databaseReady;
      await _openingFinished.future;
      if (!mounted || !_storageMigrationFailed) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey.currentContext;
        if (!mounted || context == null) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L10n.of(context).storageMigrationFailed),
        ));
      });
    } catch (_) {
      // HomePage shows the startup failure and restart guidance.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    await Server().stop();
    await webViewEnvironment?.dispose();
    webViewEnvironment = null;
    await DBHelper.close();
    await windowManager.destroy();
  }

  @override
  Future<void> onWindowMoved() async {
    await _updateWindowInfo();
  }

  @override
  Future<void> onWindowMaximize() async {
    await _updateWindowInfo();
  }

  @override
  Future<void> onWindowUnmaximize() async {
    await _updateWindowInfo();
  }

  @override
  Future<void> onWindowResized() async {
    await _updateWindowInfo();
  }

  Future<void> _updateWindowInfo() async {
    if (!AnxPlatform.isWindows && !AnxPlatform.isMacOS) {
      return;
    }
    final windowOffset = await windowManager.getPosition();
    final windowSize = await windowManager.getSize();
    final isMaximized = await windowManager.isMaximized();

    Prefs().windowInfo = WindowInfo(
        x: windowOffset.dx,
        y: windowOffset.dy,
        width: windowSize.width,
        height: windowSize.height,
        isMaximized: isMaximized);
    AnxLog.info('onWindowClose: Offset: $windowOffset, Size: $windowSize');
  }

  void _handleOpeningFinished() {
    if (!_openingFinished.isCompleted) {
      _openingFinished.complete();
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (Prefs().webdavStatus) {
        ref
            .read(syncProvider.notifier)
            .syncData(SyncDirection.both, ref, trigger: SyncTrigger.auto);
      }
    } else if (state == AppLifecycleState.resumed) {
      if (AnxPlatform.isIOS) {
        Server().start();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final databaseReady = widget.databaseReady;
    final Widget home;
    if (_needsMigration) {
      home = _MigrationWrapper(
        migrationCheckResult: _migrationCheckResult!,
      );
    } else {
      assert(databaseReady != null);
      final homePage = HomePage(
        databaseReady: databaseReady!,
        startupRevealReady: _openingFinished.future,
      );
      home = _playColdStartOpening
          ? OpeningSequence(
              onFinished: _handleOpeningFinished,
              child: homePage,
            )
          : homePage;
    }

    return provider.MultiProvider(
      providers: [
        provider.ChangeNotifierProvider(
          create: (_) => Prefs(),
        ),
      ],
      child: provider.Consumer<Prefs>(
        builder: (context, prefsNotifier, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            scrollBehavior: ScrollConfiguration.of(context).copyWith(
              physics: const BouncingScrollPhysics(),
              // dragDevices: {
              //   PointerDeviceKind.touch,
              //   PointerDeviceKind.mouse,
              // },
            ),
            navigatorObservers: [
              FlutterSmartDialog.observer,
              heroineController
            ],
            builder: FlutterSmartDialog.init(),
            navigatorKey: navigatorKey,
            locale: prefsNotifier.locale,
            localeListResolutionCallback: _resolveLocale,
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            title: 'Paperfold',
            themeMode: prefsNotifier.themeMode,
            theme: colorSchema(prefsNotifier, context, Brightness.light),
            darkTheme: colorSchema(prefsNotifier, context, Brightness.dark),
            home: home,
          );
        },
      ),
    );
  }

  Locale _resolveLocale(
    List<Locale>? preferredLocales,
    Iterable<Locale> supportedLocales,
  ) {
    if (preferredLocales == null || preferredLocales.isEmpty) {
      return _englishFallbackLocale;
    }

    final Locale resolvedLocale = basicLocaleListResolution(
      preferredLocales,
      supportedLocales,
    );

    final bool hasMatch = preferredLocales.any((Locale preferredLocale) {
      return supportedLocales.any((Locale supportedLocale) {
        if (preferredLocale.languageCode != supportedLocale.languageCode) {
          return false;
        }

        final String? preferredCountryCode = preferredLocale.countryCode;
        final String? supportedCountryCode = supportedLocale.countryCode;

        return preferredCountryCode == null ||
            supportedCountryCode == null ||
            preferredCountryCode == supportedCountryCode;
      });
    });

    return hasMatch ? resolvedLocale : _englishFallbackLocale;
  }
}

/// Widget that wraps the migration flow on macOS.
/// Shows MigrationPage during migration, then navigates to HomePage.
class _MigrationWrapper extends StatefulWidget {
  final MigrationCheckResult migrationCheckResult;

  const _MigrationWrapper({required this.migrationCheckResult});

  @override
  State<_MigrationWrapper> createState() => _MigrationWrapperState();
}

class _MigrationWrapperState extends State<_MigrationWrapper> {
  bool _migrationComplete = false;

  Future<void> _onMigrationComplete() async {
    await _startDataServices();

    if (mounted) {
      setState(() {
        _migrationComplete = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_migrationComplete) {
      return HomePage(databaseReady: DBHelper().database);
    }
    return MigrationPage(
      checkResult: widget.migrationCheckResult,
      onMigrationComplete: _onMigrationComplete,
    );
  }
}
