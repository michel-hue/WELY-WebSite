import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/notifications_repository.dart';
import '../theme/tokens.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    (Icons.search, 'Explorer'),
    (Icons.favorite_border, 'Favoris'),
    (Icons.chat_bubble_outline, 'Demandes'),
    (Icons.person_outline, 'Profil'),
  ];
  static const _profileIndex = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: WellyColors.surface.withValues(alpha: 0.97),
          border: const Border(top: BorderSide(color: WellyColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabItem(
                      icon: _tabs[i].$1,
                      label: _tabs[i].$2,
                      active: navigationShell.currentIndex == i,
                      dot: i == _profileIndex && unread > 0,
                      onTap: () => navigationShell.goBranch(
                        i,
                        initialLocation: i == navigationShell.currentIndex,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.dot = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 24, color: active ? WellyColors.laiton : WellyColors.muted);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!dot)
            iconWidget
          else
            Stack(clipBehavior: Clip.none, children: [
              iconWidget,
              Positioned(
                top: -1,
                right: -3,
                child: Semantics(
                  label: 'Notifications non lues',
                  child: Container(
                    key: const Key('profile-unread-dot'),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: WellyColors.laiton,
                      shape: BoxShape.circle,
                      border: Border.all(color: WellyColors.surface, width: 2),
                    ),
                  ),
                ),
              ),
            ]),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: active ? FontWeight.w500 : FontWeight.w400,
              color: active ? WellyColors.laitonText : WellyColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
