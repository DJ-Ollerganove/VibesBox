import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';

/// Helper-Klasse zum Finden der Admin-DJ-ID
/// Diese Funktion wird einmalig ausgeführt, um die DJ-ID zu finden und fest einzutragen
class FindAdminDjIdHelper {
  /// Findet die Admin-DJ-ID durch Analyse der Datenbank
  /// Gibt eine Liste aller möglichen IDs zurück
  static Future<List<String>> findAllPossibleDjIds() async {
    final List<String> possibleIds = [];
    
    try {
      debugLog('🔍 FindAdminDjIdHelper: Starte Suche nach Admin-DJ-ID...');
      
      // Methode 1: Suche in parties nach created_by_email
      debugLog('📋 Methode 1: Suche in parties nach created_by_email...');
      final partiesQuery = await FirebaseFirestore.instance
          .collection('parties')
          .where('created_by_email', isEqualTo: AppConfig.adminEmail)
          .get();
      
      if (partiesQuery.docs.isNotEmpty) {
        debugLog('✅ Gefunden: ${partiesQuery.docs.length} Party(s) mit created_by_email = ${AppConfig.adminEmail}');
        for (final doc in partiesQuery.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final djId = data['created_by'] as String?;
          final djCode = data['dj_code'] as String?;
          final partyName = data['party_name'] as String?;
          
          if (djId != null && djId.isNotEmpty) {
            if (!possibleIds.contains(djId)) {
              possibleIds.add(djId);
              debugLog('   → Party "${partyName ?? doc.id}": created_by = $djId');
            }
          }
          if (djCode != null && djCode.isNotEmpty && djCode != djId) {
            if (!possibleIds.contains(djCode)) {
              possibleIds.add(djCode);
              debugLog('   → Party "${partyName ?? doc.id}": dj_code = $djCode');
            }
          }
        }
      } else {
        debugLog('⚠️ Keine Partys mit created_by_email = ${AppConfig.adminEmail} gefunden');
      }
      
      // Methode 2: Suche in users nach E-Mail
      debugLog('📋 Methode 2: Suche in users nach E-Mail...');
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: AppConfig.adminEmail)
          .get();
      
      if (usersQuery.docs.isNotEmpty) {
        debugLog('✅ Gefunden: ${usersQuery.docs.length} User(s) mit E-Mail = ${AppConfig.adminEmail}');
        for (final doc in usersQuery.docs) {
          final userId = doc.id;
          final data = doc.data() as Map<String, dynamic>;
          final displayName = data['displayName'] as String?;
          final roleId = data['role_id'] as String?;
          
          if (!possibleIds.contains(userId)) {
            possibleIds.add(userId);
            debugLog('   → Admin-Kandidat gefunden (role_id)');
          }
          
          // Prüfe, ob dieser User Partys erstellt hat
          final userPartiesQuery = await FirebaseFirestore.instance
              .collection('parties')
              .where('created_by', isEqualTo: userId)
              .limit(5)
              .get();
          
          if (userPartiesQuery.docs.isNotEmpty) {
            debugLog('   → Dieser User hat ${userPartiesQuery.docs.length} Party(s) erstellt');
          }
        }
      } else {
        debugLog('⚠️ Keine User mit E-Mail = ${AppConfig.adminEmail} gefunden');
      }
      
      // Methode 3: Suche in music_history nach djId
      debugLog('📋 Methode 3: Suche in music_history nach djId...');
      final musicHistoryQuery = await FirebaseFirestore.instance
          .collection('music_history')
          .where('djId', isEqualTo: possibleIds.isNotEmpty ? possibleIds.first : '')
          .limit(1)
          .get();
      
      // Methode 4: Suche in wishes nach djId
      if (possibleIds.isNotEmpty) {
        debugLog('📋 Methode 4: Suche in wishes nach djId...');
        for (final djId in possibleIds) {
          final wishesQuery = await FirebaseFirestore.instance
              .collection('wishes')
              .where('djId', isEqualTo: djId)
              .limit(1)
              .get();
          
          if (wishesQuery.docs.isNotEmpty) {
            debugLog('   → djId $djId hat ${wishesQuery.docs.length} Wunsch/Wünsche');
          }
        }
      }
      
      debugLog('✅ FindAdminDjIdHelper: Suche abgeschlossen. Gefundene IDs: ${possibleIds.length}');
      for (int i = 0; i < possibleIds.length; i++) {
        debugLog('   ${i + 1}. ${possibleIds[i]}');
      }
      
      return possibleIds;
    } catch (e) {
      debugLog('❌ FindAdminDjIdHelper: Fehler bei der Suche: $e');
      return possibleIds;
    }
  }
  
  /// Findet die wahrscheinlichste DJ-ID (die erste, die Partys erstellt hat)
  static Future<String?> findMostLikelyDjId() async {
    final possibleIds = await findAllPossibleDjIds();
    
    if (possibleIds.isEmpty) {
      debugLog('⚠️ FindAdminDjIdHelper: Keine möglichen DJ-IDs gefunden');
      return null;
    }
    
    // Prüfe für jede ID, ob sie Partys erstellt hat
    for (final djId in possibleIds) {
      final partiesQuery = await FirebaseFirestore.instance
          .collection('parties')
          .where('created_by', isEqualTo: djId)
          .limit(1)
          .get();
      
      if (partiesQuery.docs.isNotEmpty) {
        debugLog('✅ FindAdminDjIdHelper: Wahrscheinlichste DJ-ID: $djId (hat Partys erstellt)');
        return djId;
      }
    }
    
    // Fallback: Nimm die erste ID
    debugLog('⚠️ FindAdminDjIdHelper: Keine ID mit Partys gefunden, verwende erste ID: ${possibleIds.first}');
    return possibleIds.first;
  }
}


