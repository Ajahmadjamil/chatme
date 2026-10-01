import 'package:circle_nav_bar/circle_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/notification/notification_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass.dart';
import '../../core/theme/theme_provider.dart';
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

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  @override
  void initState() {
    super.initState();
    // Link this phone's FCM token to the logged-in user (once per open).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.syncTokenForLoggedInUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider);
    final int currentIndex = ref.watch(navIndexProvider);
    final glass = AppColors.isGlass;

    final List<Widget> pages = [
      const HomeView(),
      const GroupsScreen(),
      const ProfileScreen(),
    ];

    void onNavTap(int index) {
      if (index == currentIndex) {
        AppHaptics.tap();
        return;
      }
      AppHaptics.select();
      ref.read(navIndexProvider.notifier).setIndex(index);
    }

    final Widget bottomNav = glass
        ? GlassBottomNav(
            activeIndex: currentIndex,
            onTap: onNavTap,
            icons: const [
              Icons.chat_outlined,
              Icons.groups_outlined,
              Icons.person_outline,
            ],
            activeIcons: const [
              Icons.chat,
              Icons.groups,
              Icons.person,
            ],
            labels: const ['Chats', 'Groups', 'Profile'],
          )
        : CircleNavBar(
            activeIcons: [
              Icon(Icons.chat, color: AppColors.primary),
              Icon(Icons.groups, color: AppColors.primary),
              Icon(Icons.person, color: AppColors.primary),
            ],
            inactiveIcons: [
              Icon(Icons.chat_outlined, color: AppColors.icon),
              Icon(Icons.groups_outlined, color: AppColors.icon),
              Icon(Icons.person_outline, color: AppColors.icon),
            ],
            color: AppColors.surface,
            height: 60,
            circleWidth: 60,
            activeIndex: currentIndex,
            onTap: onNavTap,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            cornerRadius: const BorderRadius.all(Radius.circular(24)),
            shadowColor: Colors.transparent,
            circleShadowColor: AppColors.primary.withValues(alpha: 0.35),
            elevation: 10,
          );

    return GlassAtmosphere(
      child: Scaffold(
        backgroundColor: glass ? Colors.transparent : AppColors.background,
        extendBody: glass,
        body: IndexedStack(
          index: currentIndex,
          children: pages,
        ),
        bottomNavigationBar: bottomNav,
      ),
    );
  }
}
