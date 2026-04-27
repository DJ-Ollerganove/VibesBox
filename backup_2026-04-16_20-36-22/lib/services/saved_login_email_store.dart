import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// E-Mail „Merken“ am Login — bevorzugt [FlutterSecureStorage], Migration von SharedPreferences.
class SavedLoginEmailStore {
  SavedLoginEmailStore._();

  static const _secureKey = 'saved_email';
  static const _legacyPrefsKey = 'saved_email';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
  );

  static Future<String?> read() async {
    final secure = await _storage.read(key: _secureKey);
    if (secure != null && secure.trim().isNotEmpty) {
      return secure.trim();
    }
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_legacyPrefsKey);
    if (legacy != null && legacy.trim().isNotEmpty) {
      await _storage.write(key: _secureKey, value: legacy.trim());
      await prefs.remove(_legacyPrefsKey);
      return legacy.trim();
    }
    return null;
  }

  static Future<void> write(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;
    await _storage.write(key: _secureKey, value: trimmed);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _secureKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyPrefsKey);
    await prefs.remove('saved_password');
  }
}
