import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../features/callings/model/calling_model.dart';
import 'call_signaling.dart';

/// The calling engine: WebRTC + signaling. No UI, no Riverpod, no Supabase.
/// It reports to the controller through the callbacks below.
class CallingService {
  CallingService({
    required this.signaling,
    this.iceServers = const [
      {'urls': 'stun:stun.l.google.com:19302'},
      // Production: add a TURN server here, otherwise some networks
      // (mobile carriers, strict NAT) cannot connect.
    ],
  });

  final CallSignaling signaling;
  final List<Map<String, dynamic>> iceServers;

  static const _ringTimeout = Duration(seconds: 45);
  static const _connectTimeout = Duration(seconds: 30);
  static const _reconnectTimeout = Duration(seconds: 20);

  // ---- Callbacks: the controller sets these ----
  void Function(CallState state)? onStateChanged;
  void Function(CallModel call)? onIncomingCall;
  void Function(MediaStream? stream)? onLocalStream;
  void Function(MediaStream? stream)? onRemoteStream;

  /// Why the last call ended (shown on screen).
  String? lastEndReason;

  String? _userId;
  StreamSubscription? _signalSub;

  CallModel? _call;
  CallState _state = CallState.idle;
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  bool _remoteDescriptionSet = false;
  bool _finishing = false;

  // ICE candidates that arrive too early wait here.
  final List<RTCIceCandidate> _pendingCandidates = [];

  Timer? _ringTimer;
  Timer? _connectTimer;
  Timer? _reconnectTimer;

  bool get _isCaller => _call?.direction == CallDirection.outgoing;
  bool get hasActiveCall => _call != null;

  // ====================================================================
  // 1) CONNECT
  // ====================================================================
  Future<void> connect(String userId) async {
    _userId = userId;
    await _signalSub?.cancel();
    await signaling.connect(userId);
    _signalSub = signaling.messages.listen(_onSignal);
  }

  void _onSignal(Map<String, dynamic> m) {
    debugPrint('[calling] GOT signal: ${m['event']}');
    switch (m['event']) {
      case 'call:invite':
        receiveInvite(CallModel.fromJson(m, direction: CallDirection.incoming));
        break;
      case 'call:ringing':
        _onRinging(m);
        break;
      case 'call:accept':
        _onAccepted(m);
        break;
      case 'call:reject':
        _ifSameCall(m, () => _finish('Call declined'));
        break;
      case 'call:busy':
        _ifSameCall(
            m, () => _finish('User is busy', finalState: CallState.busy));
        break;
      case 'call:end':
        _ifSameCall(m, () => _finish('Call ended by other user'));
        break;
      case 'webrtc:offer':
        _onOffer(m);
        break;
      case 'webrtc:answer':
        _onAnswer(m);
        break;
      case 'webrtc:candidate':
        _onCandidate(m);
        break;
    }
  }

  bool _isSameCall(Map<String, dynamic> m) =>
      _call != null && m['callId'] == _call!.callId;

  void _ifSameCall(Map<String, dynamic> m, VoidCallback action) {
    if (_isSameCall(m)) action();
  }

  // Send a message to ANY user (used for busy / decline without a call).
  void _sendTo(String toUserId, String event, Map<String, dynamic> extra) {
    signaling.send(toUserId, event, {
      'from': _userId,
      'to': toUserId,
      ...extra,
    }).catchError((e) {
      debugPrint('[calling] send $event failed: $e');
    });
  }

  // Send a message to the other user of the CURRENT call.
  void _send(String event, [Map<String, dynamic> extra = const {}]) {
    if (event == 'call:end') {
      debugPrint('[calling] call:end requested by:');
      debugPrint(StackTrace.current.toString());
    }
    final call = _call;
    if (call == null) return;
    _sendTo(call.peerId, event, {'callId': call.callId, ...extra});
  }
  void _setState(CallState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }

  // ====================================================================
  // 2) ACTIONS (called by the controller)
  // ====================================================================

  /// Caller: start a new call.
  Future<void> startCall(CallModel call) async {
    if (_call != null) return;
    lastEndReason = null;
    _call = call;
    _setState(CallState.initiating);

    try {
      await _openCameraAndMic(call.type);
      await _createPeerConnection();
      debugPrint('[calling] startCall: opening mic');
      await _openCameraAndMic(call.type);
      debugPrint('[calling] startCall: creating pc');
      await _createPeerConnection();
      debugPrint('[calling] startCall: sending invite to ${call.peerId}');
      _send('call:invite', call.toJson());

      _ringTimer = Timer(_ringTimeout, () {
        _send('call:end');
        _finish('No answer');
      });
    } catch (e) {
      await _finish('Could not start call: $e');
    }
  }

  /// Receiver: an invite arrived (from realtime OR from a push / CallKit).
  /// Safe to call twice for the same call.
  void receiveInvite(CallModel incoming) {
    if (_call != null) {
      if (_call!.callId != incoming.callId) {
        // I am already in another call.
        _sendTo(incoming.callerId, 'call:busy', {'callId': incoming.callId});
      }
      return; // same call again (push + realtime): ignore
    }

    lastEndReason = null;
    _call = incoming;
    onIncomingCall?.call(incoming);
    _setState(CallState.ringing);
    _send('call:ringing');

    _ringTimer = Timer(_ringTimeout, () => _finish('Missed call'));
  }

  /// Receiver: accept the incoming call.
  Future<void> acceptCall() async {
    final call = _call;
    if (call == null || _state != CallState.ringing) return;

    _ringTimer?.cancel();
    _setState(CallState.connecting);

    try {
      await _openCameraAndMic(call.type);
      // The connection must exist BEFORE the offer arrives.
      await _createPeerConnection();
      _armConnectTimer();
      _send('call:accept');
    } catch (e) {
      _send('call:end');
      await _finish('Could not accept call: $e');
    }
  }

  /// Receiver: decline the incoming call.
  Future<void> rejectCall() async {
    if (_call == null) return;
    _send('call:reject');
    await _finish('Call declined');
  }

  /// Decline a call that has no screen (e.g. declined from a closed app).
  void declineWithoutUi(CallModel call) {
    _sendTo(call.callerId, 'call:reject', {'callId': call.callId});
  }

  /// Either side: hang up.
  Future<void> endCall() async {
    if (_call == null) return;
    _send('call:end');
    await _finish('Call ended');
  }

  // ====================================================================
  // 3) MESSAGES FROM THE OTHER USER
  // ====================================================================
  void _onRinging(Map<String, dynamic> m) {
    if (_isSameCall(m) && _state == CallState.initiating) {
      _setState(CallState.ringing);
    }
  }

  // Receiver accepted (caller side) -> create and send the offer.
  Future<void> _onAccepted(Map<String, dynamic> m) async {
    if (!_isSameCall(m) || !_isCaller || _pc == null) return;
    _ringTimer?.cancel();
    _setState(CallState.connecting);
    _armConnectTimer();
    await _sendOffer();
  }

  Future<void> _sendOffer({bool iceRestart = false}) async {
    final pc = _pc;
    if (pc == null) return;
    final offer = await pc.createOffer(iceRestart ? {'iceRestart': true} : {});
    await pc.setLocalDescription(offer);
    _send('webrtc:offer', {'sdp': offer.sdp, 'type': offer.type});
  }

  Future<void> _onOffer(Map<String, dynamic> m) async {
    final pc = _pc;
    if (!_isSameCall(m) || pc == null) return;

    await pc.setRemoteDescription(
      RTCSessionDescription(m['sdp'] as String, m['type'] as String),
    );
    _remoteDescriptionSet = true;
    await _addPendingCandidates();

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    _send('webrtc:answer', {'sdp': answer.sdp, 'type': answer.type});
  }

  Future<void> _onAnswer(Map<String, dynamic> m) async {
    final pc = _pc;
    if (!_isSameCall(m) || pc == null) return;

    await pc.setRemoteDescription(
      RTCSessionDescription(m['sdp'] as String, m['type'] as String),
    );
    _remoteDescriptionSet = true;
    await _addPendingCandidates();
  }

  Future<void> _onCandidate(Map<String, dynamic> m) async {
    if (!_isSameCall(m) || _pc == null) return;

    final candidate = RTCIceCandidate(
      m['candidate'] as String?,
      m['sdpMid'] as String?,
      (m['sdpMLineIndex'] as num?)?.toInt(),
    );

    if (_remoteDescriptionSet) {
      await _pc!.addCandidate(candidate);
    } else {
      _pendingCandidates.add(candidate);
    }
  }

  Future<void> _addPendingCandidates() async {
    for (final c in _pendingCandidates) {
      await _pc?.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  // ====================================================================
  // 4) WEBRTC SETUP
  // ====================================================================
  Future<void> _openCameraAndMic(CallType type) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': type == CallType.video
          ? {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
        'frameRate': {'ideal': 30},
      }
          : false,
    });
    onLocalStream?.call(_localStream);

    // Video call -> loudspeaker, audio call -> earpiece.
    await Helper.setSpeakerphoneOn(type == CallType.video);
  }

  Future<void> _createPeerConnection() async {
    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;

    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      _send('webrtc:candidate', candidate.toMap());
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) onRemoteStream?.call(event.streams.first);
    };

    pc.onIceConnectionState = _onConnectionChanged;
  }

  void _onConnectionChanged(RTCIceConnectionState state) {
    debugPrint('[calling] ICE state: $state');
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        _connectTimer?.cancel();
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        if (_state != CallState.connected) _setState(CallState.connected);
        break;

      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        if (_state == CallState.connected) _setState(CallState.reconnecting);
        _startReconnectTimer();
        break;

      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        _setState(CallState.reconnecting);
        _startReconnectTimer();
        if (_isCaller) _sendOffer(iceRestart: true);
        break;

      default:
        break;
    }
  }

  // After "accept", the media must connect within a limit.
  void _armConnectTimer() {
    _connectTimer?.cancel();
    _connectTimer = Timer(_connectTimeout, () {
      if (_state != CallState.connected) {
        _send('call:end');
        _finish('Could not connect');
      }
    });
  }

  void _startReconnectTimer() {
    _reconnectTimer ??= Timer(_reconnectTimeout, () {
      _send('call:end');
      _finish('Connection lost');
    });
  }

  // ====================================================================
  // 5) IN-CALL CONTROLS
  // ====================================================================
  void setMicMuted(bool muted) {
    for (final t in _localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = !muted;
    }
  }

  void setCameraEnabled(bool enabled) {
    for (final t in _localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = enabled;
    }
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  Future<void> setSpeaker(bool on) => Helper.setSpeakerphoneOn(on);

  // ====================================================================
  // 6) CLEANUP: the ONLY way a call ever ends
  // ====================================================================
  Future<void> _finish(String reason,
      {CallState finalState = CallState.ended}) async {
    final call = _call;
    if (call == null || _finishing) return;
    _finishing = true;
    lastEndReason = reason;

    _ringTimer?.cancel();
    _connectTimer?.cancel();
    _reconnectTimer?.cancel();
    _ringTimer = null;
    _connectTimer = null;
    _reconnectTimer = null;
    _pendingCandidates.clear();
    _remoteDescriptionSet = false;

    try {
      // stop() turns off the camera light and the mic indicator.
      for (final t in _localStream?.getTracks() ?? <MediaStreamTrack>[]) {
        await t.stop();
      }
      await _localStream?.dispose();
      await _pc?.close();
      await _pc?.dispose();
    } catch (e) {
      debugPrint('[calling] cleanup error: $e');
    }

    _localStream = null;
    _pc = null;
    onLocalStream?.call(null);
    onRemoteStream?.call(null);

    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}

    _setState(finalState); // ended / busy (UI shows the reason)
    _call = null;
    _setState(CallState.idle);
    _finishing = false;

    signaling.release(call.peerId);
  }

  Future<void> dispose() async {
    if (_call != null) {
      _send('call:end');
      await _finish('Service closed');
    }
    await _signalSub?.cancel();
    await signaling.dispose();
  }
}