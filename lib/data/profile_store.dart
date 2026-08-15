import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'profile.dart';
import 'profile_service.dart';

/// Single in-memory source of truth for the signed-in user's profile,
/// shared across every tab in [AppShell] — the same reasoning as
/// [SubscriptionStore].
///
/// Before this existed, the dashboard header, Settings' account card, and
/// the Profile screen each fetched `GET /auth/me` independently and kept
/// their own private copy. That caused two visible bugs: the dashboard
/// avatar flashed the wrong initial ("A", from the "Account" placeholder
/// name) every time, since it had no way to know a real name was already
/// loaded elsewhere; and a photo changed on the Profile screen never
/// showed up on Settings' account card, because `AppShell` keeps every tab
/// alive in an `IndexedStack` — a tab that was already mounted never finds
/// out something changed on a different tab. One shared, listenable store
/// fixes both: everyone reads the same object, and a change made anywhere
/// (`setProfile`) notifies every listener immediately.
class ProfileStore extends ChangeNotifier {
  ProfileStore() {
    load();
  }

  Profile? profile;

  /// True only for the very first load, before any profile has ever been
  /// fetched — screens use this to show a neutral skeleton instead of a
  /// name/avatar placeholder that would just be wrong for a moment.
  bool get isInitialLoad => isLoading && profile == null;

  bool isLoading = true;
  String? error;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    try {
      profile = await ProfileService.getProfile();
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      // See SubscriptionStore.load()'s equivalent catch — a malformed
      // response otherwise leaves `isLoading` stuck true with nothing
      // telling the user (or the "Try again" button) that anything failed.
      error = "Couldn't load your profile — try again.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Called after any successful edit (name change, photo upload) so every
  /// screen holding this store picks up the change on its next rebuild,
  /// without each of them re-fetching from the network.
  void setProfile(Profile updated) {
    profile = updated;
    error = null;
    notifyListeners();
  }
}
