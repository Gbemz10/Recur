import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'banking_service.dart';
import 'linked_bank.dart';

/// Shared, listenable store for linked-bank status — same reasoning as
/// [SubscriptionStore]/[TrialStore]/[ProfileStore].
///
/// Before this existed, `SettingsScreen` fetched `/banking/accounts` into
/// its own private `State`, refreshed only in `initState` and manually
/// after its own link/unlink actions. That's the exact "fetched once per
/// screen, no shared store" shape that caused the profile bugs fixed
/// earlier — harmless only by accident, because Settings has so far been
/// the only tab that shows bank-link status. The moment anything else
/// (e.g. a "connect your bank" prompt on the dashboard) needs to know
/// whether a bank is linked, it would silently go stale the same way.
class BankStore extends ChangeNotifier {
  BankStore() {
    load();
  }

  List<LinkedBank> _banks = [];

  bool isLoading = true;
  String? error;

  List<LinkedBank> get all => List.unmodifiable(_banks);

  List<LinkedBank> get active => _banks.where((b) => b.isActive).toList();

  bool get hasActiveBank => active.isNotEmpty;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    try {
      _banks = await BankingService.listAccounts();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = "Couldn't load your linked accounts — try again.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Removes the bank from view immediately and reverts if the backend
  /// rejects the unlink — same optimistic-then-revert shape used
  /// throughout the other stores.
  Future<void> unlink(LinkedBank bank) async {
    final previous = [..._banks];
    _banks = _banks.where((b) => b.id != bank.id).toList();
    notifyListeners();

    try {
      await BankingService.unlinkAccount(bank.id);
    } catch (e) {
      _banks = previous;
      notifyListeners();
      if (e is ApiException) rethrow;
      throw ApiException("Couldn't unlink that bank — try again.", code: 'CLIENT_ERROR');
    }
  }
}
