import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState;
import 'package:get/get.dart';

import '../../core/theme/theme_provider.dart';
import 'Controller/message_controller.dart';
import 'constants/personas.dart';
import 'persona_background.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Persona persona;
  const ChatScreen({super.key, required this.persona});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  late final MessageController chatMessageController =
  Get.put(MessageController(widget.persona), tag: widget.persona.id);
  final TextEditingController messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    chatMessageController.messages.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    messageController.dispose();
    _scrollController.dispose();
    Get.delete<MessageController>(tag: widget.persona.id);
    super.dispose();
  }

  void _send() {
    if (messageController.text.isNotEmpty) {
      chatMessageController.sendMessage(messageController.text.trim());
      messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(themeProvider).preset;
    final bool dark = PersonaBackground.isDark(
        widget.persona, p.brightness == Brightness.dark);

    return Scaffold(
      backgroundColor: p.chatBackground,
      appBar: AppBar(
        backgroundColor: p.header,
        foregroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: widget.persona.color,
              child: Icon(widget.persona.icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.persona.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Obx(
                        () => Text(
                      chatMessageController.isTypeing.value
                          ? 'typing...'
                          : 'online',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: PersonaBackground(persona: widget.persona, dark: dark),
          ),
          Positioned.fill(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: Column(
                children: [
                  Expanded(child: _buildMessages(p, dark)),
                  _buildTypingIndicator(p),
                  _buildInputBar(p),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(dynamic p, bool dark) {
    return Obx(() {
      final count = chatMessageController.messages.length;

      if (count == 0) return _buildEmptyState(p, dark);

      return ListView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        itemCount: count,
        itemBuilder: (context, index) {
          final message = chatMessageController.messages[index];
          final bool isUser = message['isUser'] == true;
          final String time = (message['time'] ?? '').toString();
          final String text = (message['text'] ?? '').toString();

          // Change 4: error aur last message check
          final bool isError = message['isError'] == true;
          final bool isLastMessage = index == count - 1;

          final bool sameAsPrev = index > 0 &&
              (chatMessageController.messages[index - 1]['isUser'] == true) ==
                  isUser;

          // Change 5: bubble ke neeche Retry button
          return Padding(
            padding: EdgeInsets.only(top: sameAsPrev ? 2 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AiBubble(
                  isUser: isUser,
                  text: text,
                  time: time,
                  sentColor:
                  Color.alphaBlend(p.accent.withOpacity(0.28), p.surface),
                  receivedColor: p.surface,
                  textColor: p.textMain,
                  metaColor: p.textGrey,
                  tickColor: p.accent,
                ),
                if (isError && isLastMessage)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: TextButton.icon(
                      onPressed: () {
                        chatMessageController.retryLast();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildEmptyState(dynamic p, bool dark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: widget.persona.color,
              child: Icon(widget.persona.icon, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Say hi to ${widget.persona.name} 👋',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: dark ? Colors.white : p.textMain,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.persona.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: dark ? Colors.white70 : p.textGrey),
            ),
            if (widget.persona.starters.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: widget.persona.starters
                    .map(
                      (s) => ActionChip(
                    label: Text(s),
                    labelStyle: TextStyle(
                      color: p.textMain,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: p.surface,
                    side: BorderSide(color: p.divider),
                    onPressed: () => chatMessageController.sendMessage(s),
                  ),
                )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(dynamic p) {
    return Obx(() {
      if (!chatMessageController.isTypeing.value) {
        return const SizedBox.shrink();
      }
      final String live = chatMessageController.responseText.value;

      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomRight: Radius.circular(14),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: live.trim().isEmpty
                ? _TypingDots(color: p.textGrey)
                : Text(
              live,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: p.textGrey,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildInputBar(dynamic p) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        color: p.surface,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: p.inputField,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: messageController,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: p.textMain),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: p.icon),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: p.accent,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final bool isUser;
  final String text;
  final String time;
  final Color sentColor;
  final Color receivedColor;
  final Color textColor;
  final Color metaColor;
  final Color tickColor;

  const _AiBubble({
    required this.isUser,
    required this.text,
    required this.time,
    required this.sentColor,
    required this.receivedColor,
    required this.textColor,
    required this.metaColor,
    required this.tickColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.78;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
        decoration: BoxDecoration(
          color: isUser ? sentColor : receivedColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                text,
                style: TextStyle(fontSize: 15, height: 1.35, color: textColor),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(time, style: TextStyle(fontSize: 11, color: metaColor)),
                if (isUser) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.done_all_rounded, size: 15, color: tickColor),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_anim.value - i * 0.18) % 1.0;
              final bounce = t < 0.5 ? (t / 0.5) : (1 - (t - 0.5) / 0.5);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                height: 7,
                width: 7,
                transform: Matrix4.translationValues(0, -4 * bounce, 0),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.4 + 0.5 * bounce),
                  shape: BoxShape.circle,
                ),
              );
            }),
          );
        },
      ),
    );
  }
}