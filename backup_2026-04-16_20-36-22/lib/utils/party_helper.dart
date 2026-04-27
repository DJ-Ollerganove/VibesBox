import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/debug_log.dart';

/// Hilfsfunktion zum Finden der aktiven Party für den aktuellen DJ
/// Gibt Party-ID, Party-Code und DJ-Code zurück
Future<Map<String, String>> party_dj_check() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'party_id': 'manual',
        'party_code': 'manual',
        'dj_code': 'manual',
      };
    }

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    // Suche nach aktiven Partys des aktuellen DJs (genau wie in offen_page.dart)
    final partiesQuery = await FirebaseFirestore.instance
        .collection('parties')
        .where('end_date', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .where('created_by', isEqualTo: user.uid)
        .get();
    
    // PRIORITÄT 1: lifecycle_status == 'active' – sofort bei manuellem Party-Start
    for (final partyDoc in partiesQuery.docs) {
      final data = partyDoc.data();
      final lifecycleStatus = data['lifecycle_status'] as String?;
      final finishedAt = data['finished_at'];
      if (lifecycleStatus == 'finished' || lifecycleStatus == 'standby' || finishedAt != null) continue;
      if (lifecycleStatus == 'active') {
        final partyCode = data['party_code'] as String? ?? '';
        final djCode = data['dj_code'] as String? ?? data['created_by'] as String? ?? user.uid;
        return {
          'party_id': partyDoc.id,
          'party_code': partyCode,
          'dj_code': djCode,
        };
      }
    }

    // PRIORITÄT 2: Zeitfenster (jetzt >= Start UND jetzt < Ende)
    for (final partyDoc in partiesQuery.docs) {
      final data = partyDoc.data();
      final startTimestamp = data['start_date'] as Timestamp?;
      final endTimestamp = data['end_date'] as Timestamp?;

      if (startTimestamp != null && endTimestamp != null) {
        final startDate = startTimestamp.toDate();
        final endDate = endTimestamp.toDate();

        if (now.compareTo(startDate) >= 0 && now.compareTo(endDate) < 0) {
          final partyCode = data['party_code'] as String? ?? '';
          final djCode = data['dj_code'] as String? ?? data['created_by'] as String? ?? user.uid;
          return {
            'party_id': partyDoc.id,
            'party_code': partyCode,
            'dj_code': djCode,
          };
        }
      }
    }

    // Keine aktive Party nach Datum gefunden – prüfe manuellen Modus (VibesBox manuell: wishbox_enabled im Party-Dokument)
    for (final partyDoc in partiesQuery.docs.reversed) {
      final data = partyDoc.data();
      final partyName = data['party_name'] as String?;
      final createdBy = data['created_by'] as String?;
      final wishboxEnabled = data['wishbox_enabled'] as bool? ?? false;
      if (partyName == 'VibesBox manuell' && createdBy == user.uid && wishboxEnabled == true) {
        final partyCode = data['party_code'] as String? ?? '';
        final djCode = data['dj_code'] as String? ?? data['created_by'] as String? ?? user.uid;
        return {
          'party_id': partyDoc.id,
          'party_code': partyCode,
          'dj_code': djCode,
        };
      }
    }

    // Keine aktive Party gefunden
    return {
      'party_id': 'manual',
      'party_code': 'manual',
      'dj_code': 'manual',
    };
  } catch (e) {
    debugLog('❌ Fehler beim Finden der aktiven Party: $e');
    return {
      'party_id': 'manual',
      'party_code': 'manual',
      'dj_code': 'manual',
    };
  }
}

