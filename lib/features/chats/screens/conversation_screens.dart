import 'dart:async';
import 'dart:io';
import 'package:enough_giphy_flutter/enough_giphy_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/shared/widgets/avatar_viewer_screen.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/app_animations.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/app_haptics.dart';
import '../../../core/utils/page_transitions.dart';
import '../../Auto Clear Chat/provider.dart';
import '../../Auto Clear Chat/widget/auto_clear_sheet.dart';
import '../../Home/home_view.dart';
import '../../auth/Profile/online_status_provider.dart';
import '../../auth/Profile/other_user_profile_provider.dart';
import '../../callings/controller/controller.dart';
import '../../callings/model/calling_model.dart';
import '../../chat lock/provider.dart';
import '../../chat lock/screens/enter_pin_view.dart';
import '../../chat lock/screens/set_pin_view.dart';
import '../../voice/provider/voice_recorder_provider.dart';
import '../../voice/services/voice_recorder.dart';
import '../../voice/widget/voice_record_widgets.dart';
import '../Groups/group_info_view.dart';
import '../Groups/providers.dart';
import '../providers/chat_actions_provider.dart';
import '../providers/chat_list_provider.dart';
import '../providers/chat_wallpaper_provider.dart';
import '../providers/message_provider.dart';
import '../providers/group_members_provider.dart';
import '../widgets/message_bubble.dart';
import 'contact_info_view.dart';
import 'forward_screen.dart';
import 'image_preview_view.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String otherUserName;
  final bool isGroup;
  final String? otherAvatarUrl;

  const ConversationScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    this.isGroup = false,
    this.otherAvatarUrl,
  });

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  // Used to animate only NEW messages (not old ones when scrolling)
  final Set<String> _seenMessageIds = {};
  bool _firstLoadDone = false;
  bool _isSending = false;
  bool _showAttachPanel = false; // controls the smooth attach panel
  Timer? _autoClearTimer;
  Timer? _heartbeatTimer;
  final Set<String> _selectedMessageIds = {};
  // Messages hidden instantly on screen while the server is still deleting them
  final Set<String> _hiddenMessageIds = {};
  bool get _isSelectionMode => _selectedMessageIds.isNotEmpty;
  static const int _maxRecordSeconds = 300; //5min
  static const int _maxFileBytes = 5 * 1024 * 1024; // 5 MB
  String get _currentUserId => Supabase.instance.client.auth.currentUser!.id;
  dynamic _replyingTo; // the message currently being replied to, or null
  final ScrollController _scrollController = ScrollController();
  bool _showScrollDown = false;
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 300;
      if (show != _showScrollDown) setState(() => _showScrollDown = show);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatActionsProvider).markMessagesAsRead(widget.chatId);
    });
    // Rebuild UI whenever text changes, so mic <-> send icon toggles correctly
    _messageController.addListener(() => setState(() {}));

    // Clean up already-expired messages now, then keep checking every minute
    _cleanupExpiredMessages();
    _autoClearTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _cleanupExpiredMessages();
    });
    _sendHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _sendHeartbeat();
    });
  }

  // Background timers: a dropped connection must not throw an unhandled
  // error — the next tick simply tries again
  Future<void> _sendHeartbeat() async {
    try {
      await ref.read(onlineStatusServiceProvider).updateMyLastSeen();
    } catch (e) {
      debugPrint('Heartbeat skipped (offline?): $e');
    }
  }

  @override
  void dispose() {
    _autoClearTimer?.cancel();
    _messageController.dispose();
    _heartbeatTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cleanupExpiredMessages() async {
    final int deletedCount;
    try {
      deletedCount =
      await ref.read(autoClearServiceProvider).deleteExpiredMessages(widget.chatId);
    } catch (e) {
      debugPrint('Expired-message cleanup skipped (offline?): $e');
      return;
    }

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

  // Opens the Group Info screen (only used for group chats)
  void _openGroupInfo() {
Navigator.push(context, PageTransitions.slideFromRight(GroupInfoScreen(chatId: widget.chatId)));}

  // NEW: Opens the Contact Info screen (only used for 1-on-1 chats)
  void _openContactInfo() {
    Navigator.push(context, PageTransitions.slideFromRight(ContactInfoScreen(chatId: widget.chatId)));
  }

  Future<void> _forwardSelectedMessages() async {
    // Grab the currently loaded messages so we can copy the selected ones
    final currentMessages = ref.read(messagesProvider(widget.chatId)).value;
    if (currentMessages == null) return;

    final selectedMessages =
    currentMessages.where((m) => _selectedMessageIds.contains(m.id)).toList();
    if (selectedMessages.isEmpty) return;

    final targetChatId = await Navigator.push<String>(
      context,
      PageTransitions.slideFromBottom<String>(const ForwardScreen()),
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
  // Starts an audio / video call with the other person of this 1-on-1 chat
  Future<void> _startCall(String peerId, String peerName, CallType type) async {
    final error = await ref.read(callControllerProvider.notifier).initiateCall(
      receiverId: peerId,
      channelId: widget.chatId,
      type: type,
      receiverName: peerName,
    );
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }
  // AppBar shown while messages are selected for forwarding
  PreferredSizeWidget _buildSelectionAppBar() {
    final p = ref.read(themeProvider).preset;
    return AppBar(
      backgroundColor: p.header,
      foregroundColor: Colors.white,
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
    if (started) {
      AppHaptics.recordStart();
    } else {
      AppHaptics.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mic permission denied or failed to start')),
        );
      }
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

  // Reply mein dikhane ke liye naam: apna ho to "You", warna sender ka naam
  String _nameFor(dynamic msg) {
    if (msg == null) return '';
    if (msg.senderId == _currentUserId) return 'You';
    if (widget.isGroup) {
      final names = ref.read(groupMembersProvider(widget.chatId)).value;
      return names?[msg.senderId] ?? 'Unknown';
    }
    return widget.otherUserName;
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
    final caption = await Navigator.push<String>(
      context,
      PageTransitions.fadeTransition<String>(ImagePreviewScreen(imageFile: imageFile)),
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
  Future<void> _openStickerPicker() async {
    final giphyApiKey = dotenv.env['GIPHY_API_KEY'] ?? '';

    if (giphyApiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giphy API key is missing')),
      );
      return;
    }

    final gif = await Giphy.getGif(
      context: context,
      apiKey: giphyApiKey,
      type: GiphyType.stickers, // stickers, not regular GIFs
    );

    if (gif == null || !mounted) return;

    // Giphy gives several image sizes — "original" is good quality for chat
    final stickerUrl = gif.images?.original?.url;
    if (stickerUrl == null) return;

    AppHaptics.messageSent();
    await ref.read(chatActionsProvider).sendStickerMessage(
      chatId: widget.chatId,
      stickerImageUrl: stickerUrl,
    );
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
    final p = ref.read(themeProvider).preset;
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
    final p = ref.read(themeProvider).preset;

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
  }

  // Ek option ka button (gol icon + neeche naam)
  Widget _attachOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final p = ref.read(themeProvider).preset;
    return InkWell(
      onTap: onTap,
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
    final p = ref.read(themeProvider).preset;
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
    if (_isSending) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    AppHaptics.messageSent();
    _messageController.clear();
    final replyId = _replyingTo?.id;
    setState(() => _replyingTo = null);

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

  Future<void> _showMessageOptions(dynamic msg) async {
    AppHaptics.medium();

    final bool isMine = msg.senderId == _currentUserId;
    final bool isDeleted = msg.messageType == 'deleted';

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              if (!isDeleted)
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Reply'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() => _replyingTo = msg);
                  },
                ),
              if (isMine && msg.messageType == 'text')
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _editMessage(msg);
                  },
                ),
              // Dusre ka message: sirf "Delete". Apna: "Delete for me"
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(isMine ? 'Delete for me' : 'Delete'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  AppHaptics.warning();
                  _deleteForMe(msg);
                },
              ),
              if (isMine && !isDeleted)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete for everyone',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    AppHaptics.warning();
                    _deleteForEveryone(msg);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleChatLockToggle(bool isLocked) async {
    final notifier = ref.read(chatLockProvider.notifier);

    if (isLocked) {
      final success = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => EnterPinScreen(
            chatId: widget.chatId,
            title: 'Unlock Chat',
            subtitle: 'Enter the PIN to remove the lock on this chat.',
          ),
        ),
      );
      if (success == true) {
        await notifier.removeLock(widget.chatId);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Chat unlocked')));
        }
      }
      return;
    }

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SetPinScreen(chatId: widget.chatId)),
    );
    if (created != true) return;

    // Already inside the chat, so don't ask for the PIN again right away
    notifier.markUnlocked(widget.chatId);

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Chat locked')));
    }
  }

  Future<void> _pickChatWallpaper() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    try {
      await ref.read(chatWallpaperActionsProvider).setWallpaper(
        widget.chatId,
        File(pickedFile.path),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to set wallpaper: $e')));
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
  }
  // Delete for me: hide instantly, server works in the background
  Future<void> _deleteForMe(dynamic msg) async {
    // 1) Hide right away so the UI feels instant
    setState(() => _hiddenMessageIds.add(msg.id));

    try {
      // 2) The stream updates itself, so no invalidate is needed
      await ref.read(chatActionsProvider).deleteForMe(msg.id);
    } catch (e) {
      // 3) Server failed: bring the message back and show the reason
      if (!mounted) return;
      setState(() => _hiddenMessageIds.remove(msg.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: $e')),
      );
    }
  }

  // Delete for everyone: the stream pushes the change to both devices
  Future<void> _deleteForEveryone(dynamic msg) async {
    try {
      await ref.read(chatActionsProvider).deleteForEveryone(msg.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final p = ref.watch(themeProvider).preset;
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
    final hasLeft = widget.isGroup &&
        (ref.watch(hasLeftGroupProvider(widget.chatId)).value ?? false);
    final wallpaperAsync = ref.watch(chatWallpaperStreamProvider(widget.chatId));
    final wallpaperPath = wallpaperAsync.whenOrNull(data: (url) => url); // now a URL, not a local path
    // Live name + photo for the header (falls back to the values passed in)
    final chatList = ref.watch(chatListProvider).value ?? [];
    final matches = chatList.where((c) => c.id == widget.chatId).toList();
    final liveChat = matches.isNotEmpty ? matches.first : null;
    final headerName = liveChat?.otherUserName ?? widget.otherUserName;
    final headerAvatarUrl = liveChat?.avatarUrl;
    final hasHeaderAvatar = headerAvatarUrl != null && headerAvatarUrl.isNotEmpty;
    // Online/offline status, only computed for 1-on-1 chats
    final otherProfileAsync = widget.isGroup
        ? null
        : ref.watch(otherUserProfileProvider(widget.chatId));
    final otherUserId = otherProfileAsync?.value?.id;
    final lastSeen = otherUserId != null
        ? ref.watch(userLastSeenProvider(otherUserId)).value
        : null;
    final statusText = formatOnlineStatus(lastSeen);

    return Scaffold(
      backgroundColor: p.chatBackground,
      appBar: _isSelectionMode
          ? _buildSelectionAppBar()
          : AppBar(
        backgroundColor: p.header,
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Group chats open Group Info, 1-on-1 chats open Contact Info
          onTap: widget.isGroup ? _openGroupInfo : _openContactInfo, // CHANGED
          child: Row(
            children: [
              GestureDetector(
                onTap: widget.otherAvatarUrl != null
                    ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AvatarViewerScreen(
                      imageUrl: widget.otherAvatarUrl!,
                      title: widget.otherUserName,
                    ),
                  ),
                )
                    : null,
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: widget.otherAvatarUrl != null
                      ? NetworkImage(widget.otherAvatarUrl!)
                      : null,
                  backgroundColor: widget.isGroup
                      ? Colors.teal.shade100
                      : avatarColorFor(widget.otherUserName),
                  child: widget.otherAvatarUrl == null
                      ? (widget.isGroup
                      ? const Icon(Icons.group, color: Colors.teal, size: 18)
                      : Text(
                    widget.otherUserName.isNotEmpty
                        ? widget.otherUserName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ))
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              // Header: chat ka naam (+ group members ki list)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      headerName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (widget.isGroup && groupMembersAsync != null && groupMembersAsync.hasValue)
                      Text(
                        groupMembersAsync.value!.values.join(', '),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      )
                    else if (!widget.isGroup && statusText.isNotEmpty)
                      Text(
                        statusText,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Call buttons: only for 1-on-1 chats (not groups)
          if (!widget.isGroup && otherUserId != null) ...[
            IconButton(
              tooltip: 'Audio call',
              icon: const Icon(Icons.call, color: Colors.white),
              onPressed: () =>
                  _startCall(otherUserId, headerName, CallType.audio),
            ),
            IconButton(
              tooltip: 'Video call',
              icon: const Icon(Icons.videocam, color: Colors.white),
              onPressed: () =>
                  _startCall(otherUserId, headerName, CallType.video),
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'toggle_lock') {
                _handleChatLockToggle(isLocked);
              } else if (value == 'auto_clear') {
                _openAutoClearSheet();
              } else if (value == 'change_wallpaper') {
                _pickChatWallpaper();
              } else if (value == 'remove_wallpaper') {
                ref.read(chatWallpaperActionsProvider).removeWallpaper(widget.chatId);
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

              // NEW: Change wallpaper
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

              // NEW: Remove wallpaper
              if (wallpaperPath != null)
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
          if (wallpaperPath != null)
            Positioned.fill(
              child: Image.network(
                wallpaperPath,
                fit: BoxFit.cover,
              ),
            ),
          if (wallpaperPath != null)
            Positioned.fill(
              // Soft white wash so text bubbles stay readable over any photo
              child: Container(color: Colors.white.withOpacity(0.45)),
            ),
          Column(
            children: [
              Expanded(
                child: Stack(
                 children: [
      messagesAsync.when(
                  data: (messages) {
                    // NEW: I left this group -> show a note instead of messages
                    if (hasLeft) {
                      return Center(
                        child: Text(
                          'You left this group',
                          style: TextStyle(color: p.textGrey),
                        ),
                      );
                    }

                    if (messages.isEmpty) {
                      return Center(
                        child: BounceIn(
                          child: const Text('Say hi 👋', style: TextStyle(color: Colors.grey, fontSize: 18)),
                        ),
                      );
                    }

                    // Skip messages I just deleted for me
                    List<dynamic> sortedMessages = messages
                        .where((m) => !_hiddenMessageIds.contains(m.id))
                        .toList();
                    sortedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
                    Map<String, dynamic> messagesById = {for (var m in sortedMessages) m.id: m};

                    Map<String, String> memberNames = {};
                    if (groupMembersAsync != null && groupMembersAsync.hasValue) {
                      memberNames = groupMembersAsync.value!;
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _seenMessageIds.addAll(sortedMessages.map<String>((m) => m.id as String));
                      _firstLoadDone = true;
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: sortedMessages.length,
                      itemBuilder: (context, index) {
                        int realIndex = sortedMessages.length - 1 - index;
                        final msg = sortedMessages[realIndex];

                        // NEW: "<name> left the group" style notices
                        if (msg.messageType == 'system') {
                          return _buildSystemMessage(msg.content);
                        }

                        final isMe = msg.senderId == _currentUserId;

                        String? senderName;
                        if (widget.isGroup && !isMe) {
                          senderName = memberNames[msg.senderId];
                        }
                        final bool isNew = _firstLoadDone && !_seenMessageIds.contains(msg.id);
                        // message bubble style is untouched, only the screen
                        // around it has been polished
                        return FadeSlideIn(
                          key: ValueKey(msg.id),
                          enabled: isNew,
                          child: MessageBubble(
                            key: ValueKey(msg.id),
                            text: msg.content,
                            time: msg.createdAt,
                            isMe: isMe,
                            status: msg.status,
                            senderName: senderName,
                            messageType: msg.messageType,
                            mediaUrl: msg.mediaUrl,
                            durationSeconds: msg.durationSeconds,
                            onStopLiveLocation: isMe ? () => _stopLiveLocation(msg.id) : null,
                            onLongPress: () => _showMessageOptions(msg),
                            selectionMode: _isSelectionMode,
                            isSelected: _selectedMessageIds.contains(msg.id),
                            onToggleSelect: () => _toggleMessageSelection(msg.id),
                            repliedMessage: msg.replyToId != null ? messagesById[msg.replyToId] : null,
                            onSwipeReply: () => setState(() => _replyingTo = msg),
                            repliedSenderName: (msg.replyToId != null && messagesById[msg.replyToId] != null)
                                ? _nameFor(messagesById[msg.replyToId])
                                : null,
                          ),
                        );
                      },
                    );
                  },
      loading: () => const _ChatSkeleton(),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                ),
    ]
              ),
              ),              // ---- Input bar ----
              if (hasLeft)
                _buildLeftBanner()
              else
                SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reply preview bar (naam + message text)
                        AnimatedSize(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
    child: _replyingTo != null
                          ?Container(
                            color: p.surface,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Container(width: 3, height: 36, color: p.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _nameFor(_replyingTo),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: p.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _replyingTo?.content ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13, color: p.textMain),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setState(() => _replyingTo = null),
                                ),
                              ],
                            ),
                          )
        : const SizedBox(width: double.infinity),
                        ),
                      // Attach panel smoothly grows above the input bar
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: _showAttachPanel
                            ? _buildAttachPanel()
                            : const SizedBox(width: double.infinity),
                      ),

                      // Input row + lock hint bubble
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: ScrollToBottomButton(
                              visible: _showScrollDown,
                              onTap: () => _scrollController.animateTo(
                                0, // list is reversed, so 0 = latest message
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            color: p.surface,
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
    );
  }

  // Left side of the input bar while recording
  Widget _buildRecordingBar(VoiceRecorderState recorder) {
    final p = ref.read(themeProvider).preset;
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
          const Pulse(
            minScale: 0.85,
            maxScale: 1.1,
            child: Icon(Icons.mic, color: Colors.red, size: 22),
          ),
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
    final p = ref.read(themeProvider).preset;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(Icons.attach_file, color: p.primary),
          onPressed: _toggleAttachPanel,
        ),
        IconButton(
          icon: const Icon(Icons.emoji_emotions_outlined, color: kHeaderColor),
          onPressed: _openStickerPicker,
        ),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
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
          ),
        ),
      ],
    );
  }

  // Right side button: send (locked / typed text) or mic
  Widget _buildRightButton(VoiceRecorderState recorder) {
    // Send is shown when: locked recording, or text typed (and not recording)
    final bool showSend = recorder.isRecording
        ? recorder.isLocked
        : _messageController.text.trim().isNotEmpty;

    return SendMicSwitcher(
      showSend: showSend,
      sendButton: CircleAvatar(
        radius: 22,
        backgroundColor: kAccentColor,
        child: IconButton(
          icon: const Icon(Icons.send, color: Colors.white, size: 20),
          onPressed: recorder.isRecording ? _stopVoiceRecording : _sendMessage,
        ),
      ),
      micButton: VoiceMicButton(
        isRecording: recorder.isRecording,
        onStart: _startVoiceRecording,
        onLock: _lockVoiceRecording,
        onCancel: _cancelVoiceRecording,
        onSend: _stopVoiceRecording,
      ),
    );
  }

  // Shown instead of the input bar after I left the group
  Widget _buildLeftBanner() {
    final p = ref.read(themeProvider).preset;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        color: p.surface,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Text(
          "You can't send messages to this group because you're no longer a member.",
          textAlign: TextAlign.center,
          style: TextStyle(color: p.textGrey, fontSize: 13.5),
        ),
      ),
    );
  }

  // NEW: centered grey notice, like "Ali left the group"
  Widget _buildSystemMessage(String text) {
    final p = ref.read(themeProvider).preset;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textGrey, fontSize: 12.5),
          ),
        ),
      ),
    );
  }

  // Small "lock" bubble shown above the mic while holding
  Widget _buildLockHint() {
    final p = ref.read(themeProvider).preset;
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
// Loading skeleton for the message list (replaces the spinner)
class _ChatSkeleton extends StatelessWidget {
  const _ChatSkeleton();

  // Different bubble widths so it looks like a real chat
  static const List<double> _widths = [180, 120, 220, 150, 200, 100, 240, 160];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      reverse: true, // newest at the bottom, like the real list
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: _widths.length,
      itemBuilder: (context, index) {
        final bool isMe = index % 3 == 1; // some bubbles on the right
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: ShimmerBox(
              width: _widths[index],
              height: index % 4 == 0 ? 56 : 38,
              borderRadius: 16,
            ),
          ),
        );
      },
    );
  }
}