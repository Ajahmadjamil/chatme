import 'package:circle_nav_bar/circle_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_haptics.dart';
import '../Home/home_view.dart';
import '../auth/Profile/Screens/view.dart';
import 'group_screen.dart';

class NavIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int newIndex) {
    state = newIndex;
  }
}

final navIndexProvider = NotifierProvider<NavIndexNotifier, int>(() {
  return NavIndexNotifier();
});

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int currentIndex = ref.watch(navIndexProvider);

    final List<Widget> pages = [
      const HomeView(),
      const GroupsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: CircleNavBar(
        activeIcons: const [
          Icon(Icons.chat, color: AppColors.primary),
          Icon(Icons.groups, color: AppColors.primary),
          Icon(Icons.person, color: AppColors.primary),
        ],
        inactiveIcons: const [
          Icon(Icons.chat_outlined, color: AppColors.icon),
          Icon(Icons.groups_outlined, color: AppColors.icon),
          Icon(Icons.person_outline, color: AppColors.icon),
        ],
        color: Colors.white,
        height: 60,
        circleWidth: 60,
        activeIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) {
            AppHaptics.tap();
            return;
          }
          AppHaptics.select();
          ref.read(navIndexProvider.notifier).setIndex(index);
        },
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        cornerRadius: const BorderRadius.all(Radius.circular(24)),
        shadowColor: AppColors.primary,
        circleShadowColor: AppColors.primary,
        elevation: 10,
      ),
    );
  }
}
