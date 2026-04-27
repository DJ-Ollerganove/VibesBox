import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/debug_log.dart';

/// Service für die Verwaltung der Übersetzungs-Einstellung
/// Speichert in Firebase und cached lokal in SharedPreferences
class TranslationSettingsService {
  static const String _prefsKey = 'show_greeting_translations';
  static const String _firebasePath = 'show_greeting_translations';
  
  /// Lädt die Einstellung aus Firebase (mit Fallback auf SharedPreferences)
  /// Gibt true zurück, wenn Übersetzungen aktiviert sind, sonst false
  static Future<bool> isTranslationEnabled({String? userId}) async {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Fallback: Lade aus SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefsKey) ?? true; // Default: aktiviert
    }
    
    try {
      // Versuche zuerst aus SharedPreferences (schneller)
      final prefs = await SharedPreferences.getInstance();
      final cachedValue = prefs.getBool(_prefsKey);
      if (cachedValue != null) {
        // Lade im Hintergrund aus Firebase für Synchronisation
        _syncFromFirebase(uid, prefs);
        return cachedValue;
      }
      
      // Wenn nicht in Cache: Lade aus Firebase
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        final value = doc.data()?[_firebasePath] as bool?;
        final result = value ?? true; // Default: aktiviert
        
        // Speichere in SharedPreferences für schnellen Zugriff
        await prefs.setBool(_prefsKey, result);
        
        return result;
      }
      
      // Wenn kein Dokument existiert: Default-Wert
      final defaultValue = true;
      await prefs.setBool(_prefsKey, defaultValue);
      return defaultValue;
    } catch (e) {
      debugLog('⚠️ Fehler beim Laden der Übersetzungs-Einstellung: $e');
      // Fallback: Lade aus SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_prefsKey) ?? true; // Default: aktiviert
    }
  }
  
  /// Speichert die Einstellung in Firebase und SharedPreferences
  static Future<void> setTranslationEnabled(bool enabled, {String? userId}) async {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Nur in SharedPreferences speichern, wenn kein User eingeloggt
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, enabled);
      return;
    }
    
    try {
      // Speichere in Firebase
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        _firebasePath: enabled,
      });
      
      // Speichere auch in SharedPreferences für schnellen Zugriff
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, enabled);
    } catch (e) {
      debugLog('❌ Fehler beim Speichern der Übersetzungs-Einstellung: $e');
      // Fallback: Speichere zumindest in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, enabled);
      rethrow;
    }
  }
  
  /// Synchronisiert die Einstellung aus Firebase (im Hintergrund)
  static void _syncFromFirebase(String uid, SharedPreferences prefs) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      if (doc.exists) {
        final value = doc.data()?[_firebasePath] as bool?;
        if (value != null) {
          await prefs.setBool(_prefsKey, value);
        }
      }
    } catch (e) {
      // Fehler beim Sync ignorieren (nicht kritisch)
      debugLog('⚠️ Fehler beim Sync der Übersetzungs-Einstellung: $e');
    }
  }
  
  /// Stream für Echtzeit-Updates der Einstellung
  /// Gibt einen Stream zurück, der die Einstellung überwacht
  static Stream<bool> watchTranslationEnabled({String? userId}) {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Fallback: Einmaliger Wert aus SharedPreferences
      return Stream.value(true);
    }
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final value = doc.data()?[_firebasePath] as bool?;
        // Update auch SharedPreferences
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool(_prefsKey, value ?? true);
        });
        return value ?? true; // Default: aktiviert
      }
      return true; // Default: aktiviert
    });
  }
}
