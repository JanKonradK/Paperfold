import 'package:paperfold/l10n/generated/L10n.dart';
import 'package:paperfold/main.dart';
import 'package:paperfold/utils/log/common.dart';
import 'package:paperfold/utils/toast/common.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';

class SaveImg {
  static Future<bool> requestStoragePer() async {
    await Permission.storage.request();
    PermissionStatus status = await Permission.storage.status;
    if (status == PermissionStatus.denied ||
        status == PermissionStatus.permanentlyDenied) {
      SmartDialog.show(
        useSystem: true,
        animationType: SmartAnimationType.centerFade_otherSlide,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(L10n.of(context).storagePermissionDenied),
            content: Text(L10n.of(context).storagePermissionDenied),
            actions: [
              TextButton(
                onPressed: () async {
                  openAppSettings();
                },
                child: Text(L10n.of(context).gotoAuthorize),
              )
            ],
          );
        },
      );
      return false;
    } else {
      return true;
    }
  }

  static Future<bool> saveImg(
    Uint8List img,
    String extension,
    String name,
  ) async {
    try {
      SmartDialog.showLoading(
          msg: L10n.of(navigatorKey.currentContext!).commonSaving);

      final SaveResult result = await SaverGallery.saveImage(
        img,
        fileName: '$name.$extension',
        skipIfExists: false,
        albumPath: 'Paperfold',
      );

      SmartDialog.dismiss();
      if (result.isSuccess) {
        await SmartDialog.showToast(
            '「${'$name.$extension'}」${L10n.of(navigatorKey.currentContext!).commonSaved}');
      }
      return true;
    } catch (err) {
      SmartDialog.dismiss();
      AnxToast.show(L10n.of(navigatorKey.currentContext!).commonFailed);
      AnxLog.severe("saveImage: saveImage error: $err");
      return true;
    }
  }

  static Future<bool> androidImgSaver(
    Uint8List img,
    String extension,
    String name,
  ) async {
    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      final deviceInfo = await deviceInfoPlugin.androidInfo;
      final sdkInt = deviceInfo.version.sdkInt;
      AnxLog.info('sdkInt: $sdkInt');

      if (sdkInt < 29) {
        if (!await requestStoragePer()) {
          return false;
        }
      }
      return await saveImg(img, extension, name);
    } catch (err) {
      SmartDialog.dismiss();
      AnxToast.show(L10n.of(navigatorKey.currentContext!).commonFailed);
      AnxLog.severe("saveImage: saveImage error: $err");
      return true;
    }
  }

  static Future<bool> downloadImg(
    Uint8List img,
    String extension,
    String name,
  ) async {
    String picName =
        "Paperfold_${name}_${DateTime.now().toString().replaceAll(RegExp(r'[- :]'), '').split('.').first}";
    return await androidImgSaver(img, extension, picName);
  }
}
