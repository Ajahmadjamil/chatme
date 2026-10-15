import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Updates MY OWN last_seen timestamp, so others can see I'm online.
// Called on a timer, as long as some chat screen is open.
class OnlineStatusService {
  final supabase = Supabase.instance.client;

  Future<void> updateMyLastSeen() async {
    final myId = supabase.auth.currentUser!.id;
    await supabase
        .from('profiles')
        .update({'last_seen': DateTime.now().toUtc().toIso8601String()})
        .eq('id', myId);
  }
}

final onlineStatusServiceProvider = Provider<OnlineStatusService>((ref) {
  return OnlineStatusService();
});

// Streams one person's last_seen value live, so their status updates
// on screen the moment the heartbeat changes it in the database
final userLastSeenProvider =
StreamProvider.autoDispose.family<DateTime?, String>((ref, userId) {
  final supabase = Supabase.instance.client;

  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((rows) {
    if (rows.isEmpty) return null;
    final lastSeenText = rows.first['last_seen'] as String?;
    return lastSeenText != null ? DateTime.parse(lastSeenText) : null;
  });
});

// Turns a last_seen timestamp into "Online" or "Last seen ..." text
String formatOnlineStatus(DateTime? lastSeen) {
  if (lastSeen == null) return '';

  final now = DateTime.now().toUtc();
  final secondsAgo = now.difference(lastSeen).inSeconds;

  if (secondsAgo < 25) {
    return 'Online';
  }

  final diff = now.difference(lastSeen);
  if (diff.inMinutes < 1) return 'Last seen just now';
  if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
  return 'Last seen ${diff.inDays}d ago';
}