import 'package:cloud_firestore/cloud_firestore.dart';
import 'debug_log.dart';

/// Gibt die tatsächlichen Feldnamen (Keys) eines User-Dokuments aus Firestore aus.
/// Für das Detail-Fenster: So siehst du, welche Keys physisch in der DB existieren.
///
/// Aufruf z. B. aus der Benutzerverwaltung oder einem Debug-Menü:
/// ```dart
/// await DebugUsersDocKeys.printUserDocKeys('UID_DES_NUTZERS');
/// ```
class DebugUsersDocKeys {
  /// Lädt users/[uid], gibt alle Top-Level-Keys sortiert aus (inkl. Typ).
  /// In Debug/Profile-Mode: [debugPrint]; sonst nur bei kDebugMode.
  static Future<void> printUserDocKeys(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        debugLog('DebugUsersDocKeys: users/(uid) existiert nicht.');
        return;
      }

      final data = doc.data()!;
      final keys = data.keys.toList()..sort();

      debugLog('=== users/(uid) – ${keys.length} Felder ===');
      for (final k in keys) {
        final v = data[k];
        final type = v == null
            ? 'null'
            : v is Map
                ? 'Map(${v.length} keys)'
                : v.runtimeType.toString();
        debugLog('  $k: $type');
      }
      debugLog('=== Ende users/(uid) ===');
    } catch (e, st) {
      debugLog('DebugUsersDocKeys Fehler: $e');
      debugLog('$st');
    }
  }

  /// Gibt die Keys als sortierte Liste zurück (z. B. für UI im Detail-Fenster).
  static Future<List<String>> getUserDocKeys(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return [];
      final data = doc.data()!;
      final keys = data.keys.toList()..sort();
      return keys;
    } catch (e) {
      debugLog('DebugUsersDocKeys.getUserDocKeys: $e');
      return [];
    }
  }

  /// Gibt das komplette User-Dokument als Map zurück (Keys + Werte).
  /// Nützlich, um im Detail-Fenster alle Felder anzuzeigen.
  static Future<Map<String, dynamic>?> getUserDocData(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugLog('DebugUsersDocKeys.getUserDocData: $e');
      return null;
    }
  }
}
