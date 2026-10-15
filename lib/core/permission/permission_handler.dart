// Prefix "ph" because this file has the same name as the package file.
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../features/callings/model/calling_model.dart';


class CallPermissionHandler {
  /// Asks for the microphone (always) and the camera (video calls only).
  /// Returns true only if everything needed was granted.
  static Future<bool> request(CallType type) async {
    final permissions = [
      ph.Permission.microphone,
      if (type == CallType.video) ph.Permission.camera,
    ];
    final results = await permissions.request();
    return results.values.every((status) => status.isGranted);
  }

  /// Opens the phone's app settings (if the user denied permanently).
  static Future<bool> openSettings() => ph.openAppSettings();
}