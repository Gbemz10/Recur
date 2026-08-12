/// A bank connected via Mono, mirroring `linked_banks` on the backend.
class LinkedBank {
  const LinkedBank({
    required this.id,
    required this.bankName,
    required this.bankCode,
    required this.accountNumberMask,
    required this.status,
  });

  final String id;
  final String bankName;
  final String bankCode;
  final String accountNumberMask;
  final String status;

  /// The row exists the instant `account_connected` fires, before Mono has
  /// actually returned institution details — this is the placeholder name
  /// set at that point (see banking/service.ts `handleAccountConnected`).
  bool get isSyncing => bankName.isEmpty || bankName == 'Syncing…';

  factory LinkedBank.fromJson(Map<String, dynamic> json) => LinkedBank(
        id: json['id'] as String,
        bankName: json['bankName'] as String? ?? '',
        bankCode: json['bankCode'] as String? ?? '',
        accountNumberMask: json['accountNumberMask'] as String? ?? '',
        status: json['status'] as String? ?? '',
      );
}
