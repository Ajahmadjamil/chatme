import 'dart:async';
import 'dart:io';

import 'package:chatme/features/voice/widget/voice_message_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/time_formatter.dart';
import '../screens/full_screen_image.dart';

class MessageBubble extends ConsumerWidget {
  final String text;
  final DateTime time;
  final bool isMe;
  final String status;
  final VoidCallback? onLongPress;
  final String? senderName;
  final String messageType;
  final String? mediaUrl;
  final int? durationSeconds;
  final VoidCallback? onStopLiveLocation;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback? onToggleSelect;

  // NEW: reply support
  final dynamic repliedMessage; // the MessageModel this one replies to, or null
  final VoidCallback? onSwipeReply; // called when the user swipes the bubble
  final String? repliedSenderName;
  const MessageBubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
    this.status = 'sent',
    this.senderName,
    this.onLongPress,
    this.messageType = 'text',
    this.mediaUrl,
    this.durationSeconds,
    this.onStopLiveLocation,
    this.selectionMode = false,
    this.isSelected = false,
    this.onToggleSelect,
    this.repliedMessage,
    this.onSwipeReply,
    this.repliedSenderName,
  });

  static const Color _sentColor = Color(0xFFDCF8C6);
  static const Color _receivedColor = Colors.white;

  // Short one-line preview for the quoted reply bubble
  String _previewFor(dynamic msg) {
    switch (msg.messageType as String) {
      case 'image':
        return '📷 Photo';
      case 'sticker':
        return '😊 Sticker';
      case 'voice':
        return '🎤 Voice message';
      case 'file':
        return '📎 ${msg.content}';
      case 'location':
        return '📍 Location';
      case 'deleted':
        return 'This message was deleted';
      default:
        return msg.content as String;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).preset;

    if (messageType == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: p.textGrey.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: p.textGrey),
        ),
      );
    }

    // NEW: a reply bubble must never shrink to just the text width,
    // otherwise the quoted box and the time look squeezed.
    final bool hasReply = repliedMessage != null;
    // NEW: for text replies, let the quoted box stretch to the bubble width.
    // (Only text / deleted, because those are safe inside IntrinsicWidth.)
    final bool stretchQuote =
        hasReply && (messageType == 'text' || messageType == 'deleted');

    final Widget bubbleContent = Column(
      crossAxisAlignment:
      stretchQuote ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
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

        // ===== NEW: Quoted reply preview =====
        if (repliedMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: p.primary, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (repliedSenderName != null)
                  Text(
                    repliedSenderName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: p.primary,
                    ),
                  ),
                Text(
                  _previewFor(repliedMessage),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: p.textGrey),
                ),
              ],
            ),
          ),
        // ===== END Quoted reply preview =====

        // ===== DELETED MESSAGE =====
        if (messageType == 'deleted')
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 15, color: p.textGrey),
                const SizedBox(width: 6),
                Text(
                  'This message was deleted',
                  style: TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: p.textGrey,
                  ),
                ),
              ],
            ),
          ),
        // ===== END DELETED MESSAGE =====

        if (messageType == 'image' && mediaUrl != null)
          GestureDetector(
            onTap: () {
              if (selectionMode) {
                onToggleSelect?.call();
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullscreenImageScreen(imageUrl: mediaUrl!),
                ),
              );
            },
            onDoubleTap: onToggleSelect,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Image.network(
                    mediaUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
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
        // ===== STICKER (plain image, no download needed — Giphy hosts it) =====
        if (messageType == 'sticker' && mediaUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Image.network(
              mediaUrl!,
              width: 130,
              height: 130,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  width: 130,
                  height: 130,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
              errorBuilder: (context, error, stack) => const SizedBox(
                width: 130,
                height: 130,
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        // ===== END STICKER =====
        if (messageType == 'voice' && mediaUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 2),
            child: VoiceMessagePlayer(
              audioUrl: mediaUrl!,
              durationSeconds: durationSeconds ?? 0,
              isMe: isMe,
            ),
          ),

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
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
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

        if (messageType != 'voice' && messageType != 'deleted' && messageType != 'sticker')
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
                color: isMe ? p.myBubbleText.withOpacity(0.7) : p.textGrey,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 3),
              _StatusTicks(status: status),
            ],
          ],
        ),
      ],
    );

    return GestureDetector(
      onLongPress: onLongPress,
      onDoubleTap: onToggleSelect,
      // NEW: swipe left/right a little to reply, like WhatsApp
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > 150 && messageType != 'deleted') {
          onSwipeReply?.call();
        }
      },
      child: Stack(
        children: [
          Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              constraints: BoxConstraints(
                // NEW: reply bubbles are never narrower than 150
                minWidth: hasReply ? 150 : 0,
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? p.primary.withOpacity(0.18)
                    : (isMe ? p.myBubble : p.otherBubble),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(10),
                  topRight: const Radius.circular(10),
                  bottomLeft: Radius.circular(isMe ? 10 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 10),
                ),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 4),
              // NEW: IntrinsicWidth only for text replies (quote fills bubble)
              child: stretchQuote ? IntrinsicWidth(child: bubbleContent) : bubbleContent,
            ),
          ),
          if (selectionMode)
            Positioned(
              left: isMe ? null : 2,
              right: isMe ? 2 : null,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 3),
                    ],
                  ),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onToggleSelect?.call(),
                    activeColor: p.primary,
                    shape: const CircleBorder(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _staticMapUrlFrom(String mapUrl) {
  final uri = Uri.parse(mapUrl);
  final coords = uri.queryParameters['q'];
  if (coords == null) return '';
  return 'https://staticmap.openstreetmap.de/staticmap.php'
      '?center=$coords&zoom=15&size=440x260&markers=$coords,red-pushpin';
}

Future<void> _downloadAndOpenFile(String url, String fileName) async {
  final response = await http.get(Uri.parse(url));
  final tempDir = await getTemporaryDirectory();
  final localFile = File('${tempDir.path}/$fileName');
  await localFile.writeAsBytes(response.bodyBytes);
  await OpenFile.open(localFile.path);
}

class _LiveLocationFooter extends StatefulWidget {
  final String label;
  final DateTime sentAt;
  final int? totalSeconds;
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
          Text(statusText,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
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
    final color = status == 'read' ? const Color(0xFF34B7F1) : Colors.grey;
    return Icon(Icons.done_all, size: 15, color: color);
  }
}