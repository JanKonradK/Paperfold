import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:paperfold/utils/platform_utils.dart';

TextSelectionControls selectionControls() {
  switch (AnxPlatform.type) {
    case AnxPlatformEnum.ios:
    case AnxPlatformEnum.macos:
      return CupertinoTextSelectionControls();
    case AnxPlatformEnum.android:
    case AnxPlatformEnum.ohos:
    case AnxPlatformEnum.windows:
      return MaterialTextSelectionControls();
  }
}
