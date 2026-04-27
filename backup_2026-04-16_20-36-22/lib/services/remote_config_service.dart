import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../utils/debug_log.dart';

/// Service für Firebase Remote Config
/// Ermöglicht Fernkonfiguration ohne App-Update
class RemoteConfigService {
  static FirebaseRemoteConfig? _remoteConfig;
  static bool _initialized = false;

  /// Initialisiert Remote Config
  static Future<void> initialize() async {
    if (_initialized) {
      debugLog('✅ Remote Config bereits initialisiert');
      return;
    }

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      
      // Default-Werte (werden verwendet, wenn Remote Config nicht verfügbar ist)
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      await _remoteConfig!.setDefaults({
        // App Check: standardmäßig an (Notfall-Abschaltung nur über Firebase Console / RC)
        'enable_app_check': true,
        'cooldown_seconds': 30, // ✅ Cooldown in Sekunden
        'guest_limit_per_hour': 2, // ✅ Standard-Limit für Gäste
        'user_limit_per_hour': 5, // ✅ Standard-Limit für User
      });

      // Lade Remote Config
      await _remoteConfig!.fetchAndActivate();
      
      _initialized = true;
      debugLog('✅ Remote Config initialisiert');
      debugLog('   - enable_app_check: ${getBool('enable_app_check')}');
      debugLog('   - cooldown_seconds: ${getInt('cooldown_seconds')}');
    } catch (e) {
      debugLog('⚠️ Fehler beim Initialisieren von Remote Config: $e');
      // App darf weiter funktionieren, auch wenn Remote Config fehlschlägt
    }
  }

  /// Gibt einen Boolean-Wert zurück
  static bool getBool(String key) {
    if (_remoteConfig == null) {
      debugLog('⚠️ Remote Config nicht initialisiert, verwende Default für $key');
      return false;
    }
    return _remoteConfig!.getBool(key);
  }

  /// Gibt einen Integer-Wert zurück
  static int getInt(String key) {
    if (_remoteConfig == null) {
      debugLog('⚠️ Remote Config nicht initialisiert, verwende Default für $key');
      return 30; // Default Cooldown
    }
    return _remoteConfig!.getInt(key);
  }

  /// Gibt einen String-Wert zurück
  static String getString(String key) {
    if (_remoteConfig == null) {
      debugLog('⚠️ Remote Config nicht initialisiert, verwende Default für $key');
      return '';
    }
    return _remoteConfig!.getString(key);
  }

  /// Ob App Check laufen soll (Remote Config). Wenn RC nicht initialisiert ist: **an** (sicherer Fallback).
  static bool isAppCheckEnabled() {
    if (_remoteConfig == null) {
      return true;
    }
    return _remoteConfig!.getBool('enable_app_check');
  }

  /// Gibt den Cooldown in Sekunden zurück
  static int getCooldownSeconds() {
    return getInt('cooldown_seconds');
  }

  /// Aktualisiert Remote Config (wird periodisch aufgerufen)
  static Future<void> fetchAndActivate() async {
    if (_remoteConfig == null) {
      return;
    }
    try {
      await _remoteConfig!.fetchAndActivate();
      debugLog('✅ Remote Config aktualisiert');
    } catch (e) {
      debugLog('⚠️ Fehler beim Aktualisieren von Remote Config: $e');
    }
  }
}
