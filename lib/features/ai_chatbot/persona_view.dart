import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ConsumerStatefulWidget, ConsumerState;
import 'package:get_storage/get_storage.dart';

import '../../core/shared/widgets/chat_tile.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/page_transitions.dart';
import 'constants/personas.dart';
import 'view.dart';

class PersonaScreen extends ConsumerStatefulWidget {
  const PersonaScreen({super.key});

  @override
  ConsumerState<PersonaScreen> createState() => _PersonaScreenState();
}

class _PersonaScreenState extends ConsumerState<PersonaScreen> {
  final TextEditingController _searchController = TextEditingController();
  final GetStorage _box = GetStorage();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _lastMessage(Persona p) {
    try {
      final saved = _box.read<List>('chat_${p.id}');
      if (saved == null || saved.isEmpty) return null;
      final last = Map<String, dynamic>.from(saved.last as Map);
      final text = (last['text'] ?? '').toString();
      if (text.isEmpty) return null;
      return last['isUser'] == true ? 'You: $text' : text;
    } catch (_) {
      return null;
    }
  }

  Future<void> _open(Persona persona) async {
    await Navigator.push(
      context,
      PageTransitions.slideFromRight(ChatScreen(persona: persona)),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(themeProvider).preset;
    final String q = _query.trim().toLowerCase();

    final List<Persona> visible = Personas.all.where((x) {
      return q.isEmpty ||
          x.name.toLowerCase().contains(q) ||
          x.subtitle.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: p.surface,
      appBar: AppBar(
        backgroundColor: p.header,
        foregroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'AI Chat',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 18, color: p.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pick a character and start chatting',
                    style: TextStyle(fontSize: 13.5, color: p.textGrey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ChatSearchField(
            controller: _searchController,
            hint: 'Search characters',
            onChanged: (v) => setState(() => _query = v),
          ),
          Expanded(
            child: visible.isEmpty
                ? const ChatEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No results',
              subtitle: 'Try a different name.',
            )
                : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: visible.length * 2 - 1,
              itemBuilder: (context, i) {
                if (i.isOdd) return const ChatDivider();
                final persona = visible[i ~/ 2];
                return _PersonaTile(
                  persona: persona,
                  preview: _lastMessage(persona) ?? persona.subtitle,
                  hasChat: _lastMessage(persona) != null,
                  nameColor: p.textMain,
                  subColor: p.textGrey,
                  iconColor: p.icon,
                  onTap: () => _open(persona),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonaTile extends StatelessWidget {
  final Persona persona;
  final String preview;
  final bool hasChat;
  final Color nameColor;
  final Color subColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _PersonaTile({
    required this.persona,
    required this.preview,
    required this.hasChat,
    required this.nameColor,
    required this.subColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      persona.color,
                      Color.lerp(persona.color, Colors.black, 0.25)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(persona.icon, color: Colors.white, size: 26),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    persona.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: nameColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 14,
                      fontStyle:
                      hasChat ? FontStyle.normal : FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: iconColor),
          ],
        ),
      ),
    );
  }
}