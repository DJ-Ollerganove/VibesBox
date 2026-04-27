import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'user_service.dart';

/// Einmaliges Cleanup-Script für Firestore parties Collection
/// Bereinigt Altlasten: fehlende timezone_id, inkonsistente Timestamps
/// 
/// WICHTIG: Dieses Script sollte nach erfolgreichem Durchlauf wieder entfernt werden!
class PartyCleanupService {
  static const String _cleanupFlagKey = 'party_cleanup_completed_v1';
  
  /// Führt das Cleanup einmalig aus (nur wenn noch nicht durchgeführt)
  static Future<void> runCleanupOnce() async {
    try {
      final um = UserService().currentUser.value;
      if (um == null) {
        debugLog(
          'ℹ️ [CLEANUP] Party-Daten-Cleanup übersprungen (nicht eingeloggt / kein Profil)',
        );
        return;
      }
      if (!AppConfig.isAdminRole(um)) {
        debugLog(
          'ℹ️ [CLEANUP] Party-Daten-Cleanup übersprungen (nur Admin; volle parties-Liste)',
        );
        return;
      }

      // Prüfe ob Cleanup bereits durchgeführt wurde
      final prefs = await SharedPreferences.getInstance();
      final alreadyCompleted = prefs.getBool(_cleanupFlagKey) ?? false;
      
      if (alreadyCompleted) {
        debugLog('✅ [CLEANUP] Party-Cleanup wurde bereits durchgeführt - überspringe');
        return;
      }
      
      debugLog('🔧 [CLEANUP] Starte Party-Daten-Cleanup...');
      
      // Lade alle Partys
      final partiesSnapshot = await FirebaseFirestore.instance
          .collection('parties')
          .get();
      
      debugLog('📊 [CLEANUP] Gefundene Partys: ${partiesSnapshot.docs.length}');
      
      int correctedCount = 0;
      int skippedCount = 0;
      
      const defaultTimezoneId = 'Europe/Berlin';

      // Gehe durch alle Partys
      for (final doc in partiesSnapshot.docs) {
        final data = doc.data();
        final partyId = doc.id;
        final partyName = data['party_name'] as String? ?? 'Unbenannte Party';
        
        bool needsCorrection = false;
        final updateData = <String, dynamic>{};
        
        // PRÜFUNG 1: timezone_id fehlt oder ist leer
        dynamic timezoneIdRaw = data['timezone_id'] ?? 
                               data['timezoneId'] ?? 
                               data['time_zone_id'] ??
                               data['timezone'];
        
        String? currentTimezoneId;
        if (timezoneIdRaw != null && timezoneIdRaw is String) {
          final cleaned = timezoneIdRaw.trim();
          if (cleaned.isNotEmpty && cleaned.toLowerCase() != 'null') {
            currentTimezoneId = cleaned;
          }
        }
        
        if (currentTimezoneId == null || currentTimezoneId.isEmpty) {
          updateData['timezone_id'] = defaultTimezoneId;
          needsCorrection = true;
          debugLog('   ⚠️ [CLEANUP] Party $partyId: timezone_id fehlt → setze auf $defaultTimezoneId');
        }

        // latitude/longitude: Nicht überschreiben – fehlende Koordinaten bleiben null,
        // damit der Maps-Link auf den Adressnamen (Fallback) zurückgreift statt auf Berlin.

        // PRÜFUNG 3: Timestamp-Synchronität prüfen
        final startDate = data['start_date'] as Timestamp?;
        final endDate = data['end_date'] as Timestamp?;
        final startTimePosix = data['start_time_posix'] as int?;
        final endTimePosix = data['end_time_posix'] as int?;
        
        bool timestampNeedsSync = false;
        
        if (startDate != null) {
          // Berechne UTC-Sekunden aus Timestamp
          final startDateUtcSeconds = startDate.seconds;
          
          // Prüfe ob start_time_posix fehlt oder abweicht
          if (startTimePosix == null || startTimePosix != startDateUtcSeconds) {
            updateData['start_time_posix'] = startDateUtcSeconds;
            timestampNeedsSync = true;
            debugLog('   ⚠️ [CLEANUP] Party $partyId: start_time_posix inkonsistent → synchronisiere');
          }
          
          // Speichere start_date erneut basierend auf UTC-Sekunden (eliminiert Zeitzonen-Versatz)
          updateData['start_date'] = Timestamp.fromMillisecondsSinceEpoch(startDateUtcSeconds * 1000);
          timestampNeedsSync = true;
        }
        
        if (endDate != null) {
          // Berechne UTC-Sekunden aus Timestamp
          final endDateUtcSeconds = endDate.seconds;
          
          // Prüfe ob end_time_posix fehlt oder abweicht
          if (endTimePosix == null || endTimePosix != endDateUtcSeconds) {
            updateData['end_time_posix'] = endDateUtcSeconds;
            timestampNeedsSync = true;
            debugLog('   ⚠️ [CLEANUP] Party $partyId: end_time_posix inkonsistent → synchronisiere');
          }
          
          // Speichere end_date erneut basierend auf UTC-Sekunden (eliminiert Zeitzonen-Versatz)
          updateData['end_date'] = Timestamp.fromMillisecondsSinceEpoch(endDateUtcSeconds * 1000);
          timestampNeedsSync = true;
        }
        
        if (timestampNeedsSync) {
          needsCorrection = true;
        }
        
        // Führe Update durch wenn Korrekturen nötig
        if (needsCorrection) {
          try {
            await FirebaseFirestore.instance
                .collection('parties')
                .doc(partyId)
                .update(updateData);
            
            debugLog('✅ [CLEANUP] Party ID: $partyId ($partyName) - Synchronisiert auf $defaultTimezoneId');
            correctedCount++;
          } catch (e) {
            debugLog('❌ [CLEANUP] Fehler beim Aktualisieren von Party $partyId: $e');
          }
        } else {
          skippedCount++;
        }
      }
      
      // Markiere Cleanup als abgeschlossen
      await prefs.setBool(_cleanupFlagKey, true);
      
      debugLog('✅ [CLEANUP] Cleanup abgeschlossen!');
      debugLog('   📊 Korrigierte Partys: $correctedCount');
      debugLog('   📊 Übersprungene Partys: $skippedCount');
      debugLog('   📊 Gesamt: ${partiesSnapshot.docs.length}');
      
    } catch (e) {
      debugLog('❌ [CLEANUP] Fehler beim Cleanup: $e');
      debugLog('   Stack-Trace: ${e.toString()}');
    }
  }
  
  /// Entfernt die Cleanup-Flag (für erneutes Testen)
  /// WICHTIG: Nur für Entwicklung/Debugging verwenden!
  static Future<void> resetCleanupFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cleanupFlagKey);
    debugLog('⚠️ [CLEANUP] Cleanup-Flag zurückgesetzt - Cleanup wird beim nächsten Start erneut ausgeführt');
  }
}
