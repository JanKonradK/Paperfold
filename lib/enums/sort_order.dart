import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:material_ui/material_ui.dart';

enum SortOrderEnum {
  ascending,
  descending,
}

extension SortOrderExtension on SortOrderEnum {
  String getL10n(BuildContext context) {
    return switch (this) {
      SortOrderEnum.ascending => L10n.of(context).commonAscending,
      SortOrderEnum.descending => L10n.of(context).commonDescending,
    };
  }
}
