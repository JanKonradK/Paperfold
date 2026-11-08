import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/widgets/reading_page/more_settings/page_turning/diagram.dart';
import 'package:material_ui/material_ui.dart';

class PageTurnDropdown extends StatelessWidget {
  const PageTurnDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final PageTurningType value;
  final ValueChanged<PageTurningType?> onChanged;

  String _getLabel(BuildContext context, PageTurningType type) {
    switch (type) {
      case PageTurningType.none:
        return L10n.of(context).pageTurnActionNone;
      case PageTurningType.prev:
        return L10n.of(context).pageTurnActionPrev;
      case PageTurningType.next:
        return L10n.of(context).pageTurnActionNext;
      case PageTurningType.menu:
        return L10n.of(context).pageTurnActionMenu;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButton<PageTurningType>(
      isDense: true,
      isExpanded: true,
      underline: const SizedBox.shrink(),
      value: value,
      items: [
        for (final type in PageTurningType.values)
          DropdownMenuItem(
            value: type,
            child: Text(
              _getLabel(context, type),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
