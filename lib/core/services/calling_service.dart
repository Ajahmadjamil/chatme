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
    this.iceServers = defaultIceServers,
  });

  /// Free public STUN servers. Some networks (mobile carriers, strict NAT)
  /// also need a TURN server — the host app can pass one in [iceServers].
  static const defaultIceServers = <Map<String, dynamic>>[
    {
      'urls': [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
      ],
    },
  ];

  final CallSignaling signaling;
  final List<Map<String, dynamic>> iceServers;

  /// Configures the media engine. Must run before the first WebRTC call
  /// (renderers, getUserMedia, peer connection) — later calls are ignored.
  static Future<void> initMediaEngine() async {
    try {
      await WebRTC.initialize(options: {
        // Let WebRTC's own echo canceller (AEC3) and noise suppressor clean
        // the mic instead of the phone's built-in ones, which are weak on
        // many devices and switch WebRTC's stronger processing off.
        'androidUseHardwareAudioProcessing': false,
        // Full-band audio, same rate the Opus codec works at
        'audioSampleRate': 48000,
      });
    } catch (e) {
      debugPrint('[calling] WebRTC init options not applied: $e');
    }
  }

  // Video sender limits: sharp 720p, smooth 30 fps
  static const _videoMaxBitrate = 1500 * 1000; // bits per second
  static const _videoMaxFramerate = 30;

  static const _ringTimeout = Duration(seconds: 45);
  static const _connectTimeout = Duration(seconds: 30);
  static const _reconnectTimeout = Duration(seconds: 20);
  // How long a dropped connection may wait before the caller re-negotiates
  static const _iceRestartDelay = Duration(seconds: 3);

  // ---- Callbacks: the controller sets these ----
  void Function(CallState state)? onStateChanged;
  void Function(CallModel call)? onIncomingCall;
  void Function(MediaStream? stream)? onLocalStream;
  void Function(MediaStream? stream)? onRemoteStream;
  void Function(bool on)? onRemoteCameraChanged;

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
  Timer? _iceRestartTimer;

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
      case 'call:camera':
        _ifSameCall(m, () => onRemoteCameraChanged?.call(m['on'] != false));
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
  // Never throws; completes once the message went out (or failed).
  Future<void> _sendTo(
      String toUserId, String event, Map<String, dynamic> extra) {
    return signaling.send(toUserId, event, {
      'from': _userId,
      'to': toUserId,
      ...extra,
    }).catchError((e) {
      debugPrint('[calling] send $event failed: $e');
    });
  }

  // Send a message to the other user of the CURRENT call.
  Future<void> _send(String event, [Map<String, dynamic> extra = const {}]) {
    final call = _call;
    if (call == null) return Future<void>.value();
    return _sendTo(call.peerId, event, {'callId': call.callId, ...extra});
  }

  // Hang up: tell the other phone, then clean up. The channel is closed only
  // after "call:end" went out, so the other phone never keeps ringing.
  Future<void> _sendEndAndFinish(String reason) =>
      _finish(reason, afterSent: _send('call:end'));
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
      // Open the camera/mic and the connection ONCE — a second copy would
      // keep capturing and encoding in the background for the whole call
      debugPrint('[calling] startCall: opening mic');
      await _openCameraAndMic(call.type);
      if (!_isCurrent(call)) return _dropLateMedia();
      debugPrint('[calling] startCall: creating pc');
      await _createPeerConnection();
      if (!_isCurrent(call)) return _dropLateMedia();
      debugPrint('[calling] startCall: sending invite to ${call.peerId}');
      unawaited(_send('call:invite', call.toJson()));

      _ringTimer = Timer(_ringTimeout, () => _sendEndAndFinish('No answer'));
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
        _replyWithoutCall(incoming.callerId, 'call:busy', incoming.callId);
      }
      return; // same call again (push + realtime): ignore
    }

    lastEndReason = null;
    _call = incoming;
    onIncomingCall?.call(incoming);
    _setState(CallState.ringing);
    unawaited(_send('call:ringing'));

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
      if (!_isCurrent(call)) return _dropLateMedia();
      // The connection must exist BEFORE the offer arrives.
      await _createPeerConnection();
      if (!_isCurrent(call)) return _dropLateMedia();
      _armConnectTimer();
      unawaited(_send('call:accept'));
    } catch (e) {
      await _sendEndAndFinish('Could not accept call: $e');
    }
  }

  /// Receiver: decline the incoming call.
  Future<void> rejectCall() async {
    if (_call == null) return;
    await _finish('Call declined', afterSent: _send('call:reject'));
  }

  /// Decline a call that has no screen (e.g. declined from a closed app).
  void declineWithoutUi(CallModel call) {
    _replyWithoutCall(call.callerId, 'call:reject', call.callId);
  }

  // Answer someone who isn't in my current call (busy / decline), then close
  // the channel opened for it — unless I'm in a call with that person.
  void _replyWithoutCall(String toUserId, String event, String callId) {
    unawaited(_sendTo(toUserId, event, {'callId': callId}).whenComplete(() {
      if (_call?.peerId != toUserId) signaling.release(toUserId);
    }));
  }

  /// Either side: hang up.
  Future<void> endCall() async {
    if (_call == null) return;
    await _sendEndAndFinish('Call ended');
  }

  // Is this still the call in progress? (It may have been hung up while the
  // camera/mic or the connection were still opening.)
  bool _isCurrent(CallModel call) => _call?.callId == call.callId;

  // The call ended while media was still opening: release what came too late,
  // otherwise the camera / mic stay on with no call.
  Future<void> _dropLateMedia() async {
    final stream = _localStream;
    final pc = _pc;
    _localStream = null;
    _pc = null;
    try {
      for (final t in stream?.getTracks() ?? <MediaStreamTrack>[]) {
        await t.stop();
      }
      await stream?.dispose();
      await pc?.close();
      await pc?.dispose();
    } catch (e) {
      debugPrint('[calling] releasing late media failed: $e');
    }
    onLocalStream?.call(null);
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
    // Only the first accept counts — a repeated one (push + realtime) would
    // restart the negotiation in the middle
    if (_state != CallState.initiating && _state != CallState.ringing) return;
    _ringTimer?.cancel();
    _setState(CallState.connecting);
    _armConnectTimer();
    await _sendOffer();
  }

  // The negotiation steps below run from network messages and timers, so
  // they catch their own errors (e.g. the call ended while one was running)
  // instead of crashing; the connect/reconnect timers end a call that can't
  // recover.
  Future<void> _sendOffer({bool iceRestart = false}) async {
    final pc = _pc;
    if (pc == null) return;
    try {
      final offer =
          await pc.createOffer(iceRestart ? {'iceRestart': true} : {});
      await pc.setLocalDescription(offer);
      unawaited(_send('webrtc:offer', {'sdp': offer.sdp, 'type': offer.type}));
      await _tuneSenders(pc);
    } catch (e) {
      debugPrint('[calling] sending offer failed: $e');
    }
  }

  Future<void> _onOffer(Map<String, dynamic> m) async {
    final pc = _pc;
    if (!_isSameCall(m) || pc == null) return;

    try {
      await pc.setRemoteDescription(
        RTCSessionDescription(m['sdp'] as String, m['type'] as String),
      );
      _remoteDescriptionSet = true;
      await _addPendingCandidates();

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      unawaited(
          _send('webrtc:answer', {'sdp': answer.sdp, 'type': answer.type}));
      await _tuneSenders(pc);
    } catch (e) {
      debugPrint('[calling] handling offer failed: $e');
    }
  }

  Future<void> _onAnswer(Map<String, dynamic> m) async {
    final pc = _pc;
    if (!_isSameCall(m) || pc == null) return;

    try {
      await pc.setRemoteDescription(
        RTCSessionDescription(m['sdp'] as String, m['type'] as String),
      );
      _remoteDescriptionSet = true;
      await _addPendingCandidates();
    } catch (e) {
      debugPrint('[calling] handling answer failed: $e');
    }
  }

  Future<void> _onCandidate(Map<String, dynamic> m) async {
    final pc = _pc;
    if (!_isSameCall(m) || pc == null) return;

    final candidate = RTCIceCandidate(
      m['candidate'] as String?,
      m['sdpMid'] as String?,
      (m['sdpMLineIndex'] as num?)?.toInt(),
    );

    if (!_remoteDescriptionSet) {
      _pendingCandidates.add(candidate);
      return;
    }
    try {
      await pc.addCandidate(candidate);
    } catch (e) {
      debugPrint('[calling] adding candidate failed: $e');
    }
  }

  Future<void> _addPendingCandidates() async {
    final pending = List.of(_pendingCandidates);
    _pendingCandidates.clear();
    for (final c in pending) {
      try {
        await _pc?.addCandidate(c);
      } catch (e) {
        debugPrint('[calling] adding early candidate failed: $e');
      }
    }
  }

  // ====================================================================
  // 4) WEBRTC SETUP
  // ====================================================================
  Future<void> _openCameraAndMic(CallType type) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        // Standard names (iOS / web)...
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        // ...and the names Android's WebRTC actually reads
        'optional': [
          {'googEchoCancellation': 'true'},
          {'googNoiseSuppression': 'true'},
          {'googAutoGainControl': 'true'},
          {'googHighpassFilter': 'true'}, // cuts low rumble / wind noise
        ],
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
      // Audio + video over one connection: fewer ports, faster setup
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      // Start finding network routes right away, before the other side answers
      'iceCandidatePoolSize': 2,
      // Keep watching for new routes, so switching Wi-Fi <-> mobile data
      // can recover the call instead of dropping it
      'continualGatheringPolicy': 'gather_continually',
    });
    _pc = pc;

    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      unawaited(_send('webrtc:candidate', candidate.toMap()));
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) onRemoteStream?.call(event.streams.first);
    };

    pc.onIceConnectionState = _onConnectionChanged;
  }

  // Quality settings for what this phone sends:
  //  - audio gets high priority, so on a weak network the voice stays clear
  //    and the video gives way first
  //  - video is capped at a sharp 720p bitrate and keeps 30 fps, lowering
  //    resolution instead of frame rate when bandwidth drops, so motion
  //    never looks laggy
  Future<void> _tuneSenders(RTCPeerConnection pc) async {
    try {
      for (final sender in await pc.getSenders()) {
        final kind = sender.track?.kind;
        final params = sender.parameters;
        final encodings = params.encodings;
        if (kind == null || encodings == null || encodings.isEmpty) continue;

        for (final encoding in encodings) {
          if (kind == 'audio') {
            encoding.priority = RTCPriorityType.high;
            encoding.networkPriority = RTCPriorityType.high;
          } else if (kind == 'video') {
            encoding.maxBitrate = _videoMaxBitrate;
            encoding.maxFramerate = _videoMaxFramerate;
          }
        }
        if (kind == 'video') {
          params.degradationPreference =
              RTCDegradationPreference.MAINTAIN_FRAMERATE;
        }
        await sender.setParameters(params);
      }
    } catch (e) {
      // Tuning is a bonus — it must never break the call
      debugPrint('[calling] sender tuning skipped: $e');
    }
  }

  void _onConnectionChanged(RTCIceConnectionState state) {
    debugPrint('[calling] ICE state: $state');
    switch (state) {
      case RTCIceConnectionState.RTCIceConnectionStateConnected:
      case RTCIceConnectionState.RTCIceConnectionStateCompleted:
        _connectTimer?.cancel();
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _iceRestartTimer?.cancel();
        _iceRestartTimer = null;
        if (_state != CallState.connected) _setState(CallState.connected);
        break;

      case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
        if (_state == CallState.connected) _setState(CallState.reconnecting);
        _startReconnectTimer();
        // Often it comes back by itself (brief signal loss). If not, the
        // caller re-negotiates after a few seconds instead of waiting for
        // ICE to give up completely — e.g. after switching Wi-Fi <-> data.
        if (_isCaller) {
          _iceRestartTimer ??= Timer(_iceRestartDelay, () {
            _iceRestartTimer = null;
            if (_state == CallState.reconnecting) {
              _sendOffer(iceRestart: true);
            }
          });
        }
        break;

      case RTCIceConnectionState.RTCIceConnectionStateFailed:
        _setState(CallState.reconnecting);
        _startReconnectTimer();
        _iceRestartTimer?.cancel();
        _iceRestartTimer = null;
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
        _sendEndAndFinish('Could not connect');
      }
    });
  }

  void _startReconnectTimer() {
    _reconnectTimer ??= Timer(
      _reconnectTimeout,
      () => _sendEndAndFinish('Connection lost'),
    );
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
    // A disabled track just freezes on the other side — tell it to show
    // the avatar instead
    unawaited(_send('call:camera', {'on': enabled}));
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? [];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  Future<void> setSpeaker(bool on) => Helper.setSpeakerphoneOn(on);

  // ====================================================================
  // 6) CLEANUP: the ONLY way a call ever ends
  // ====================================================================
  /// [afterSent]: a last message still on its way (e.g. "call:end"); the
  /// channel to the other user is kept open until it has gone out.
  Future<void> _finish(String reason,
      {CallState finalState = CallState.ended, Future<void>? afterSent}) async {
    final call = _call;
    if (call == null || _finishing) return;
    _finishing = true;
    lastEndReason = reason;

    _ringTimer?.cancel();
    _connectTimer?.cancel();
    _reconnectTimer?.cancel();
    _iceRestartTimer?.cancel();
    _ringTimer = null;
    _connectTimer = null;
    _reconnectTimer = null;
    _iceRestartTimer = null;
    _pendingCandidates.clear();
    _remoteDescriptionSet = false;

    // Detach first, so closing the connection can't fire "disconnected"
    // and start reconnect timers for a call that is already over
    final pc = _pc;
    final stream = _localStream;
    _pc = null;
    _localStream = null;
    pc?.onIceConnectionState = null;
    pc?.onIceCandidate = null;
    pc?.onTrack = null;

    try {
      // stop() turns off the camera light and the mic indicator.
      for (final t in stream?.getTracks() ?? <MediaStreamTrack>[]) {
        await t.stop();
      }
      await stream?.dispose();
      await pc?.close();
      await pc?.dispose();
    } catch (e) {
      debugPrint('[calling] cleanup error: $e');
    }

    onLocalStream?.call(null);
    onRemoteStream?.call(null);

    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}

    _setState(finalState); // ended / busy (UI shows the reason)
    _call = null;
    _setState(CallState.idle);
    _finishing = false;

    // Close the channel only after the last message (e.g. call:end) went
    // out — and not if a new call with the same person already uses it.
    final peerId = call.peerId;
    unawaited((afterSent ?? Future<void>.value())
        .timeout(const Duration(seconds: 3), onTimeout: () {})
        .whenComplete(() {
      if (_call?.peerId != peerId) signaling.release(peerId);
    }));
  }

  Future<void> dispose() async {
    if (_call != null) {
      await _sendEndAndFinish('Service closed');
    }
    await _signalSub?.cancel();
    await signaling.dispose();
  }
}