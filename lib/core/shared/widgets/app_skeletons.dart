import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../theme/app_colors.dart';
import 'chat_tile.dart';

/// Shared shimmer skeletons used instead of CircularProgressIndicator.
/// Always mirrors the real layout + theme shimmer colors.
class AppSkeletons {
  AppSkeletons._();

  static ShimmerEffect get _effect => ShimmerEffect(
        baseColor: AppColors.shimmerBase,
        highlightColor: AppColors.shimmerHighlight,
      );

  static Widget chatList({int count = 8}) {
    return Skeletonizer(
      enabled: true,
      effect: _effect,
      containersColor: AppColors.background,
      child: ColoredBox(
        color: AppColors.background,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          itemCount: count,
          separatorBuilder: (_, __) => const ChatDivider(),
          itemBuilder: (_, i) => ChatTile(
            index: i,
            name: 'Loading user name here',
            lastMessage: 'Last message preview text goes here',
            time: '12:00',
            unreadCount: 0,
            isGroup: i.isOdd,
            avatarColor: AppColors.secondary,
            onTap: () {},
          ),
        ),
      ),
    );
  }

  /// For CustomScrollView / Sliver lists (Home + Groups).
  static Widget chatListSliver({int count = 8}) {
    return SliverSkeletonizer(
      enabled: true,
      effect: _effect,
      containersColor: AppColors.background,
      child: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i.isOdd) return const ChatDivider();
            final idx = i ~/ 2;
            return ChatTile(
              index: idx,
              name: 'Loading user name here',
              lastMessage: 'Last message preview text goes here',
              time: '12:00',
              unreadCount: 0,
              isGroup: idx.isOdd,
              avatarColor: AppColors.secondary,
              onTap: () {},
            );
          },
          childCount: count * 2 - 1,
        ),
      ),
    );
  }

  static Widget messages({int count = 10}) {
    return Skeletonizer(
      enabled: true,
      effect: _effect,
      containersColor: AppColors.surface,
      child: ColoredBox(
        color: AppColors.chatBackground,
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          itemCount: count,
          itemBuilder: (_, i) {
            final isMe = i.isEven;
            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                constraints: const BoxConstraints(maxWidth: 260),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.myBubble : AppColors.otherBubble,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe
                          ? 'Outgoing message skeleton line'
                          : 'Incoming message skeleton preview',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '12:00',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static Widget userList({int count = 10}) {
    return Skeletonizer(
      enabled: true,
      effect: _effect,
      containersColor: AppColors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: count,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 72,
          color: AppColors.divider,
        ),
        itemBuilder: (_, __) => ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.secondary,
            child: Text('A', style: TextStyle(color: AppColors.primary)),
          ),
          title: Text(
            'Loading contact name',
            style: TextStyle(color: AppColors.textMain),
          ),
          subtitle: Text(
            'contact@email.com',
            style: TextStyle(color: AppColors.textGrey),
          ),
          trailing: Icon(Icons.chevron_right, color: AppColors.icon),
        ),
      ),
    );
  }

  /// Matches [UserProfileScreen] photo-led layout (square hero + section cards).
  static Widget profile() {
    return Skeletonizer(
      enabled: true,
      effect: _effect,
      containersColor: AppColors.surface,
      child: ColoredBox(
        color: AppColors.chatBackground,
        child: CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: AspectRatio(
                aspectRatio: 1,
                child: ColoredBox(color: AppColors.surface),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Phone number placeholder',
                              style: TextStyle(
                                color: AppColors.textMain,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Phone',
                              style: TextStyle(
                                color: AppColors.textGrey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hey there! I am using ChatMe profile about text',
                        style: TextStyle(
                          color: AppColors.textMain,
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Joined January 2024',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget editProfileForm() {
    return Skeletonizer(
      enabled: true,
      effect: _effect,
      containersColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.secondary,
              child: Text('A', style: TextStyle(color: AppColors.primary)),
            ),
            const SizedBox(height: 28),
            TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Name placeholder text',
                hintStyle: TextStyle(color: AppColors.textGrey),
                prefixIcon: Icon(Icons.person_outline, color: AppColors.icon),
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              enabled: false,
              decoration: InputDecoration(
                hintText: 'Phone placeholder text',
                hintStyle: TextStyle(color: AppColors.textGrey),
                prefixIcon: Icon(Icons.phone_outlined, color: AppColors.icon),
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: null,
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget authGate() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Skeletonizer(
        enabled: true,
        effect: _effect,
        containersColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Bone.circle(size: 72),
              const SizedBox(height: 28),
              const Bone.text(words: 2, fontSize: 28),
              const SizedBox(height: 12),
              const Bone.multiText(lines: 2, fontSize: 14),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: Bone.button(height: 56),
              ),
              const SizedBox(height: 16),
              const Bone.text(words: 4, fontSize: 13),
            ],
          ),
        ),
      ),
    );
  }

  static Future<T?> showBlockingOverlay<T>({
    required BuildContext context,
    required Future<T> future,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      builder: (_) => const Center(child: _BlockingSkeletonCard()),
    );

    try {
      return await future;
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  static Widget imagePlaceholder({
    double width = 220,
    double height = 220,
  }) {
    return Skeletonizer(
      enabled: true,
      effect: _effect,
      containersColor: AppColors.surface,
      child: Container(
        width: width,
        height: height,
        color: AppColors.surface,
        alignment: Alignment.center,
        child: Icon(Icons.image, size: 40, color: AppColors.icon),
      ),
    );
  }
}

class _BlockingSkeletonCard extends StatelessWidget {
  const _BlockingSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Skeletonizer(
        enabled: true,
        effect: ShimmerEffect(
          baseColor: AppColors.shimmerBase,
          highlightColor: AppColors.shimmerHighlight,
        ),
        containersColor: AppColors.surface,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Bone.circle(size: 40),
              SizedBox(height: 14),
              Bone.text(words: 2),
              SizedBox(height: 8),
              Bone.text(words: 3, fontSize: 12),
            ],
          ),
        ),
      ),
    );
  }
}
