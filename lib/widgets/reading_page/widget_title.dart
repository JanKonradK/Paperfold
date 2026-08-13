import 'package:paperfold/widgets/reading_page/more_settings/more_settings.dart';
import 'package:flutter/material.dart';

/// The heading of a reader panel, with the panel's own settings beside it.
///
/// The heading takes the Material title role rather than a size fixed here, so
/// it follows the system text scale and speaks in Paperfold's content face.
Widget widgetTitle(
  BuildContext context,
  String title,
  ReadingSettings? settings,
) {
  return Padding(
    padding: const EdgeInsetsDirectional.only(top: 4, bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (settings != null)
          IconButton(
            tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
            onPressed: () => showMoreSettings(settings),
            icon: const Icon(Icons.tune),
          ),
      ],
    ),
  );
}
