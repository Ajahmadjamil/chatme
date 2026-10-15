import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/permission/permission_handler.dart';
import '../../../core/services/call_notification_service.dart';
import '../../../core/services/call_push_sender.dart';
import '../../../core/services/call_signaling.dart';
import '../../../core/services/calling_service.dart';
import '../model/calling_model.dart';

/// Everything the UI needs to know about the current call.
class CallUiState {
  const CallUiState({
    this.status = CallState.idle,
    this.call,
    this.endReason,
    this.duration = Duration.zero,
    this.isMuted = false,
    this.isCameraOn = true,
    this.isFrontCamera = true,
    this.isSpeakerOn = false,
    this.hasLocalVideo = false,
    this.hasRemoteVideo = false,
  });

  final CallState status;
  final CallModel? call;
  final String? endReason;
  final Duration duration;
  final bool isMuted;
  final bool isCameraOn;
  final bool isFrontCamera;
  final bool isSpeakerOn;
  final bool hasLocalVideo;
  final bool hasRemoteVideo;

  bool get isInCall =>
      status != CallState.idle &&
          status != CallState.ended &&
          status != CallState.busy;

  CallUiState copyWith({
    CallState? status,
    CallModel? call,
    String? endReason,
    Duration? duration,
    bool? isMuted,
    bool? isCameraOn,
    bool? isFrontCamera,
    bool? isSpeakerOn,
    bool? hasLocalVideo,
    bool? hasRemoteVideo,
  }) =>
      CallUiState(
        status: status ?? this.status,
        call: call ?? this.call,
        endReason: endReason ?? this.endReason,
        duration: duration ?? this.duration,
        isMuted: isMuted ?? this.isMuted,
        isCameraOn: isCameraOn ?? this.isCameraOn,
        isFrontCamera: isFrontCamera ?? this.isFrontCamera,
        isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
        hasLocalVideo: hasLocalVideo ?? this.hasLocalVideo,
        hasRemoteVideo: hasRemoteVideo ?? this.hasRemoteVideo,
      );
}

/// ref.watch(callControllerProvider)          -> read the state
/// ref.read(callControllerProvider.notifier)  -> call methods
final callControllerProvider =
NotifierProvider<CallController, CallUiState>(CallController.new);

class CallController extends Notifier<CallUiState> {
  // Renderers draw the video on screen.
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();

  CallingService? _service;
  CallPushSender? _push;
  String _userId = '';
  String _userName = '';
  bool _renderersReady = false;
  bool _initializing = false;
  bool _wasConnected = false;
  Timer? _durationTimer;
  Timer? _idleTimer;

  @override
  CallUiState build() {
    ref.onDispose(() {
      debugPrint('[calling] controller DISPOSED');
      _durationTimer?.cancel();
      _idleTimer?.cancel();
      CallNotificationService.instance.detach();
      _service?.dispose();
      localRenderer.dispose();
      remoteRenderer.dispose();
    });
    return const CallUiState();
  }

  // ====================================================================
  // SETUP: call once after the user is logged in
  // ====================================================================
  Future<void> init({
    required String userId,
    required String userName,
    required CallSignaling signaling,
    required CallPushSender pushSender,
  }) async {
    if (_initializing) return;
    if (_service != null && _userId == userId) return;
    _initializing = true;

    try {
      await shutdown();

      _userId = userId;
      _userName = userName;
      _push = pushSender;

      if (!_renderersReady) {
        await localRenderer.initialize();
        await remoteRenderer.initialize();
        _renderersReady = true;
      }

      final service = CallingService(signaling: signaling);
      service.onStateChanged = _onServiceState;
      service.onIncomingCall = _onIncomingCall;
      service.onLocalStream = (stream) {
        localRenderer.srcObject = stream;
        state = state.copyWith(
          hasLocalVideo: stream != null && stream.getVideoTracks().isNotEmpty,
        );
      };
      service.onRemoteStream = (stream) {
        remoteRenderer.srcObject = stream;
        state = state.copyWith(
          hasRemoteVideo:
          stream != null && stream.getVideoTracks().isNotEmpty,
        );
      };
      _service = service;

      await service.connect(userId);

      // Buttons on the system call screen -> same as buttons in our app.
      // Presses that happened while the app was closed are delivered now.
      CallNotificationService.instance.attach(
        onAccept: _onCallKitAccept,
        onDecline: _onCallKitDecline,
      );
    } finally {
      _initializing = false;
    }
  }

  /// Call on logout.
  Future<void> shutdown() async {
    debugPrint('[calling] SHUTDOWN called');
    CallNotificationService.instance.detach();
    _durationTimer?.cancel();
    _durationTimer = null;
    _idleTimer?.cancel();
    final service = _service;
    _service = null;
    _userId = '';
    await service?.dispose();
    state = const CallUiState();
  }

  // ====================================================================
  // PUBLIC API
  // ====================================================================

  /// Starts a call. Returns an error message, or null if all is fine.
  Future<String?> initiateCall({
    required String receiverId,
    required String channelId,
    required CallType type,
    String? receiverName,
  }) async {
    if (_service == null) return 'Calling is not ready yet';
    if (state.isInCall) return 'You are already in a call';

    final allowed = await CallPermissionHandler.request(type);
    if (!allowed) return 'Camera/microphone permission is required';

    final call = CallModel(
      callId: const Uuid().v4(),
      callerId: _userId,
      receiverId: receiverId,
      channelId: channelId,
      type: type,
      direction: CallDirection.outgoing,
      callerName: _userName,
      receiverName: receiverName,
    );

    _wasConnected = false;
    state = CallUiState(call: call, isSpeakerOn: call.isVideo);

    await _service!.startCall(call);
    // Also wake the other phone if its app is closed.
    unawaited(_push?.sendInvite(call));
    return null;
  }

  Future<void> acceptCall() async {
    final call = state.call;
    if (call == null) return;

    final allowed = await CallPermissionHandler.request(call.type);
    if (!allowed) {
      await rejectCall();
      return;
    }

    await CallNotificationService.instance.endAll();
    await _service?.acceptCall();
  }

  Future<void> rejectCall() async {
    await CallNotificationService.instance.endAll();
    await _service?.rejectCall();
  }

  Future<void> endCall() async => _service?.endCall();

  void toggleMute() {
    final muted = !state.isMuted;
    _service?.setMicMuted(muted);
    state = state.copyWith(isMuted: muted);
  }

  void toggleCamera() {
    if (state.call?.isVideo != true) return;
    final on = !state.isCameraOn;
    _service?.setCameraEnabled(on);
    state = state.copyWith(isCameraOn: on);
  }

  Future<void> switchCamera() async {
    if (state.call?.isVideo != true || !state.isCameraOn) return;
    await _service?.switchCamera();
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  Future<void> toggleSpeaker() async {
    final on = !state.isSpeakerOn;
    await _service?.setSpeaker(on);
    state = state.copyWith(isSpeakerOn: on);
  }

  // ====================================================================
  // SYSTEM CALL SCREEN (CallKit) BUTTONS
  // ====================================================================
  Future<void> _onCallKitAccept(CallModel call) async {
    final service = _service;
    if (service == null) return;
    // App was closed: the invite only came by push, so create it now.
    if (state.call?.callId != call.callId) service.receiveInvite(call);
    await acceptCall();
  }

  Future<void> _onCallKitDecline(CallModel call) async {
    if (state.call?.callId == call.callId) {
      await rejectCall();
    } else {
      _service?.declineWithoutUi(call);
    }
  }

  // ====================================================================
  // REACTING TO THE SERVICE
  // ====================================================================
  void _onIncomingCall(CallModel call) {
    _wasConnected = false;
    state = CallUiState(call: call, isSpeakerOn: call.isVideo);

    final inForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    // App open -> our own Accept/Decline screen is enough.
    // App in background / phone locked -> show the system call screen.
    if (!inForeground) {
      CallNotificationService.instance.showIncoming(call);
    }
  }

  void _onServiceState(CallState newStatus) {
    _idleTimer?.cancel();

    switch (newStatus) {
      case CallState.connected:
        _wasConnected = true;
        _durationTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
          state = state.copyWith(
            duration: state.duration + const Duration(seconds: 1),
          );
        });
        state = state.copyWith(status: newStatus);
        break;

      case CallState.ended:
      case CallState.busy:
        _durationTimer?.cancel();
        _durationTimer = null;
        CallNotificationService.instance.endAll();

        // Caller gave up (or nobody answered): dismiss the other phone's
        // system call screen too, in case its app was closed.
        final call = state.call;
        if (call != null && !call.isIncoming && !_wasConnected) {
          unawaited(_push?.sendCancel(call));
        }

        state = state.copyWith(
          status: newStatus,
          endReason: _service?.lastEndReason,
        );
        break;

      case CallState.idle:
      // Keep the "Call ended" screen visible for a moment.
        _idleTimer = Timer(const Duration(milliseconds: 1500), () {
          state = const CallUiState();
        });
        break;

      default:
        state = state.copyWith(status: newStatus);
    }
  }
}