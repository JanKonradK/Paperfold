import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:material_ui/material_ui.dart';

enum SortFieldEnum {
  title,
  author,
  lastReadTime,
  progress,
  importTime,
}

extension SortFieldExtension on SortFieldEnum {
  String getL10n(BuildContext context) {
    return switch (this) {
      SortFieldEnum.title => L10n.of(context).bookshelfTitle,
      SortFieldEnum.author => L10n.of(context).bookshelfAuthor,
      SortFieldEnum.lastReadTime => L10n.of(context).bookshelfLastReadTime,
      SortFieldEnum.progress => L10n.of(context).bookshelfProgress,
      SortFieldEnum.importTime => L10n.of(context).bookshelfImportTime,
    };
  }
}
