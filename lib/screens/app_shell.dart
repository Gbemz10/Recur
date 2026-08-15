import 'package:flutter/material.dart';

import '../data/profile_store.dart';
import '../data/subscription_store.dart';
import '../data/trial_store.dart';
import '../ui/ui.dart';
import 'calendar_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'trial_reminders_screen.dart';

/// Bottom-nav host for the four primary destinations.
///
/// Owns the single [SubscriptionStore] and [TrialStore] instances and hands
/// them to every tab that needs one, so a change made on Home is
/// immediately visible on Calendar, Trials, and Settings — there's exactly
/// one list of subscriptions (and one list of trial reminders) in memory,
/// not one per screen.
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
  final ProfileStore _profileStore = ProfileStore();

  static const _items = [
    AppNavItem(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded),
    AppNavItem(label: 'Calendar', icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today_rounded),
    // A trial isn't a subscription yet — it doesn't have a charge date, an
    // amount, or a cycle, so it doesn't belong in the same list as
    // Home/Calendar's confirmed and detected charges. It gets its own
    // destination rather than being squeezed into Settings, where a task
    // this time-sensitive would go unnoticed.
    AppNavItem(label: 'Trials', icon: Icons.hourglass_empty_rounded, selectedIcon: Icons.hourglass_bottom_rounded),
    AppNavItem(label: 'Settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded),
  ];

  @override
  void dispose() {
    _store.dispose();
    _trialStore.dispose();
    _profileStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            store: _store,
            trialStore: _trialStore,
            profileStore: _profileStore,
            onOpenTrials: () => setState(() => _index = 2),
          ),
          CalendarScreen(store: _store),
          TrialRemindersScreen(store: _trialStore),
          SettingsScreen(store: _store, profileStore: _profileStore, onSignOut: widget.onSignOut),
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
