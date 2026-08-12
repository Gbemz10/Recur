import 'dart:typed_data';

import 'api_client.dart';
import 'profile.dart';

/// Wraps `/auth/me` — reading, editing the display name, and swapping the
/// avatar photo. Separate from [AuthService] since that module is about
/// establishing a session, not managing the account once signed in.
class ProfileService {
  ProfileService._();

  static Future<Profile> getProfile() async {
    final response = await apiClient.get('/auth/me');
    return Profile.fromJson(response['user'] as Map<String, dynamic>);
  }

  static Future<Profile> updateDisplayName(String displayName) async {
    final response = await apiClient.patch('/auth/me', body: {'displayName': displayName});
    return Profile.fromJson(response['user'] as Map<String, dynamic>);
  }

  static Future<Profile> uploadAvatar({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final response = await apiClient.postFile(
      '/auth/me/avatar',
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
    return Profile.fromJson(response['user'] as Map<String, dynamic>);
  }
}
