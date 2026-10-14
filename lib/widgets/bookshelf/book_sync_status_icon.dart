import 'package:paperfold/enums/book_sync_status.dart';
import 'package:paperfold/widgets/bookshelf/spining_sync_icon.dart';
import 'package:material_ui/material_ui.dart';

class BookSyncStatusIcon extends StatelessWidget {
  const BookSyncStatusIcon({
    super.key,
    required this.syncStatus,
    this.iconSize = 16,
  });

  final BookSyncStatusEnum syncStatus;
  final double iconSize;

  Color get color {
    switch (syncStatus) {
      case BookSyncStatusEnum.localOnly:
        return Colors.orangeAccent;
      case BookSyncStatusEnum.remoteOnly:
        return Colors.grey;
      case BookSyncStatusEnum.both:
        return Colors.green;
      case BookSyncStatusEnum.nonExistent:
        return Colors.red;
      case BookSyncStatusEnum.downloading:
        return Colors.blue;
      case BookSyncStatusEnum.uploading:
        return Colors.blue;
      case BookSyncStatusEnum.checking:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = switch (syncStatus) {
      BookSyncStatusEnum.localOnly => Stack(
          children: [
            Center(
              child: Icon(
                Icons.cloud_outlined,
                color: color,
                size: iconSize,
              ),
            ),
            Center(
              child: Icon(
                Icons.close,
                color: color,
                size: iconSize * 0.7,
              ),
            ),
          ],
        ),
      BookSyncStatusEnum.remoteOnly => Stack(
          children: [
            Center(
              child: Icon(
                Icons.cloud_outlined,
                color: color,
                size: iconSize,
              ),
            ),
            Center(
              child: Icon(
                Icons.sync,
                color: color,
                size: iconSize * 0.5,
              ),
            ),
          ],
        ),
      BookSyncStatusEnum.both => Icon(
          Icons.cloud_done_outlined,
          color: color,
          size: iconSize,
        ),
      BookSyncStatusEnum.nonExistent => Icon(
          Icons.cancel_outlined,
          color: color,
          size: iconSize * 0.8,
        ),
      BookSyncStatusEnum.downloading => Stack(
          children: [
            Center(
              child: SpiningSyncIcon(
                size: iconSize,
                color: color,
              ),
            ),
            Center(
              child: Icon(
                Icons.arrow_downward,
                color: color,
                size: iconSize * 0.7,
              ),
            ),
          ],
        ),
      BookSyncStatusEnum.uploading => Stack(
          children: [
            Center(
              child: SpiningSyncIcon(
                size: iconSize,
                color: color,
              ),
            ),
            Center(
              child: Icon(
                Icons.arrow_upward,
                color: color,
                size: iconSize * 0.7,
              ),
            ),
          ],
        ),
      BookSyncStatusEnum.checking => CircularProgressIndicator.adaptive(
          strokeWidth: 2,
        ),
    };
    return SizedBox(
      width: iconSize,
      height: iconSize,
      child: child,
    );
  }
}
