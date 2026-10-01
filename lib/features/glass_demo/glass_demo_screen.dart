import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_palette.dart';
import '../../core/theme/glass.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/app_haptics.dart';

/// Reference screen for the two glass themes: atmosphere, frosted app bar,
/// scrolling glass cards and the liquid tab bar, all edge-to-edge.
/// Toggle Liquid Glass ↔ Glass Dark from the app bar.
class GlassDemoScreen extends ConsumerStatefulWidget {
  const GlassDemoScreen({super.key});

  @override
  ConsumerState<GlassDemoScreen> createState() => _GlassDemoScreenState();
}

class _GlassDemoScreenState extends ConsumerState<GlassDemoScreen> {
  int _tab = 0;

  static const _threads = <_Thread>[
    _Thread('Ava Martinez', 'Sent the final mockups — take a look 👀', '9:41', 3),
    _Thread('Design Crew', 'Leo: pill indicator feels so smooth now', '9:12', 12),
    _Thread('Noah Kim', 'Voice message · 0:42', '8:57', 0),
    _Thread('Mia Chen', 'Lunch tomorrow? 🍜', 'Yesterday', 1),
    _Thread('Ethan Brooks', 'Ok, pushing the build tonight', 'Yesterday', 0),
    _Thread('Product Sync', 'You: agenda is in the doc', 'Mon', 0),
    _Thread('Zara Ali', 'Photo', 'Mon', 0),
    _Thread('Lucas Silva', 'Haha that was great', 'Sun', 0),
    _Thread('Chloe Park', 'See you there!', 'Sat', 0),
    _Thread('Omar Haddad', 'Thanks for the review 🙏', 'Fri', 0),
  ];

  void _toggleTheme() {
    AppHaptics.select();
    final next = AppColors.isDark ? AppThemeId.softCream : AppThemeId.nordicSlate;
    ref.read(themeProvider.notifier).select(next);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final inset = MediaQuery.paddingOf(context);

    return GlassScaffold(
      appBar: GlassAppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: AppColors.isDark ? 'Liquid Glass' : 'Glass Dark',
            icon: Icon(AppColors.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            onPressed: _toggleTheme,
          ),
          IconButton(
            tooltip: 'New message',
            icon: const Icon(Icons.edit_square),
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      // With extendBody + extendBodyBehindAppBar the scaffold folds the bar
      // heights into MediaQuery padding, so content starts below the glass
      // but still scrolls underneath it.
      body: ListView(
        padding: EdgeInsets.fromLTRB(0, inset.top + 12, 0, inset.bottom + 24),
        children: [
          const _StoriesRow(),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _SummaryCard(),
          ),
          const _SectionLabel('Recent'),
          for (final t in _threads)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _ThreadCard(thread: t),
            ),
          const _SectionLabel('Contrast tiers'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _ContrastCard(),
          ),
        ],
      ),
      bottomNavigationBar: GlassBottomNav(
        activeIndex: _tab,
        onTap: (i) {
          AppHaptics.select();
          setState(() => _tab = i);
        },
        icons: const [
          Icons.chat_bubble_outline_rounded,
          Icons.call_outlined,
          Icons.blur_circular_outlined,
          Icons.settings_outlined,
        ],
        activeIcons: const [
          Icons.chat_bubble_rounded,
          Icons.call_rounded,
          Icons.blur_circular_rounded,
          Icons.settings_rounded,
        ],
        labels: const ['Chats', 'Calls', 'Updates', 'Settings'],
      ),
    );
  }
}

class _Thread {
  final String name;
  final String preview;
  final String time;
  final int unread;
  const _Thread(this.name, this.preview, this.time, this.unread);
}

// ---- Stories: vivid content that shows off the bar blur as it scrolls ----
class _StoriesRow extends StatelessWidget {
  const _StoriesRow();

  static const _names = ['You', 'Ava', 'Leo', 'Mia', 'Noah', 'Zara', 'Omar'];

  @override
  Widget build(BuildContext context) {
    final swatches = AppThemePalettes.avatarSwatches;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _names.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final c = swatches[i % swatches.length];
          return Column(
            children: [
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [AppColors.primary, c, AppColors.primary],
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Color.alphaBlend(
                    c.withValues(alpha: 0.85),
                    Colors.white,
                  ),
                  child: i == 0
                      ? const Icon(Icons.add_rounded, color: Colors.white)
                      : Text(
                          _names[i][0],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _names[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: AppColors.textMain,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
            ],
          ),
        );

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(Icons.bolt_rounded,
                    color: AppColors.onPrimary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
              ),
              Text(
                'See all',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat('16', 'Unread'),
              stat('4', 'Groups'),
              stat('2', 'Missed calls'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 20, 10),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textGrey,
        ),
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final _Thread thread;
  const _ThreadCard({required this.thread});

  @override
  Widget build(BuildContext context) {
    final hasUnread = thread.unread > 0;
    final avatar = AppColors.avatarFor(thread.name);

    return GlassCard(
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: AppHaptics.tap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: avatar.withValues(alpha: 0.18),
            child: Text(
              thread.name[0],
              style: TextStyle(
                color: avatar,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  thread.preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: hasUnread ? AppColors.textMain : AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                thread.time,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
                  color: hasUnread ? AppColors.primary : AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 6),
              if (hasUnread)
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${thread.unread}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const SizedBox(height: 18),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows every text tier on real glass so contrast can be eyeballed.
class _ContrastCard extends StatelessWidget {
  const _ContrastCard();

  @override
  Widget build(BuildContext context) {
    Widget line(String label, Color color, {FontWeight? weight}) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: TextStyle(fontSize: 15, color: color, fontWeight: weight),
          ),
        );

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line('Primary text · AAA', AppColors.textMain,
              weight: FontWeight.w600),
          line('Secondary text · AA', AppColors.textGrey),
          line('Disabled text', AppColors.textDisabled),
          line('Accent link', AppColors.primary, weight: FontWeight.w600),
          const SizedBox(height: 6),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                ),
                onPressed: () {},
                child: const Text('Primary'),
              ),
              const SizedBox(width: 10),
              const FilledButton(onPressed: null, child: Text('Disabled')),
            ],
          ),
        ],
      ),
    );
  }
}
