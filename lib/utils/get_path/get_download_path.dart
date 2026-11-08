import 'package:permission_handler/permission_handler.dart';

Future<String> getDownloadPath() async {
  if (!await Permission.manageExternalStorage.isGranted) {
    await Permission.manageExternalStorage.request();
  }
  return '/storage/emulated/0/Download';
}
