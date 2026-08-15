import 'package:flutter/material.dart';

import '../data/subscription_store.dart';
import '../data/trial_store.dart';
import '../ui/ui.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';

/// Bottom-nav host for the three primary destinations.
///
/// Owns the single [SubscriptionStore] instance and hands it to every tab,
/// so a status change made on Home is immediately visible on Calendar and
/// Settings — there's exactly one list of subscriptions in memory, not one
/// per screen.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.onSignOut});

  /// Bubbled up from Settings, through here, to the root flow — see
  /// main.dart's `_RootFlow`, the only place that can actually swap the
  /// whole app back to the auth screen.
  final VoidCallback onSignOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final SubscriptionStore _store = SubscriptionStore();
  final TrialStore _trialStore = TrialStore();

  static const _items = [
    AppNavItem(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
    AppNavItem(label: 'Calendar', icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today_rounded),
    AppNavItem(label: 'Settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded),
  ];

  @override
  void dispose() {
    _store.dispose();
    _trialStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(store: _store, trialStore: _trialStore),
          CalendarScreen(store: _store),
          SettingsScreen(store: _store, trialStore: _trialStore, onSignOut: widget.onSignOut),
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
