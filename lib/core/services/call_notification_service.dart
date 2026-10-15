import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/callings/model/calling_model.dart';

/// Shows the system "incoming call" screen (lock screen / notification) and
/// reports Accept / Decline presses. Knows nothing about WebRTC.
///
/// It is a singleton and [start] is called in main() BEFORE runApp, so a tap
/// on Accept/Decline while the app was closed is never lost: the events wait
/// in a buffer until the calling controller calls [attach].
class CallNotificationService {
  CallNotificationService._();
  static final CallNotificationService instance = CallNotificationService._();

  StreamSubscription? _subscription;
  bool _started = false;

  void Function(CallModel call)? _onAccept;
  void Function(CallModel call)? _onDecline;

  // Presses that arrived before anyone was listening.
  final List<({bool accepted, CallModel call})> _buffer = [];

  // Calls whose system screen WE closed. The plugin reports closing an
  // unanswered one as a "decline", which must not reject a call that was
  // just answered inside the app.
  final Set<String> _closedByApp = {};

  // ---------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------
  Future<void> start() async {
    if (_started) return;
    _started = true;

    await _askFullScreenPermissionOnce();

    _subscription = FlutterCallkitIncoming.onEvent.listen(_onEvent);

    // App was closed and the user already pressed Accept: pick it up.
    await _checkAcceptedCalls();
  }

  // Android 14+ needs "full-screen notifications" allowed for the incoming
  // call screen on a locked phone. The plugin opens the Settings page every
  // time it is asked, so only ask once per install, and only if not allowed.
  static const _askedFullScreenKey = 'callkit_full_screen_asked';

  Future<void> _askFullScreenPermissionOnce() async {
    try {
      final allowed = await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (allowed == true) return;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_askedFullScreenKey) == true) return;
      await prefs.setBool(_askedFullScreenKey, true);

      await FlutterCallkitIncoming.requestFullIntentPermission();
    } catch (e) {
      debugPrint('[callkit] full screen permission: $e');
    }
  }

  /// The controller says "tell me when the user presses a button".
  void attach({
    required void Function(CallModel call) onAccept,
    required void Function(CallModel call) onDecline,
  }) {
    _onAccept = onAccept;
    _onDecline = onDecline;

    final pending = List.of(_buffer);
    _buffer.clear();
    for (final item in pending) {
      _dispatch(item.accepted, item.call);
    }
  }

  void detach() {
    _onAccept = null;
    _onDecline = null;
  }

  void _dispatch(bool accepted, CallModel call) {
    final handler = accepted ? _onAccept : _onDecline;
    if (handler == null) {
      _buffer.add((accepted: accepted, call: call));
    } else {
      handler(call);
    }
  }

  // ---------------------------------------------------------------------
  // Events from the system call screen
  // ---------------------------------------------------------------------
  // "dynamic" on purpose: the event class changed between plugin versions.
  void _onEvent(dynamic event) {
    if (event == null) return;

    String name = '';
    dynamic body;
    try {
      name = event.event.toString();
    } catch (_) {
      try {
        name = event.name.toString();
      } catch (_) {}
    }
    try {
      body = event.body;
    } catch (_) {}

    final key = name.toLowerCase().replaceAll('_', '').replaceAll('event.', '');
    final call = _callFromBody(body);
    if (call == null) return;

    if (key.contains('actioncallaccept')) {
      _dispatch(true, call);
    } else if (key.contains('actioncalldecline')) {
      if (_closedByApp.remove(call.callId)) return; // not the user's press
      _dispatch(false, call);
    }
  }

  void _markClosedByApp(String callId) {
    _closedByApp.add(callId);
    // The plugin's event comes right away; don't keep the id forever
    Future<void>.delayed(
      const Duration(seconds: 10),
      () => _closedByApp.remove(callId),
    );
  }

  CallModel? _callFromBody(dynamic body) {
    try {
      if (body is! Map) return null;
      final map = Map<String, dynamic>.from(body);
      final extra = map['extra'];
      if (extra is! Map) return null;
      return CallModel.fromJson(
        Map<String, dynamic>.from(extra),
        direction: CallDirection.incoming,
      );
    } catch (e) {
      debugPrint('[callkit] could not read call data: $e');
      return null;
    }
  }

  Future<void> _checkAcceptedCalls() async {
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      if (active is! List) return;
      for (final item in active) {
        if (item is Map && item['isAccepted'] == true) {
          final call = _callFromBody(item);
          if (call != null) _dispatch(true, call);
        }
      }
    } catch (e) {
      debugPrint('[callkit] activeCalls: $e');
    }
  }

  // ---------------------------------------------------------------------
  // Show / hide the system call screen
  // ---------------------------------------------------------------------
  Future<void> showIncoming(CallModel call) async {
    final params = CallKitParams(
      id: call.callId, // must be a UUID
      nameCaller: call.callerName ?? 'Incoming call',
      appName: 'ChatMe',
      handle: call.isVideo ? 'Video call' : 'Audio call',
      type: call.isVideo ? 1 : 0, // 0 = audio, 1 = video
      duration: 45000, // stop ringing after 45 seconds
      extra: call.toJson(), // comes back when the user presses a button
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Used by the FCM background handler (push data -> system call screen).
  Future<void> showIncomingFromPush(Map<String, dynamic> data) async {
    await showIncoming(CallModel.fromPushData(data));
  }

  Future<void> endById(String? callId) async {
    if (callId == null || callId.isEmpty) return;
    _markClosedByApp(callId);
    try {
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      debugPrint('[callkit] endCall: $e');
    }
  }

  Future<void> endAll() async {
    try {
      final active = await FlutterCallkitIncoming.activeCalls();
      if (active is List) {
        for (final item in active) {
          final id = item is Map ? item['id']?.toString() : null;
          if (id != null && id.isNotEmpty) _markClosedByApp(id);
        }
      }
      await FlutterCallkitIncoming.endAllCalls();
    } catch (e) {
      debugPrint('[callkit] endAllCalls: $e');
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _started = false;
  }
}