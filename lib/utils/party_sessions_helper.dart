import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/debug_log.dart';

/// Helper-Funktionen für die party_sessions Collection
/// Speichert Verbindung zwischen Party-ID, DJ-ID, Start-Zeitcode und End-Zeitcode

/// Erstellt oder aktualisiert einen party_sessions Eintrag
/// Bei manuellem Start: Endzeit = Startzeit + 24h
Future<void> createOrUpdatePartySession({
  required String partyId,
  required String djId,
  DateTime? startTime,
  DateTime? endTime,
  bool isManualStart = false,
  String? partyCode,
}) async {
  try {
    final now = DateTime.now();
    final sessionStartTime = startTime ?? now;
    final sessionEndTime = endTime ?? (isManualStart ? sessionStartTime.add(const Duration(hours: 24)) : null);
    
    // Hole party_code aus Party-Dokument, falls nicht übergeben
    String? finalPartyCode = partyCode;
    if (finalPartyCode == null) {
      try {
        final partyDoc = await FirebaseFirestore.instance
            .collection('parties')
            .doc(partyId)
            .get();
        if (partyDoc.exists) {
          finalPartyCode = partyDoc.data()?['party_code'] as String?;
        }
      } catch (e) {
        debugLog('⚠️ Konnte party_code nicht aus Party-Dokument laden: $e');
      }
    }
    
    // Prüfe, ob bereits ein aktiver Eintrag existiert (ohne end_time)
    final existingSessionsQuery = await FirebaseFirestore.instance
        .collection('party_sessions')
        .where('party_id', isEqualTo: partyId)
        .where('dj_id', isEqualTo: djId)
        .where('end_time', isNull: true)
        .limit(1)
        .get();
    
    if (existingSessionsQuery.docs.isNotEmpty) {
      // Aktualisiere bestehenden Eintrag
      final docRef = existingSessionsQuery.docs.first.reference;
      final updateData = <String, dynamic>{};
      
      if (endTime != null) {
        updateData['end_time'] = Timestamp.fromDate(endTime);
      }
      if (finalPartyCode != null) {
        updateData['party_code'] = finalPartyCode;
      }
      
      await docRef.update(updateData);
      debugLog('✅ Party-Session aktualisiert: $partyId für DJ $djId');
    } else {
      // Erstelle neuen Eintrag
      await FirebaseFirestore.instance
          .collection('party_sessions')
          .add({
        'party_id': partyId,
        'party_code': finalPartyCode,
        'dj_id': djId,
        'start_time': Timestamp.fromDate(sessionStartTime),
        'end_time': sessionEndTime != null ? Timestamp.fromDate(sessionEndTime) : null,
        'is_active': sessionEndTime == null || sessionEndTime.isAfter(now),
        'created_at': FieldValue.serverTimestamp(),
      });
      debugLog('✅ Party-Session erstellt: $partyId für DJ $djId');
    }
  } catch (e) {
    debugLog('❌ Fehler beim Erstellen/Aktualisieren der Party-Session: $e');
    rethrow;
  }
}

/// Beendet eine aktive Party-Session (setzt end_time)
Future<void> endPartySession({
  required String partyId,
  required String djId,
  DateTime? endTime,
}) async {
  try {
    final now = endTime ?? DateTime.now();
    
    // Finde aktive Sessions (ohne end_time)
    final activeSessionsQuery = await FirebaseFirestore.instance
        .collection('party_sessions')
        .where('party_id', isEqualTo: partyId)
        .where('dj_id', isEqualTo: djId)
        .where('end_time', isNull: true)
        .get();
    
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in activeSessionsQuery.docs) {
      batch.update(doc.reference, {
        'end_time': Timestamp.fromDate(now),
      });
    }
    
    await batch.commit();
    debugLog('✅ Party-Session beendet: $partyId für DJ $djId');
  } catch (e) {
    debugLog('❌ Fehler beim Beenden der Party-Session: $e');
    rethrow;
  }
}

/// Findet die aktive Party-ID für einen DJ (basierend auf party_sessions)
/// Erstellt automatisch party_sessions Einträge für geplante Partys, wenn sie starten
/// Gibt die Party-ID zurück, wenn eine aktive Session existiert (ohne end_time oder end_time > jetzt)
Future<String?> getActivePartyIdForDj(String djId) async {
  try {
    final now = DateTime.now();
    
    // ZUERST: Prüfe party_sessions
    final sessionsQuery = await FirebaseFirestore.instance
        .collection('party_sessions')
        .where('dj_id', isEqualTo: djId)
        .get();
    
    // Filtere clientseitig nach aktiven Sessions
    for (final doc in sessionsQuery.docs) {
      final data = doc.data();
      final endTime = data['end_time'] as Timestamp?;
      final startTime = data['start_time'] as Timestamp?;
      
      if (startTime == null) continue;
      
      final startDate = startTime.toDate();
      
      // Session ist aktiv wenn:
      // 1. end_time ist null UND jetzt >= start_time
      // 2. ODER end_time > jetzt UND jetzt >= start_time
      bool isActive = false;
      if (endTime == null) {
        isActive = now.compareTo(startDate) >= 0;
      } else {
        final endDate = endTime.toDate();
        isActive = now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0;
      }
      
      if (isActive) {
        final partyId = data['party_id'] as String?;
        debugLog('✅ Aktive Party-Session gefunden für DJ $djId: $partyId');
        return partyId;
      }
    }
    
    // FALLBACK: Prüfe geplante Partys - wenn eine gerade gestartet wurde, erstelle party_sessions Eintrag
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final partiesQuery = await FirebaseFirestore.instance
        .collection('parties')
        .where('end_date', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .where('created_by', isEqualTo: djId)
        .get();
    
    for (final partyDoc in partiesQuery.docs) {
      final data = partyDoc.data();
      final startTimestamp = data['start_date'] as Timestamp?;
      final endTimestamp = data['end_date'] as Timestamp?;
      
      if (startTimestamp != null && endTimestamp != null) {
        final startDate = startTimestamp.toDate();
        final endDate = endTimestamp.toDate();
        
        // Party ist aktiv, wenn jetzt >= Start UND jetzt < Ende
        if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
          // Prüfe, ob bereits ein party_sessions Eintrag existiert
          final existingSession = sessionsQuery.docs.where((doc) {
            final sessionData = doc.data();
            return sessionData['party_id'] == partyDoc.id && sessionData['end_time'] == null;
          }).isNotEmpty;
          
          if (!existingSession) {
            // Erstelle party_sessions Eintrag für geplante Party, die gerade gestartet wurde
            debugLog('🔧 Erstelle party_sessions Eintrag für geplante Party ${partyDoc.id}');
            await createOrUpdatePartySession(
              partyId: partyDoc.id,
              djId: djId,
              startTime: startDate,
              endTime: endDate,
              isManualStart: false,
            );
          }
          
          debugLog('✅ Aktive geplante Party gefunden für DJ $djId: ${partyDoc.id}');
          return partyDoc.id;
        }
      }
    }
    
    debugLog('ℹ️ Keine aktive Party-Session gefunden für DJ $djId');
    return null;
  } catch (e) {
    debugLog('❌ Fehler beim Finden der aktiven Party-Session: $e');
    return null;
  }
}

