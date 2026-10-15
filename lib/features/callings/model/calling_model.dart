// What kind of call is it?
enum CallType { audio, video }

// Who started the call? (from MY phone's point of view)
enum CallDirection { outgoing, incoming }

// What the call is doing right now. The UI only reacts to this value.
enum CallState {
  idle, // no call
  initiating, // I pressed call, starting up
  ringing, // other phone is ringing / I am being called
  connecting, // accepted, setting up audio/video
  connected, // talking
  reconnecting, // network problem, trying to recover
  ended, // call finished
  busy, // other person is already in a call
}

/// Plain data about ONE call. No chat-specific logic: the host app maps its
/// own user id / chat id onto callerId, receiverId and channelId.
class CallModel {
  const CallModel({
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.channelId,
    required this.type,
    required this.direction,
    this.callerName,
    this.receiverName,
  });

  final String callId;
  final String callerId;
  final String receiverId;
  final String channelId; // e.g. the chat id (only passed along)
  final CallType type;
  final CallDirection direction;
  final String? callerName; // shown on the incoming call screen
  final String? receiverName; // shown on the outgoing call screen

  bool get isVideo => type == CallType.video;
  bool get isIncoming => direction == CallDirection.incoming;

  /// The "other person" from my point of view.
  String get peerId => isIncoming ? callerId : receiverId;
  String? get peerName => isIncoming ? callerName : receiverName;

  // Used for realtime signaling and for the CallKit "extra" data.
  Map<String, dynamic> toJson() => {
    'callId': callId,
    'callerId': callerId,
    'receiverId': receiverId,
    'channelId': channelId,
    'type': type.name,
    'callerName': callerName ?? '',
    'receiverName': receiverName ?? '',
  };

  factory CallModel.fromJson(
      Map<String, dynamic> json, {
        required CallDirection direction,
      }) {
    String? opt(String key) {
      final v = json[key]?.toString();
      return (v == null || v.isEmpty) ? null : v;
    }

    return CallModel(
      callId: json['callId'].toString(),
      callerId: json['callerId'].toString(),
      receiverId: json['receiverId'].toString(),
      channelId: json['channelId'].toString(),
      type: json['type'] == 'video' ? CallType.video : CallType.audio,
      direction: direction,
      callerName: opt('callerName'),
      receiverName: opt('receiverName'),
    );
  }

  /// Builds a call from an FCM data push (all values are strings).
  factory CallModel.fromPushData(Map<String, dynamic> d) {
    String? opt(String key) {
      final v = d[key]?.toString();
      return (v == null || v.isEmpty) ? null : v;
    }

    return CallModel(
      callId: d['call_id'].toString(),
      callerId: d['caller_id'].toString(),
      receiverId: d['receiver_id'].toString(),
      channelId: (d['channel_id'] ?? '').toString(),
      type: d['call_type'] == 'video' ? CallType.video : CallType.audio,
      direction: CallDirection.incoming,
      callerName: opt('caller_name'),
      receiverName: opt('receiver_name'),
    );
  }
}