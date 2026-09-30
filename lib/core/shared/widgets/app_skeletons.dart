import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'chat_tile.dart';

/// Shared shimmer skeletons used instead of CircularProgressIndicator.
class AppSkeletons {
  AppSkeletons._();

  static Widget chatList({int count = 8}) {
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: count,
        separatorBuilder: (_, __) => const ChatDivider(),
        itemBuilder: (_, i) => ChatTile(
          index: i,
          name: 'Loading user name here',
          lastMessage: 'Last message preview text',
          time: '12:00',
          unreadCount: 0,
          isGroup: i.isOdd,
          avatarColor: Colors.grey,
          onTap: () {},
        ),
      ),
    );
  }

  /// For CustomScrollView / Sliver lists (Home + Groups).
  static Widget chatListSliver({int count = 8}) {
    return SliverSkeletonizer(
      enabled: true,
      child: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            if (i.isOdd) return const ChatDivider();
            final idx = i ~/ 2;
            return ChatTile(
              index: idx,
              name: 'Loading user name here',
              lastMessage: 'Last message preview text',
              time: '12:00',
              unreadCount: 0,
              isGroup: idx.isOdd,
              avatarColor: Colors.grey,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              constraints: const BoxConstraints(maxWidth: 260),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe
                        ? 'Outgoing message skeleton line'
                        : 'Incoming message skeleton preview',
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('12:00', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget userList({int count = 10}) {
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => const ListTile(
          leading: CircleAvatar(radius: 24, child: Text('A')),
          title: Text('Loading contact name'),
          subtitle: Text('contact@email.com'),
          trailing: Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  static Widget profile() {
    return Skeletonizer(
      enabled: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          const Center(
            child: CircleAvatar(radius: 48, child: Text('A')),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Loading profile name',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('user@email.com')),
          const SizedBox(height: 28),
          Card(
            elevation: 0,
            color: Colors.grey.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person)),
                  title: Text('Edit profile option'),
                  trailing: Icon(Icons.chevron_right),
                ),
                Divider(height: 1, indent: 66),
                ListTile(
                  leading: CircleAvatar(child: Icon(Icons.lock)),
                  title: Text('Change password option'),
                  trailing: Icon(Icons.chevron_right),
                ),
                Divider(height: 1, indent: 66),
                ListTile(
                  leading: CircleAvatar(child: Icon(Icons.settings)),
                  title: Text('Settings option row'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget editProfileForm() {
    return Skeletonizer(
      enabled: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Column(
          children: [
            const CircleAvatar(radius: 48, child: Text('A')),
            const SizedBox(height: 28),
            TextField(
              enabled: false,
              decoration: const InputDecoration(
                hintText: 'Name placeholder text',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              enabled: false,
              decoration: const InputDecoration(
                hintText: 'Phone placeholder text',
                prefixIcon: Icon(Icons.phone_outlined),
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
      body: Skeletonizer(
        enabled: true,
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

  /// Blocking overlay used instead of a spinner dialog.
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
      child: Container(
        width: width,
        height: height,
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Icon(Icons.image, size: 40),
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
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Bone.circle(size: 40),
              const SizedBox(height: 14),
              Bone.text(words: 2),
              const SizedBox(height: 8),
              Bone.text(words: 3, fontSize: 12),
            ],
          ),
        ),
      ),
    );
  }
}
