/// Mirrors recur-backend's `serializeProfile` shape exactly — see
/// src/modules/auth/service.ts.
class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.memberSince,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime memberSince;

  /// Falls back to the email's local part when no name has been set yet —
  /// "shogagbemiga" beats a blank header for someone who just signed up.
  String get displayLabel {
    if (displayName != null && displayName!.trim().isNotEmpty) return displayName!;
    return email.split('@').first;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      memberSince: DateTime.parse(json['memberSince'] as String),
    );
  }
}
