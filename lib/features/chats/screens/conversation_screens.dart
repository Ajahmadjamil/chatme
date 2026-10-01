import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/app_haptics.dart';
import '../../Auto Clear Chat/provider.dart';
import '../../Auto Clear Chat/widget/auto_clear_sheet.dart';
import '../../chat lock/chat_lock_actions.dart';
import '../../chat lock/provider.dart';
import '../../voice/provider/voice_recorder_provider.dart';
import '../../voice/services/voice_recorder.dart';
import '../../voice/widget/voice_record_widgets.dart';
import '../providers/chat_actions_provider.dart';
import '../providers/chat_list_provider.dart';
import '../providers/chat_wallpaper_provider.dart';
import '../providers/message_provider.dart';
import '../providers/group_members_provider.dart';
import '../widgets/message_bubble.dart';
import 'forward_screen.dart';
import 'image_preview_view.dart';
import '../../../core/shared/widgets/app_skeletons.dart';
import '../../../core/shared/widgets/user_avatar.dart';
import '../../auth/Profile/Screens/user_profile_screen.dart';
import '../../../core/navigation/app_nav.dart';
class ConversationScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String otherUserName;
  final String? otherUserId;
  final String? avatarUrl;
  final bool isGroup;


  const ConversationScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    this.otherUserId,
    this.avatarUrl,
    this.isGroup = false,
  });

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  bool _showAttachPanel = false; // controls the smooth attach panel
  Timer? _autoClearTimer;
  final Set<String> _selectedMessageIds = {};
  bool get _isSelectionMode => _selectedMessageIds.isNotEmpty;
  static const int _maxRecordSeconds = 300; //5min
  static const int _maxFileBytes = 5 * 1024 * 1024; // 5 MB
  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;
  String? _resolvedOtherUserId;
  String? _resolvedAvatarUrl;
  dynamic _replyingTo; // MessageModel being replied to

  String? get _peerUserId => widget.otherUserId ?? _resolvedOtherUserId;
  String? get _peerAvatarUrl => widget.avatarUrl ?? _resolvedAvatarUrl;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(chatActionsProvider).markMessagesAsRead(widget.chatId);
      if (mounted) ref.invalidate(chatListProvider);
      if (!widget.isGroup) await _resolvePeerProfile();
    });
    // Rebuild UI whenever text changes, so mic <-> send icon toggles correctly
    _messageController.addListener(() => setState(() {}));

    // Opportunistic cleanup; DB pg_cron also purges every 5 minutes
    _cleanupExpiredMessages();
    _autoClearTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _cleanupExpiredMessages();
    });
  }

  Future<void> _resolvePeerProfile() async {
    if (widget.otherUserId != null && widget.avatarUrl != null) return;
    try {
      final row = await Supabase.instance.client
          .from('chat_members')
          .select('user_id, profiles!inner(avatar_url)')
          .eq('chat_id', widget.chatId)
          .neq('user_id', _currentUserId)
          .maybeSingle();
      if (!mounted || row == null) return;
      setState(() {
        _resolvedOtherUserId = row['user_id'] as String?;
        final profiles = row['profiles'];
        if (profiles is Map) {
          _resolvedAvatarUrl = profiles['avatar_url'] as String?;
        }
      });
    } catch (_) {}
  }

  void _openPeerProfile() {
    final userId = _peerUserId;
    if (userId == null || userId.isEmpty) return;
    AppNav.push(
      context,
      UserProfileScreen(
          userId: userId,
          fallbackName: widget.otherUserName,
        ),
    );
  }

  @override
  void dispose() {
    _autoClearTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _cleanupExpiredMessages() async {
    final deletedCount =
    await ref.read(autoClearServiceProvider).deleteExpiredMessages(widget.chatId);

    // Only refresh the message list if something was actually deleted,
    // so the loading spinner doesn't flash every minute for no reason
    if (mounted && deletedCount > 0) {
      ref.invalidate(messagesProvider(widget.chatId));
    }
  }
  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        return;
      }
      if (_selectedMessageIds.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You can forward up to 5 messages')),
        );
        return;
      }
      _selectedMessageIds.add(messageId);
    });
  }

  void _exitSelectionMode() {
    setState(() => _selectedMessageIds.clear());
  }

  Future<void> _forwardSelectedMessages() async {
    // Grab the currently loaded messages so we can copy the selected ones
    final currentMessages = ref.read(messagesProvider(widget.chatId)).value;
    if (currentMessages == null) return;

    final selectedMessages =
    currentMessages.where((m) => _selectedMessageIds.contains(m.id)).toList();
    if (selectedMessages.isEmpty) return;

    final targetChatId = await AppNav.push<String>(
      context,
      const ForwardScreen(),
    );

    if (targetChatId == null || !mounted) return;

    for (final msg in selectedMessages) {
      await ref.read(chatActionsProvider).forwardMessage(
        targetChatId: targetChatId,
        message: msg,
      );
    }

    _exitSelectionMode();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message forwarded')),
      );
    }
  }

  // AppBar shown while messages are selected for forwarding
  PreferredSizeWidget _buildSelectionAppBar() {
    final p = ref.read(themeProvider).palette;
    return AppBar(
      backgroundColor: p.header,
      foregroundColor: AppColors.headerForeground,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: Text('${_selectedMessageIds.length} selected'),
      actions: [
        IconButton(
          icon: const Icon(Icons.forward),
          onPressed: _forwardSelectedMessages,
        ),
      ],
    );
  }

  Future<void> _openAutoClearSheet() async {
    final currentMinutes =
    await ref.read(autoClearServiceProvider).getAutoClearMinutes(widget.chatId);

    if (!mounted) return;

    showAutoClearSheet(
      context: context,
      currentMinutes: currentMinutes,
      onSelected: (minutes) async {
        await ref.read(autoClearServiceProvider).setAutoClearMinutes(widget.chatId, minutes);
      },
    );
  }
  // Called when user presses and holds the mic button
  Future<void> _startVoiceRecording() async {
    final started = await ref.read(voiceRecorderProvider.notifier).start();
    AppHaptics.error();
    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mic permission denied or failed to start')),
      );
    }
  }

  // Called when user lifts the finger (or the time limit is reached)
  Future<void> _stopVoiceRecording() async {
    final result = await ref.read(voiceRecorderProvider.notifier).stop();
    if (!mounted || result == null) return;
    AppHaptics.messageSent();

    await ref.read(chatActionsProvider).sendVoiceMessage(
      chatId: widget.chatId,
      audioFile: File(result.filePath),
      durationSeconds: result.durationSeconds,
    );
  }

  // Slide left or trash button: throw the recording away
  Future<void> _cancelVoiceRecording() async {
    await ref.read(voiceRecorderProvider.notifier).cancel();
    AppHaptics.warning();
  }

  void _lockVoiceRecording() {
    AppHaptics.lock();
    ref.read(voiceRecorderProvider.notifier).lock();
  }

  // Helper to format seconds as m:ss for the live timer
  String _formatRecordTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1280,
    );
    if (pickedFile == null) return;

    final imageFile = File(pickedFile.path);

    // 5 MB limit check
    final int fileSize = await imageFile.length();
    if (fileSize > _maxFileBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File is too large. Maximum size is 5 MB')),
      );
      return;
    }

    if (!mounted) return;
    AppHaptics.messageSent();

    // Show preview screen first, wait for the caption (or null if cancelled)
    final caption = await AppNav.push<String>(
      context,
      ImagePreviewScreen(imageFile: imageFile),
    );

    // If user pressed back instead of send, caption will be null -> do nothing
    if (caption == null) return;

    await ref.read(chatActionsProvider).sendImageMessage(
      chatId: widget.chatId,
      imageFile: imageFile,
      caption: caption,
    );
  }
  void _toggleAttachPanel() {
    FocusScope.of(context).unfocus(); // hide keyboard first, like WhatsApp
    setState(() => _showAttachPanel = !_showAttachPanel);
  }
  Future<void> _pickAndSendFile() async {
    final PlatformFile? pickedFile = await FilePicker.pickFile();
    if (pickedFile == null || pickedFile.path == null) return;

    final file = File(pickedFile.path!);
    final fileName = pickedFile.name;

    // 5 MB size check, same rule as images
    final int fileSize = await file.length();
    if (fileSize > _maxFileBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File is too large. Maximum size is 5 MB')),
      );
      return;
    }

    AppHaptics.messageSent();
    await ref.read(chatActionsProvider).sendFileMessage(
      chatId: widget.chatId,
      file: file,
      fileName: fileName,
    );
  }
  // First step: "Share current location" or "Share live location"
  void _showLocationOptionsSheet() {
    final p = ref.read(themeProvider).palette;
    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Share your location',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: p.textMain),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.location_on, color: Colors.redAccent),
                title: const Text('Share current location'),
                subtitle: const Text('Sends a single pin'),
                onTap: () {
                  Navigator.pop(context);
                  _sendCurrentLocation(null); // null = not live
                },
              ),
              ListTile(
                leading: const Icon(Icons.location_searching, color: Colors.green),
                title: const Text('Share live location'),
                subtitle: const Text('Choose how long, then send'),
                onTap: () {
                  Navigator.pop(context);
                  _showLiveLocationDurationSheet();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

// Second step (only for live location): pick a duration, then press Send
  void _showLiveLocationDurationSheet() {
    int? selectedMinutes; // holds the user's pick until they press Send
    final p = ref.read(themeProvider).palette;

    showModalBottomSheet(
      context: context,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        // StatefulBuilder lets this sheet remember which option is selected
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget durationTile(String label, int minutes) {
              final bool isSelected = selectedMinutes == minutes;
              return ListTile(
                leading: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isSelected ? p.accent : p.icon,
                ),
                title: Text(label),
                onTap: () {
                  setSheetState(() => selectedMinutes = minutes);
                },
              );
            }

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Share live location for...',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16, color: p.textMain),
                    ),
                  ),
                  durationTile('15 minutes', 15),
                  durationTile('1 hour', 60),
                  durationTile('8 hours', 480),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        // Send stays disabled until a duration is picked
                        onPressed: selectedMinutes == null
                            ? null
                            : () {
                          Navigator.pop(context);
                          _sendCurrentLocation(selectedMinutes);
                        },
                        child: const Text('Send'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

// liveMinutes == null means a one-time (non-live) location
  Future<void> _sendCurrentLocation(int? liveMinutes) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    AppHaptics.messageSent();

    await ref.read(chatActionsProvider).sendLocationMessage(
      chatId: widget.chatId,
      latitude: position.latitude,
      longitude: position.longitude,
      liveDurationMinutes: liveMinutes,
    );
  }

// Called when the sender taps "Stop sharing" on their own live location
  Future<void> _stopLiveLocation(String messageId) async {
    await ref.read(chatActionsProvider).stopLiveLocation(messageId);
    ref.invalidate(messagesProvider(widget.chatId));
  }

// Ek option ka button (gol icon + neeche naam)
  Widget _attachOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final p = ref.read(themeProvider).palette;
    return InkWell(
      onTap: () {
        AppHaptics.tap();
        onTap();
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: p.primary.withOpacity(0.12),
            child: Icon(icon, color: p.primary, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12.5, color: p.textMain)),
        ],
      ),
    );
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }
  // The actual panel content (grid of options)
  Widget _buildAttachPanel() {
    final p = ref.read(themeProvider).palette;
    return Container(
      color: p.surface,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        children: [
          _attachOption(
            icon: Icons.photo_camera,
            label: 'Camera',
            onTap: () {
              setState(() => _showAttachPanel = false);
              _pickAndSendImage(ImageSource.camera);
            },
          ),
          _attachOption(
            icon: Icons.photo_library,
            label: 'Gallery',
            onTap: () {
              setState(() => _showAttachPanel = false);
              _pickAndSendImage(ImageSource.gallery);
            },
          ),
          _attachOption(
            icon: Icons.insert_drive_file,
            label: 'File',
            onTap: () {
              setState(() => _showAttachPanel = false);
              _pickAndSendFile();
            },
          ),
          _attachOption(
            icon: Icons.location_on,
            label: 'Location',
            onTap: () {
              setState(() => _showAttachPanel = false);
              _showLocationOptionsSheet();
            },
          ),
          // _attachOption(
          //   icon: Icons.person,
          //   label: 'Contact',
          //   onTap: () {
          //     setState(() => _showAttachPanel = false);
          //     _showComingSoon();
          //   },
          // ),
        ],
      ),
    );
  }
  Future<void> _sendMessage() async {
    if (_isSending) return; // block double-tap

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final replyId = _replyingTo?.id as String?;

    setState(() {
      _isSending = true;
      _replyingTo = null;
    });
    AppHaptics.messageSent();
    _messageController.clear();

    try {
      await ref.read(chatActionsProvider).sendMessage(
            chatId: widget.chatId,
            content: text,
            replyToId: replyId,
          );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startReply(dynamic msg, {String? senderName}) {
    AppHaptics.select();
    setState(() {
      _replyingTo = msg;
      _showAttachPanel = false;
    });
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  String _replyAuthorName(dynamic msg, Map<String, String> memberNames) {
    if (msg.senderId == _currentUserId) return 'You';
    if (widget.isGroup) {
      return memberNames[msg.senderId] ?? 'Member';
    }
    return widget.otherUserName;
  }

  String _replyPreviewFor(dynamic msg) {
    switch (msg.messageType as String?) {
      case 'image':
        return 'Photo';
      case 'voice':
        return 'Voice message';
      case 'file':
        final name = (msg.content as String?)?.trim() ?? '';
        return name.isEmpty ? 'File' : name;
      case 'location':
        return 'Location';
      default:
        final t = (msg.content as String?)?.trim() ?? '';
        return t.isEmpty ? 'Message' : t;
    }
  }
  // Long press: Reply for everyone; Edit/Delete only on my messages
  Future<void> _showMessageOptions(
    dynamic msg, {
    String? senderName,
  }) async {
    if (msg.messageType == 'system') return;

    AppHaptics.medium();
    final isMine = msg.senderId == _currentUserId;

    final action = await AppDialogs.messageOptions(
      context,
      canReply: true,
      canEdit: isMine && msg.messageType == 'text',
      canDelete: isMine,
    );
    if (action == null || !mounted) return;

    switch (action) {
      case MessageAction.reply:
        _startReply(msg, senderName: senderName);
      case MessageAction.edit:
        await _editMessage(msg);
      case MessageAction.delete:
        await _deleteMessage(msg);
    }
  }

  Future<void> _handleChatLockToggle(bool isLocked) async {
    if (isLocked) {
      final ok = await ChatLockActions.removeLock(
        context,
        ref,
        chatId: widget.chatId,
      );
      if (ok && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Chat unlocked')));
      }
      return;
    }

    final ok = await ChatLockActions.lockChat(
      context,
      ref,
      chatId: widget.chatId,
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chat locked')));
    }
  }
  Future<void> _pickChatWallpaper() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (pickedFile == null) return;

    try {
      await ref
          .read(chatWallpaperProvider(widget.chatId).notifier)
          .setWallpaper(File(pickedFile.path));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallpaper updated for everyone')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set wallpaper: $e')),
        );
      }
    }
  }

  Future<void> _editMessage(dynamic msg) async {
    final newText = await AppDialogs.editText(
      context,
      title: 'Edit message',
      initialText: msg.content,
    );

    // null = cancelled, empty or same text = nothing to save
    if (newText == null || newText.isEmpty || newText == msg.content) return;

    await ref.read(chatActionsProvider).editMessage(
      messageId: msg.id,
      newContent: newText,
    );
    ref.invalidate(messagesProvider(widget.chatId));
  }

  Future<void> _deleteMessage(dynamic msg) async {
    final confirmed = await AppDialogs.confirmDeleteMessage(context);
    if (!confirmed || !mounted) return;

    AppHaptics.warning();
    await ref.read(chatActionsProvider).deleteMessage(msg.id);
    ref.invalidate(messagesProvider(widget.chatId));
  }
  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final p = ref.watch(themeProvider).palette;
    // Auto-stop when the recording limit is reached
    ref.listen<VoiceRecorderState>(voiceRecorderProvider, (prev, next) {
      if (next.isRecording && next.seconds >= _maxRecordSeconds) {
        _stopVoiceRecording();
      }
    });
    final recorder = ref.watch(voiceRecorderProvider);
    final groupMembersAsync = widget.isGroup
        ? ref.watch(groupMembersProvider(widget.chatId))
        : null;
    final isLocked = ref.watch(chatLockProvider).lockedChatIds.contains(widget.chatId);
    final wallpaperUrl = ref.watch(chatWallpaperProvider(widget.chatId)).value;
    final glass = AppColors.isGlass && wallpaperUrl == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassAtmosphere(
      child: Scaffold(
      backgroundColor: glass ? Colors.transparent : p.chatBackground,
      extendBodyBehindAppBar: glass,
      appBar: _isSelectionMode ? _buildSelectionAppBar() : AppBar(
        backgroundColor: glass ? Colors.transparent : p.header,
        foregroundColor: AppColors.headerForeground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        flexibleSpace: glass
            ? const GlassImmersiveBar()
            : null,
        titleSpacing: 0,
        title: InkWell(
          onTap: widget.isGroup ? null : _openPeerProfile,
          child: Row(
            children: [
              UserAvatar(
                name: widget.otherUserName,
                avatarUrl: _peerAvatarUrl,
                radius: 18,
                backgroundColor: widget.isGroup
                    ? AppColors.secondary
                    : AppColors.avatarFor(widget.otherUserName).withValues(alpha: 0.2),
                foregroundColor: widget.isGroup
                    ? AppColors.primary
                    : AppColors.avatarFor(widget.otherUserName),
                fallbackIcon: widget.isGroup ? Icons.group : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.otherUserName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.headerForeground,
                      ),
                    ),
                    if (widget.isGroup && groupMembersAsync != null && groupMembersAsync.hasValue)
                      Text(
                        groupMembersAsync.value!.values.join(', '),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.headerForeground.withValues(alpha: 0.75),
                        ),
                      )
                    else if (!widget.isGroup)
                      Text(
                        'tap for contact info',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.headerForeground.withValues(alpha: 0.75),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppColors.headerForeground),
            onSelected: (value) {
              if (value == 'toggle_lock') {
                _handleChatLockToggle(isLocked);
              } else if (value == 'auto_clear') {
                _openAutoClearSheet();
              } else if (value == 'change_wallpaper') {
                _pickChatWallpaper();
              } else if (value == 'remove_wallpaper') {
                ref
                    .read(chatWallpaperProvider(widget.chatId).notifier)
                    .removeWallpaper();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_lock',
                child: Row(
                  children: [
                    Icon(
                      isLocked ? Icons.lock_open : Icons.lock_outline,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(isLocked ? 'Unlock chat' : 'Lock chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'auto_clear',
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 20),
                    SizedBox(width: 10),
                    Text('Auto-delete messages'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'change_wallpaper',
                child: Row(
                  children: [
                    Icon(Icons.wallpaper, size: 20),
                    SizedBox(width: 10),
                    Text('Change wallpaper'),
                  ],
                ),
              ),
              if (wallpaperUrl != null)
                const PopupMenuItem(
                  value: 'remove_wallpaper',
                  child: Row(
                    children: [
                      Icon(Icons.image_not_supported_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Remove wallpaper'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          if (wallpaperUrl != null) ...[
            Positioned.fill(
              child: Image.network(
                wallpaperUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            Positioned.fill(
              child: ColoredBox(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.42)
                    : Colors.white.withValues(alpha: 0.40),
              ),
            ),
          ],
          Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('Say hi 👋', style: TextStyle(color: Colors.grey)),
                    );
                  }
        
                  List<dynamic> sortedMessages = List.from(messages);
                  sortedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        
                  Map<String, String> memberNames = {};
                  if (groupMembersAsync != null && groupMembersAsync.hasValue) {
                    memberNames = groupMembersAsync.value!;
                  }
        
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: sortedMessages.length,
                    itemBuilder: (context, index) {
                      int realIndex = sortedMessages.length - 1 - index;
                      final msg = sortedMessages[realIndex];
                      final isMe = msg.senderId == _currentUserId;

                      String? senderName;
                      if (widget.isGroup && !isMe) {
                        senderName = memberNames[msg.senderId];
                      }

                      dynamic replied;
                      if (msg.replyToId != null) {
                        for (final m in sortedMessages) {
                          if (m.id == msg.replyToId) {
                            replied = m;
                            break;
                          }
                        }
                      }

                      return MessageBubble(
                        key: ValueKey(msg.id),
                        text: msg.content,
                        time: msg.createdAt,
                        isMe: isMe,
                        status: msg.status,
                        senderName: senderName,
                        messageType: msg.messageType,
                        mediaUrl: msg.mediaUrl,
                        durationSeconds: msg.durationSeconds,
                        onStopLiveLocation:
                            isMe ? () => _stopLiveLocation(msg.id) : null,
                        onLongPress: msg.messageType == 'system'
                            ? null
                            : () => _showMessageOptions(
                                  msg,
                                  senderName: senderName,
                                ),
                        onReply: msg.messageType == 'system'
                            ? null
                            : () => _startReply(msg, senderName: senderName),
                        selectionMode: _isSelectionMode,
                        isSelected: _selectedMessageIds.contains(msg.id),
                        onToggleSelect: () => _toggleMessageSelection(msg.id),
                        replyToName: replied == null
                            ? null
                            : _replyAuthorName(replied, memberNames),
                        replyToText: replied?.content as String?,
                        replyToType: replied?.messageType as String?,
                      );
                    },
                  );
                },
                loading: () => AppSkeletons.messages(),
                error: (err, stack) => Center(child: Text('Error: $err')),
              ),
            ),
            // ---- Input bar ----
            SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_replyingTo != null) _buildReplyBar(),
                  // Attach panel smoothly grows above the input bar
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: _showAttachPanel ? _buildAttachPanel() : const SizedBox(width: double.infinity),
                  ),
        
                  // Input row + lock hint bubble
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: double.infinity,
                        color: AppColors.isGlass
                            ? Colors.transparent
                            : p.surface,
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: recorder.isRecording
                                  ? _buildRecordingBar(recorder)
                                  : _buildTypingBar(),
                            ),
                            const SizedBox(width: 8),
                            _buildRightButton(recorder),
                          ],
                        ),
                      ),
        
                      // Lock hint floats above the mic while holding
                      if (recorder.isRecording && !recorder.isLocked)
                        Positioned(right: 10, bottom: 66, child: _buildLockHint()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
    ],
      ),
      ),
    );
  }
  Widget _buildReplyBar() {
    final msg = _replyingTo;
    if (msg == null) return const SizedBox.shrink();
    final p = ref.read(themeProvider).palette;
    final author = msg.senderId == _currentUserId
        ? 'You'
        : (widget.isGroup
            ? (ref.read(groupMembersProvider(widget.chatId)).value?[
                    msg.senderId] ??
                'Member')
            : widget.otherUserName);

    return Material(
      color: AppColors.isGlass ? Colors.transparent : p.surface,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: p.divider),
            left: BorderSide(color: p.primary, width: 4),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.reply, size: 18, color: p.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replying to $author',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _replyPreviewFor(msg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: p.textGrey),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 20, color: p.icon),
              onPressed: _cancelReply,
            ),
          ],
        ),
      ),
    );
  }

  // Left side of the input bar while recording
  Widget _buildRecordingBar(VoiceRecorderState recorder) {
    final p = ref.read(themeProvider).palette;
    final timerText = Text(
      _formatRecordTime(recorder.seconds),
      style: TextStyle(
        fontSize: 15,
        color: p.textMain,
        fontWeight: FontWeight.w500,
      ),
    );

    // Locked: trash button + timer + live waveform
    if (recorder.isLocked) {
      return SizedBox(
        height: 44,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _cancelVoiceRecording,
            ),
            timerText,
            const SizedBox(width: 12),
            Expanded(child: LiveWaveform(levels: recorder.levels)),
          ],
        ),
      );
    }

    // Still holding: red mic + timer + "Slide to cancel"
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.mic, color: Colors.red, size: 22),
          const SizedBox(width: 8),
          timerText,
          const Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chevron_left, size: 18, color: Colors.grey),
                SizedBox(width: 2),
                Text(
                  'Slide to cancel',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Left side of the input bar for normal typing
  Widget _buildTypingBar() {
    final p = ref.read(themeProvider).palette;
    final field = Container(
      constraints: const BoxConstraints(maxHeight: 120),
      decoration: AppColors.isGlass
          ? null
          : BoxDecoration(
              color: p.inputField,
              borderRadius: BorderRadius.circular(24),
            ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _messageController,
        minLines: 1,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Type a message...',
          hintStyle: TextStyle(color: p.icon),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(Icons.attach_file, color: p.primary),
          onPressed: () {
            AppHaptics.tap();
            _toggleAttachPanel();
          },
        ),
        Expanded(
          child: AppColors.isGlass
              ? GlassCard(
                  borderRadius: const BorderRadius.all(Radius.circular(24)),
                  shadow: false,
                  child: field,
                )
              : field,
        ),
      ],
    );
  }

  // Right side button: send (locked / typed text) or mic
  Widget _buildRightButton(VoiceRecorderState recorder) {
    // Locked recording: send button
    if (recorder.isRecording && recorder.isLocked) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.accent,
        child: IconButton(
          icon: Icon(Icons.send, color: AppColors.onPrimary, size: 20),
          onPressed: _stopVoiceRecording,
        ),
      );
    }

    // Text typed: normal send button
    if (!recorder.isRecording && _messageController.text.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.accent,
        child: IconButton(
          icon: Icon(Icons.send, color: AppColors.onPrimary, size: 20),
          onPressed: _sendMessage,
        ),
      );
    }

    // Otherwise: mic button with hold / lock / cancel gestures
    return VoiceMicButton(
      isRecording: recorder.isRecording,
      onStart: _startVoiceRecording,
      onLock: _lockVoiceRecording,
      onCancel: _cancelVoiceRecording,
      onSend: _stopVoiceRecording,
    );
  }

  // Small "lock" bubble shown above the mic while holding
  Widget _buildLockHint() {
    final p = ref.read(themeProvider).palette;
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 20, color: Colors.grey),
          SizedBox(height: 4),
          Icon(Icons.keyboard_arrow_up, size: 20, color: Colors.grey),
        ],
      ),
    );
  }
}
