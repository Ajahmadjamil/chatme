import 'dart:async';
import 'dart:io';

import '/features/voice/widget/voice_message_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/shared/widgets/app_skeletons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/time_formatter.dart';
import '../screens/full_screen_image.dart';
import '../../../core/navigation/app_nav.dart';

class MessageBubble extends ConsumerWidget {
  final String text;
  final DateTime time;
  final bool isMe;
  final String status; // 'sent' | 'delivered' | 'read'
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;
  final String? senderName; // only used in group chats, for messages not sent by me
  final String messageType;
  final String? mediaUrl;
  final int? durationSeconds;
  final VoidCallback? onStopLiveLocation;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onToggleSelect;
  final String? replyToName;
  final String? replyToText;
  final String? replyToType;

  const MessageBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
    this.status = 'sent',
    this.senderName,
    this.onLongPress,
    this.onReply,
    this.messageType = 'text',
    this.mediaUrl,
    this.durationSeconds,
    this.onStopLiveLocation,
    this.selectionMode = false,
    this.isSelected = false,
    this.onToggleSelect,
    this.replyToName,
    this.replyToText,
    this.replyToType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).palette;
    // System/info messages (like "Auto-delete turned on") get a simple
    // centered pill instead of a normal chat bubble
    if (messageType == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: p.textGrey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: p.textGrey),
        ),
      );
    }

    final bubble = GestureDetector(
      onLongPress: onLongPress,
      onDoubleTap: onToggleSelect,
      child: Stack(
        children: [
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color: isMe ? p.myBubble : p.otherBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(10),
                  topRight: const Radius.circular(10),
                  bottomLeft: Radius.circular(isMe ? 10 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 10),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 1,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (senderName != null && !isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        senderName!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),

                  if (replyToText != null || replyToType != null)
                    _ReplyQuote(
                      name: replyToName ?? 'Message',
                      preview: _replyPreviewLabel(
                        replyToType: replyToType,
                        replyToText: replyToText,
                      ),
                      accent: p.primary,
                      isMine: isMe,
                    ),

                  // ===== IMAGE (UI updated — fixed compact box, WhatsApp-style) =====
                  if (messageType == 'image' && mediaUrl != null)
                  GestureDetector(
                    onTap: () {
                      if (selectionMode) {
                        onToggleSelect?.call();
                        return;
                      }
                      AppNav.push(
                        context,
                        FullscreenImageScreen(imageUrl: mediaUrl!),
                      );
                    },
                    onDoubleTap: onToggleSelect,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        // Fixed square-ish box, same size every time (like WhatsApp).
                        // This stops the image from stretching to the full bubble width.
                        child: SizedBox(
                          width: 220,
                          height: 220,
                          child: Image.network(
                            mediaUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return AppSkeletons.imagePlaceholder();
                            },
                            errorBuilder: (context, error, stack) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // ===== END IMAGE =====
                // ===== VOICE MESSAGE =====
                if (messageType == 'voice' && mediaUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, top: 2),
                    child: VoiceMessagePlayer(
                      audioUrl: mediaUrl!,
                      durationSeconds: durationSeconds ?? 0,
                      isMe: isMe,
                    ),
                  ),
                // ===== END VOICE MESSAGE =====
                // ===== FILE MESSAGE =====
                if (messageType == 'file' && mediaUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, top: 2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        if (selectionMode) {
                          onToggleSelect?.call();
                          return;
                        }
                        _downloadAndOpenFile(mediaUrl!, text);
                      },
                      onDoubleTap: onToggleSelect,
                      child: Container(
                        width: 220,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.insert_drive_file, color: Colors.blueGrey),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    text, // file name was saved as the message content
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Tap to open',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
        // ===== END FILE MESSAGE =====
        
        // ===== LOCATION MESSAGE =====
                if (messageType == 'location' && mediaUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, top: 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 220,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                if (selectionMode) {
                                  onToggleSelect?.call();
                                  return;
                                }
                                launchUrl(
                                  Uri.parse(mediaUrl!),
                                  mode: LaunchMode.externalApplication,
                                );
                              },
                              onDoubleTap: onToggleSelect,
                              child: SizedBox(
                                height: 130,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      _staticMapUrlFrom(mediaUrl!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Center(
                                          child: Icon(Icons.map, color: Colors.grey, size: 32),
                                        ),
                                      ),
                                    ),
                                    const Center(
                                      child: Icon(Icons.location_on, color: Colors.redAccent, size: 34),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Status line + countdown + Stop button (mine only)
                            _LiveLocationFooter(
                              label: text,
                              sentAt: time,
                              totalSeconds: durationSeconds,
                              showStopButton: isMe,
                              onStop: onStopLiveLocation,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
        // ===== END LOCATION MESSAGE =====
        
                // Text is hidden for voice messages (player replaces it)
                // and for pure media without a caption.
                if (messageType != 'voice' &&
                    messageType != 'image' &&
                    messageType != 'file' &&
                    messageType != 'location')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        color: isMe ? p.myBubbleText : p.otherBubbleText,
                      ),
                    ),
                  )
                else if (messageType == 'image' &&
                    text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.3,
                        color: isMe ? p.myBubbleText : p.otherBubbleText,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatMessageTime(time),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe
                            ? p.myBubbleText.withValues(alpha: 0.7)
                            : p.textGrey,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      _StatusTicks(status: status),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
          if (isSelected)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: p.primary.withValues(alpha: 0.12),
                ),
              ),
            ),
        ],
      ),
    );

    if (onReply == null || selectionMode) return bubble;

    // WhatsApp-style: swipe right to reply (bubble springs back).
    return Dismissible(
      key: ValueKey('swipe-reply-$time-${text.hashCode}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onReply?.call();
        return false;
      },
      background: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: p.primary.withValues(alpha: 0.15),
            child: Icon(Icons.reply, size: 18, color: p.primary),
          ),
        ),
      ),
      child: bubble,
    );
  }
}

String _replyPreviewLabel({String? replyToType, String? replyToText}) {
  switch (replyToType) {
    case 'image':
      return 'Photo';
    case 'voice':
      return 'Voice message';
    case 'file':
      return replyToText?.trim().isNotEmpty == true ? replyToText! : 'File';
    case 'location':
      return 'Location';
    default:
      final t = replyToText?.trim() ?? '';
      return t.isEmpty ? 'Message' : t;
  }
}

class _ReplyQuote extends StatelessWidget {
  final String name;
  final String preview;
  final Color accent;
  final bool isMine;

  const _ReplyQuote({
    required this.name,
    required this.preview,
    required this.accent,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: isMine ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: accent, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}
// Turns the saved "https://www.google.com/maps?q=lat,lng" link into a
// small static map image URL, using latitude/longitude from it
String _staticMapUrlFrom(String mapUrl) {
  final uri = Uri.parse(mapUrl);
  final coords = uri.queryParameters['q']; // e.g. "24.8607,67.0011"

  if (coords == null) return ''; // will show the grey error box instead

  return 'https://staticmap.openstreetmap.de/staticmap.php'
      '?center=$coords&zoom=15&size=440x260&markers=$coords,red-pushpin';
}
// Downloads the file to a temp folder, then opens it with the
// phone's own app for that file type (PDF viewer, Word, etc.)
Future<void> _downloadAndOpenFile(String url, String fileName) async {
  final response = await http.get(Uri.parse(url));

  final tempDir = await getTemporaryDirectory();
  final localFile = File('${tempDir.path}/$fileName');
  await localFile.writeAsBytes(response.bodyBytes);

  await OpenFile.open(localFile.path);
}
// Shows the location label under the map, plus a live countdown and
// "Stop sharing" button while my own live share is still active.
class _LiveLocationFooter extends StatefulWidget {
  final String label; // 'Location' | 'Live location' | 'Live location ended'
  final DateTime sentAt;
  final int? totalSeconds; // total share length; null/0 = not live
  final bool showStopButton;
  final VoidCallback? onStop;

  const _LiveLocationFooter({
    required this.label,
    required this.sentAt,
    required this.totalSeconds,
    required this.showStopButton,
    required this.onStop,
  });

  @override
  State<_LiveLocationFooter> createState() => _LiveLocationFooterState();
}

class _LiveLocationFooterState extends State<_LiveLocationFooter> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresh the countdown text once a minute
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasDuration = widget.totalSeconds != null && widget.totalSeconds! > 0;
    final DateTime expiresAt = widget.sentAt.add(Duration(seconds: widget.totalSeconds ?? 0));
    final bool isLive =
        widget.label == 'Live location' && hasDuration && DateTime.now().isBefore(expiresAt);

    String statusText;
    if (isLive) {
      final remaining = expiresAt.difference(DateTime.now());
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      statusText = hours > 0 ? 'Live · ${hours}h ${minutes}m left' : 'Live · ${minutes}m left';
    } else if (widget.label == 'Live location') {
      statusText = 'Live location ended';
    } else {
      statusText = widget.label;
    }

    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(statusText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
          if (isLive && widget.showStopButton)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                ),
                onPressed: widget.onStop,
                child: const Text('Stop sharing', style: TextStyle(fontSize: 12, color: Colors.red)),
              ),
            ),
        ],
      ),
    );
  }
}
class _StatusTicks extends StatelessWidget {
  final String status;
  const _StatusTicks({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == 'sent') {
      return const Icon(Icons.done, size: 15, color: Colors.grey);
    }
    final color = status == 'read' ? AppColors.readReceipt : AppColors.unreadReceipt;
    return Icon(Icons.done_all, size: 15, color: color);
  }
}
