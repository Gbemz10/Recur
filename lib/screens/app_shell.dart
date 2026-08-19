import 'package:flutter/material.dart';

import '../data/bank_store.dart';
import '../data/profile_store.dart';
import '../data/spending_store.dart';
import '../data/subscription_store.dart';
import '../data/trial_store.dart';
import '../ui/ui.dart';
import 'dashboard_screen.dart';
import 'recurring_screen.dart';
import 'settings_screen.dart';
import 'spending_screen.dart';
import 'trial_reminders_screen.dart';

/// The five bottom-nav destinations, named rather than indexed so a caller
/// asking Home to jump somewhere does not have to know the tab order.
enum AppTab { home, recurring, spending, trials, settings }

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
  final BankStore _bankStore = BankStore();

  /// Owned here for the same reason as the others: the dashboard leads with a
  /// spending summary and the breakdown screen pushes on top of it, so both
  /// have to read one list that a budget edit updates once.
  final SpendingStore _spendingStore = SpendingStore();

  /// Five destinations, each answering one question.
  ///
  /// Home is a digest of the other four rather than a screen of its own
  /// content: how much, what is imminent, where the rest went, what converts
  /// soon. Recurring absorbed the Active/Review/Cancelled lists that used to
  /// live on Home along with the old Calendar tab, since a month grid is a
  /// view of those subscriptions rather than a separate subject. Spending was
  /// a screen pushed from Home and is now top level, because "where did it
  /// all go" is a question people arrive with, not one they drill into.
  static const _items = [
    AppNavItem(
        label: 'Home', icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded),
    AppNavItem(
        label: 'Recurring', icon: Icons.autorenew_outlined, selectedIcon: Icons.autorenew_rounded),
    AppNavItem(
        label: 'Spending',
        icon: Icons.pie_chart_outline_rounded,
        selectedIcon: Icons.pie_chart_rounded),
    // A trial is not a subscription yet: no charge date, no amount, no cycle.
    // It gets its own destination rather than being squeezed into Settings,
    // where something this time-sensitive would go unnoticed.
    AppNavItem(label: 'Trials', icon: Icons.timer_outlined, selectedIcon: Icons.timer_rounded),
    AppNavItem(
        label: 'Settings', icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded),
  ];

  /// Which of Recurring's three lists to show. Recurring lives in an
  /// IndexedStack and keeps its own state, so a constructor argument would
  /// only apply on first build; a notifier reaches it whenever Home asks.
  final _recurringSection = ValueNotifier<int>(0);

  /// Lets Home hand off to another destination by name. Home is a digest, so
  /// nearly every card on it is a doorway into the tab that owns that data.
  ///
  /// [section] deep-links past the destination's default list. Without it the
  /// three doorways into Recurring — the total, "Up next", and the review
  /// nudge — all landed on Active, so the one that says "1 charge to review"
  /// dropped you somewhere with no charges to review.
  void _goToTab(AppTab tab, {int? section}) {
    if (section != null && tab == AppTab.recurring) {
      _recurringSection.value = section;
    }
    setState(() => _index = tab.index);
  }

  @override
  void dispose() {
    _recurringSection.dispose();
    _store.dispose();
    _trialStore.dispose();
    _profileStore.dispose();
    _bankStore.dispose();
    _spendingStore.dispose();
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
            spendingStore: _spendingStore,
            onOpenTab: _goToTab,
          ),
          RecurringScreen(store: _store, section: _recurringSection),
          SpendingScreen(store: _spendingStore),
          TrialRemindersScreen(store: _trialStore),
          SettingsScreen(
            store: _store,
            profileStore: _profileStore,
            bankStore: _bankStore,
            onSignOut: widget.onSignOut,
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
