import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How two phones exchange call messages (invite, accept, offer, ...).
abstract class CallSignaling {
  Stream<Map<String, dynamic>> get messages;

  Future<void> connect(String myUserId);
  Future<void> send(String toUserId, String event, Map<String, dynamic> data);

  Future<void> release(String peerId);

  Future<void> dispose();
}

class SupabaseCallSignaling implements CallSignaling {
  SupabaseCallSignaling({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  RealtimeChannel? _inbox;
  final Map<String, Future<RealtimeChannel>> _outbox = {};

  static const _broadcastEvent = 'signal';

  @override
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  @override
  Future<void> connect(String myUserId) async {
    await _closeAll();

    debugPrint('[calling] connect: listening on calls:$myUserId');
    final channel = _client.channel('calls:$myUserId');
    channel
        .onBroadcast(
      event: _broadcastEvent,
      callback: (payload) {
        debugPrint('[calling] RAW broadcast received: $payload');
        _controller.add(_unwrap(payload));
      },
    )
        .subscribe((status, [error]) {
      debugPrint('[calling] inbox status: $status $error');
    });

    _inbox = channel;
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic> raw) {
    dynamic body = raw['body'];
    final inner = raw['payload'];
    if (body == null && inner is Map) body = inner['body'];
    if (body is Map) return Map<String, dynamic>.from(body);
    return Map<String, dynamic>.from(raw);
  }

  @override
  Future<void> send(
      String toUserId,
      String event,
      Map<String, dynamic> data,
      ) async {
    debugPrint('[calling] SEND $event -> $toUserId');
    final channel =
    await _outbox.putIfAbsent(toUserId, () => _openOutbox(toUserId));
    final res = await channel.sendBroadcastMessage(
      event: _broadcastEvent,
      payload: {
        'body': {'event': event, ...data},
      },
    );
    debugPrint('[calling] SEND result: $res');
  }

  Future<RealtimeChannel> _openOutbox(String toUserId) {
    final done = Completer<RealtimeChannel>();
    final channel = _client.channel('calls:$toUserId');

    channel.subscribe((status, [error]) {
      debugPrint('[calling] outbox status: $status $error');
      if (done.isCompleted) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        done.complete(channel);
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        done.completeError(error ?? 'Could not reach $toUserId');
      }
    });

    return done.future.timeout(const Duration(seconds: 8)).catchError((e) {
      _outbox.remove(toUserId);
      debugPrint('[calling] outbox failed: $e');
      throw e;
    });
  }

  @override
  Future<void> release(String peerId) async {
    final pending = _outbox.remove(peerId);
    if (pending == null) return;
    try {
      final channel = await pending;
      await _client.removeChannel(channel);
    } catch (_) {}
  }

  Future<void> _closeAll() async {
    final inbox = _inbox;
    _inbox = null;
    if (inbox != null) await _client.removeChannel(inbox);
    for (final peer in _outbox.keys.toList()) {
      await release(peer);
    }
  }

  @override
  Future<void> dispose() async {
    await _closeAll();
    await _controller.close();
  }
}