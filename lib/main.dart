import 'package:paperfold/config/paperfold_motion.dart';

import 'dart:async';
import 'dart:io';

import 'package:paperfold/service/capture_launch.dart';

import 'package:paperfold/config/paperfold_visual_policy.dart';

import 'package:paperfold/config/shared_preference_provider.dart';
import 'package:paperfold/dao/database.dart';
import 'package:paperfold/enums/sync_direction.dart';
import 'package:paperfold/enums/sync_trigger.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/page/home_page.dart';
import 'package:paperfold/page/opening/opening_sequence.dart';
import 'package:paperfold/service/book_player/book_player_server.dart';
import 'package:paperfold/service/network/http_proxy_overrides.dart';
import 'package:paperfold/utils/color_scheme.dart';
import 'package:paperfold/widgets/paperfold_library_theme.dart';
import 'package:paperfold/utils/error/common.dart';
import 'package:paperfold/utils/get_path/get_base_path.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/providers/sync.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:heroine/heroine.dart';
import 'package:provider/provider.dart' as provider;

final navigatorKey = GlobalKey<NavigatorState>();
final heroineController = HeroineController();

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
  unawaited(CaptureLaunch.initialize());
  PaperfoldVisualPolicy.init();
  HttpOverrides.global = AnxHttpProxyOverrides();

  // Start storage, the database, and the local reader server without waiting
  // for them before runApp. HomePage and all DAOs join databaseReady.
  final databaseReady = _startDataServices();

  _coldStartOpeningPending = Prefs().openBookAnimation;

  SmartDialog.config.custom = SmartConfigCustom(
    maskColor: Colors.black.withAlpha(35),
    useAnimation: true,
    animationType: SmartAnimationType.centerFade_otherSlide,
  );

  runApp(
    ProviderScope(
      // Failed operations use the app's visible Retry actions.
      retry: (_, _) => null,
      child: MyApp(databaseReady: databaseReady),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key, required this.databaseReady});

  final Future<void> databaseReady;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp>
    with WidgetsBindingObserver {
  static const Locale _englishFallbackLocale = Locale('en');
  late final bool _playColdStartOpening;
  late final Completer<void> _openingFinished;

  @override
  void initState() {
    super.initState();
    CaptureLaunch.observe(ref);
    _playColdStartOpening = _takeColdStartOpening();
    _openingFinished = Completer<void>();
    if (!_playColdStartOpening) {
      _openingFinished.complete();
    }
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final homePage = HomePage(
      databaseReady: widget.databaseReady,
      startupRevealReady: _openingFinished.future,
    );
    final home = _playColdStartOpening
        ? OpeningSequence(onFinished: _handleOpeningFinished, child: homePage)
        : homePage;

    return provider.MultiProvider(
      providers: [provider.ChangeNotifierProvider(create: (_) => Prefs())],
      child: provider.Consumer<Prefs>(
        builder: (context, prefsNotifier, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            themeAnimationDuration:
                prefsNotifier.eInkMode ||
                    WidgetsBinding
                        .instance
                        .platformDispatcher
                        .accessibilityFeatures
                        .disableAnimations
                ? Duration.zero
                : PaperfoldMotion.move,
            themeAnimationCurve: PaperfoldMotion.settle,
            scrollBehavior: ScrollConfiguration.of(context).copyWith(
              physics: const BouncingScrollPhysics(),
              // dragDevices: {
              //   PointerDeviceKind.touch,
              //   PointerDeviceKind.mouse,
              // },
            ),
            navigatorObservers: [
              FlutterSmartDialog.observer,
              heroineController,
            ],
            builder: FlutterSmartDialog.init(
              builder: (context, child) =>
                  MaterialUiCompatibilityBridge(child: child!),
            ),
            navigatorKey: navigatorKey,
            locale: prefsNotifier.locale,
            localeListResolutionCallback: _resolveLocale,
            localizationsDelegates: [
              L10n.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: L10n.supportedLocales,
            title: 'Paperfold',
            themeMode: prefsNotifier.themeMode,
            theme: paperfoldLibraryTheme(
              colorSchema(prefsNotifier, context, Brightness.light),
            ),
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
