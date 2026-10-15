import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/shared/widgets/avatar_viewer_screen.dart';
import '../../../core/utils/app_animations.dart';
import '../../../core/utils/page_transitions.dart';
import '../../auth/Profile/other_user_profile_provider.dart';
import '../providers/message_provider.dart';
import 'full_screen_image.dart';


class ContactInfoScreen extends ConsumerWidget {
  final String chatId;
  const ContactInfoScreen({super.key, required this.chatId});
  // Same download-then-open pattern used in message bubbles
  Future<void> _downloadAndOpenFile(String url, String fileName) async {
    final response = await http.get(Uri.parse(url));
    final tempDir = await getTemporaryDirectory();
    final localFile = File('${tempDir.path}/$fileName');
    await localFile.writeAsBytes(response.bodyBytes);
    await OpenFile.open(localFile.path);
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(themeProvider).preset;
    final profileAsync = ref.watch(otherUserProfileProvider(chatId));

    return Scaffold(
      backgroundColor: p.background,
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('User not found'));
          }
          final avatarUrl = profile.avatarUrl;
          final name = profile.name;

          return CustomScrollView(
            slivers: [
              // ---- Colored header with big avatar ----
              SliverAppBar(
                pinned: true,
                backgroundColor: p.header,
                foregroundColor: Colors.white,
                expandedHeight: 280,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(color: p.header),
                    padding: const EdgeInsets.only(top: 60, bottom: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: avatarUrl != null
                              ? () => Navigator.push(
                            context,
                              PageTransitions.fadeTransition(AvatarViewerScreen(imageUrl: avatarUrl, title: name))
                          )
                              : null,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 16,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 64,
                              backgroundColor: Colors.white,
                              backgroundImage:
                              avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null
                                  ? Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontSize: 46,
                                  fontWeight: FontWeight.bold,
                                  color: p.header,
                                ),
                              )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (profile.username != null && profile.username!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '@${profile.username}',
                            style: const TextStyle(fontSize: 14, color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ---- Info sections ----
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                        _InfoCard(
                          icon: Icons.info_outline,
                          label: 'About',
                          value: profile.bio!,
                          accent: p.primary,
                          surface: p.surface,
                          textMain: p.textMain,
                          textGrey: p.textGrey,
                        ),
                        const SizedBox(height: 12),
                      ],
                      _InfoCard(
                        icon: Icons.mail_outline,
                        label: 'Email',
                        value: profile.email,
                        accent: p.primary,
                        surface: p.surface,
                        textMain: p.textMain,
                        textGrey: p.textGrey,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Shared media',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: p.textMain,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, galleryRef, _) {
                          final messagesAsync =
                          galleryRef.watch(messagesProvider(chatId));

                          return messagesAsync.when(
                            data: (messages) {
                              // Pick out only image and file messages
                              List<dynamic> imageMessages = [];
                              List<dynamic> fileMessages = [];
                              for (var m in messages) {
                                if (m.messageType == 'image' && m.mediaUrl != null) {
                                  imageMessages.add(m);
                                } else if (m.messageType == 'file' && m.mediaUrl != null) {
                                  fileMessages.add(m);
                                }
                              }

                              if (imageMessages.isEmpty && fileMessages.isEmpty) {
                                return Text(
                                  'No shared media yet',
                                  style: TextStyle(color: p.textGrey, fontSize: 13),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (imageMessages.isNotEmpty)
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: imageMessages.length,
                                      gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                        crossAxisSpacing: 6,
                                        mainAxisSpacing: 6,
                                      ),
                                      itemBuilder: (context, index) {
                                        final msg = imageMessages[index];
                                        return PressScale(
                                          onTap: () => Navigator.push(
                                            context,
                                            PageTransitions.fadeTransition(
                                              FullscreenImageScreen(
                                                imageUrl: msg.mediaUrl,
                                                heroTag: 'img_${msg.id}',
                                              ),
                                            ),
                                          ),
                                          child: Hero(
                                            tag: 'img_${msg.id}',
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                msg.mediaUrl,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child, progress) =>
                                                progress == null ? child : const ShimmerBox(height: 100),
                                                errorBuilder: (context, error, stack) => Container(color: p.surface),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  if (fileMessages.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    for (var msg in fileMessages)
                                      Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(Icons.insert_drive_file, color: p.primary),
                                          title: Text(
                                            msg.content,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: p.textMain, fontSize: 13.5),
                                          ),
                                          onTap: () =>
                                              _downloadAndOpenFile(msg.mediaUrl, msg.content),
                                        ),
                                      ),
                                  ],
                                ],
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator()),
                            error: (err, stack) => Text('Error: $err'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

// One rounded info card: icon + label + value
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final Color surface;
  final Color textMain;
  final Color textGrey;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.surface,
    required this.textMain,
    required this.textGrey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: textGrey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, color: textMain),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}