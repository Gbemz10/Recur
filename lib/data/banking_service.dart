import 'api_client.dart';
import 'linked_bank.dart';

/// Wraps `/banking/*` — the Connect Link flow (see recur-backend's
/// `src/lib/mono.ts` for why this is a hosted URL rather than a native
/// widget SDK).
class BankingService {
  BankingService._();

  /// Asks the backend to start a bank link. Returns the Mono-hosted URL to
  /// open in a webview, and the redirect URL the client should watch for
  /// to know the user finished (or abandoned) the flow on Mono's page.
  static Future<({String monoUrl, String redirectUrl})> initiateLink() async {
    final response = await apiClient.post('/banking/link/initiate');
    return (monoUrl: response['monoUrl'] as String, redirectUrl: response['redirectUrl'] as String);
  }

  static Future<List<LinkedBank>> listAccounts() async {
    final response = await apiClient.get('/banking/accounts');
    final rows = response['banks'] as List<dynamic>? ?? const [];
    return rows.map((row) => LinkedBank.fromJson(row as Map<String, dynamic>)).toList();
  }

  static Future<void> unlinkAccount(String id) => apiClient.delete('/banking/accounts/$id');
}
