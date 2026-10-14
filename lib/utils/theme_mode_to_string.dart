import 'package:material_ui/material_ui.dart';

String themeModeToString(ThemeMode themeMode) {
  switch (themeMode) {
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.light:
      return 'light';
    case ThemeMode.system:
      return 'auto';
  }
}
