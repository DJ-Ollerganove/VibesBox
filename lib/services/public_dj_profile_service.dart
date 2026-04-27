import 'dart:convert';

import 'package:http/http.dart' as http;

class PublicDjProfile {
  final String uid;
  final String? displayName;
  final String planType;
  final String? profilePic;

  const PublicDjProfile({
    required this.uid,
    required this.displayName,
    required this.planType,
    required this.profilePic,
  });
}

class PublicDjProfileService {
  static final Uri _endpoint = Uri.parse(
    'https://us-central1-dj-ollerganove.cloudfunctions.net/getPublicDjProfile',
  );

  Future<PublicDjProfile?> fetchByUid(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return null;

    try {
      final response = await http.post(
        _endpoint,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': cleanUid}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) return null;

      final planTypeRaw = payload['planType']?.toString().trim().toLowerCase();
      final planType = (planTypeRaw == null || planTypeRaw.isEmpty)
          ? 'free'
          : planTypeRaw;

      final displayNameRaw = payload['displayName']?.toString().trim();
      final profilePicRaw = payload['profilePic']?.toString().trim();

      return PublicDjProfile(
        uid: cleanUid,
        displayName:
            (displayNameRaw == null || displayNameRaw.isEmpty) ? null : displayNameRaw,
        planType: planType,
        profilePic:
            (profilePicRaw == null || profilePicRaw.isEmpty) ? null : profilePicRaw,
      );
    } catch (_) {
      return null;
    }
  }
}

