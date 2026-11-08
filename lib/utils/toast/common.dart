import 'package:paperfold/main.dart';
import 'package:paperfold/widgets/common/container/filled_container.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class AnxToast {
  static void show(String message, {Icon? icon, int duration = 2000}) {
    Widget toast = FilledContainer(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon ?? const Icon(Icons.info_outline),
          const SizedBox(
            width: 12.0,
          ),
          Flexible(
            child: Text(
              message,
              // wrap
              style: TextStyle(
                color: Theme.of(navigatorKey.currentContext!)
                    .colorScheme
                    .onSurface,
              ),
            ),
          ),
        ],
      ),
    );

    // A new toast replaces the one on screen.
    SmartDialog.showToast(
      message,
      // fluttertoast's old bottom gap, clear of the navigation bar.
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 50),
          child: toast,
        ),
      ),
      alignment: Alignment.bottomCenter,
      displayType: SmartToastType.last,
      displayTime: Duration(milliseconds: duration),
    );
  }
}
