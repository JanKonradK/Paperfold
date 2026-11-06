import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paperfold/l10n/generated/L10n.dart';
Widget journalTestHost(Widget child, {double keyboard = 0, double textScale = 1}) => ProviderScope(child: MaterialApp(
  localizationsDelegates: [L10n.delegate, ...GlobalMaterialLocalizations.delegates],
  supportedLocales: L10n.supportedLocales, locale: const Locale('en'),
  home: MediaQuery(data: MediaQueryData(size: const Size(800, 600), viewInsets: EdgeInsets.only(bottom: keyboard), textScaler: TextScaler.linear(textScale)), child: Scaffold(body: child))));
