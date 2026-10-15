import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What a call needs from the phone itself (Android; no-ops elsewhere):
///  - a foreground service, so the mic/camera keep working when the screen
///    locks or the app goes to the background (Android silences them otherwise)
///  - keep the screen on during video calls
///  - turn the screen off when the phone is held to the ear (audio calls),
///    so the cheek can't press mute / hang up
/// Never throws: a missing feature must not break the call.
class CallDeviceService {
  CallDeviceService._();

  static const _channel = MethodChannel('chatme/call_device');

  static Future<void> startCallService({
    required String title,
    required String text,
    required bool video,
  }) =>
      _invoke('startCallService', {'title': title, 'text': text, 'video': video});

  static Future<void> stopCallService() => _invoke('stopCallService');

  static Future<void> keepScreenOn(bool on) => _invoke('keepScreenOn', {'on': on});

  static Future<void> proximityScreenOff(bool on) =>
      _invoke('proximityScreenOff', {'on': on});

  static Future<void> _invoke(String method, [Map<String, Object?>? args]) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (e) {
      debugPrint('[calling] $method failed: $e');
    }
  }
}
