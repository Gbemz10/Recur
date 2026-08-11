import 'package:flutter/material.dart';

import '../ui/ui.dart';
import 'dashboard_screen.dart';

/// Bottom-nav host. Only Home is real in v1 — the other tabs are
/// intentionally honest placeholders rather than fake screens.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _items = [
    AppNavItem(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
    AppNavItem(label: 'Calendar', icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today_rounded),
    AppNavItem(label: 'Settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          _ComingSoon(
            icon: Icons.calendar_today_rounded,
            title: 'Renewal calendar',
            message:
                'A month view of every upcoming charge. Landing right after '
                'the detection engine is tuned.',
          ),
          _ComingSoon(
            icon: Icons.settings_rounded,
            title: 'Settings',
            message:
                'Manage linked accounts, notification timing, and data '
                'deletion.',
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        items: _items,
        selectedIndex: _index,
        onSelect: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: AppEmptyState(
          icon: icon,
          title: title,
          message: message,
        ),
      ),
    );
  }
}
