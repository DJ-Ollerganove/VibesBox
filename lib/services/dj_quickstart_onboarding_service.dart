import 'package:shared_preferences/shared_preferences.dart';

/// Lokaler Fallback, falls Firestore-Write für [hasSeenQuickstart] fehlschlägt.
class DjQuickstartOnboardingService {
  DjQuickstartOnboardingService._();

  static const String _prefsKey = 'dj_quickstart_onboarding_seen_uids_v1';

  static Future<bool> isDismissedLocally(String uid) async {
    if (uid.isEmpty) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_prefsKey) ?? const [];
      return list.contains(uid);
    } catch (_) {
      return false;
    }
  }

  static Future<void> markDismissedLocally(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = List<String>.from(prefs.getStringList(_prefsKey) ?? const []);
      if (!list.contains(uid)) {
        list.add(uid);
        await prefs.setStringList(_prefsKey, list);
      }
    } catch (_) {}
  }
}
