import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/app_config.dart';
import 'user_service.dart';
import '../utils/debug_log.dart';

/// Statistik für eine einzelne Party
class PartyStatistics {
  final int totalWishes;
  final int chartPlayed;
  final int chartRejected;
  final int chartOpen;
  final int chartDeleted;

  const PartyStatistics({
    required this.totalWishes,
    required this.chartPlayed,
    required this.chartRejected,
    required this.chartOpen,
    required this.chartDeleted,
  });
}

/// Service für Party-spezifische Statistiken
class PartyStatisticsService {
  /// Berechnet die effektive DJ-ID
  /// Wenn Admin eingeloggt ist, verwendet adminDjId (rtJXMTULzTPUz0xtdQOw9Jm8SGD3)
  /// Sonst die übergebene djId oder die aktuelle User-ID
  static String _getEffectiveDjId(String? djId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return djId ?? '';
    }
    
    final current = UserService().currentUser.value;
    final isAdmin = current != null && current.id == user.uid && AppConfig.isAdminRole(current);
    
    // Wenn Admin: Verwende adminDjId, unabhängig von der übergebenen djId
    if (isAdmin && AppConfig.adminDjId != null) {
      debugLog('🔧 PartyStatisticsService: Admin erkannt, erzwinge adminDjId: ${AppConfig.adminDjId}');
      return AppConfig.adminDjId!;
    }
    
    // Normaler User: Verwende übergebene djId oder User-ID
    return djId ?? user.uid;
  }
  
  /// Lädt Statistiken für eine bestimmte Party
  /// Filtert nach partyId (und optional djId für Sicherheit)
  static Future<PartyStatistics> loadForParty({
    required String partyId,
    String? djId,
  }) async {
    if (partyId.isEmpty) {
      return const PartyStatistics(
        totalWishes: 0,
        chartPlayed: 0,
        chartRejected: 0,
        chartOpen: 0,
        chartDeleted: 0,
      );
    }

    try {
      // ERZwinge die effektive DJ-ID
      final effectiveDjId = _getEffectiveDjId(djId);
      debugLog('DEBUG STATS: Abfrage läuft für DJ-ID: $effectiveDjId (adminDjId: ${AppConfig.adminDjId})');
      
      Query query = FirebaseFirestore.instance
          .collection('wishes')
          .where('party_id', isEqualTo: partyId);

      // Verwende die effektive DJ-ID für den Filter
      if (effectiveDjId.isNotEmpty) {
        query = query.where('djId', isEqualTo: effectiveDjId);
      }

      final wishesQuery = await query.get();
      final docs = wishesQuery.docs;
      final total = docs.length;

      debugLog('🔍 ========== WISHES COLLECTION DEBUG ==========');
      debugLog('🔍 Collection: wishes');
      debugLog('🔍 Filter: party_id == $partyId');
      debugLog('🔍 Gefundene Dokumente: $total\n');
      
      for (int i = 0; i < docs.length; i++) {
        final doc = docs[i];
        final data = doc.data() as Map<String, dynamic>;
        debugLog('--- Dokument ${i + 1} (ID: ${doc.id}) ---');
        debugLog('  party_id: ${data['party_id']}');
        debugLog('  status: ${data['status']}');
        debugLog('  title: ${data['title']}');
        debugLog('  artist: ${data['artist']}');
        debugLog('  djId: ${data['djId']}');
        debugLog('  created_at: ${data['created_at']}');
        debugLog('  createdAt: ${data['createdAt']}');
        debugLog('  deleted: ${data['deleted']}');
        debugLog('');
      }
      debugLog('🔍 ============================================\n');

      int played = 0;
      int rejected = 0;
      int open = 0;
      int deleted = 0;

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isDeleted = data['deleted'] as bool? ?? false;
        if (isDeleted) {
          deleted++;
          continue;
        }

        final status = data['status'] as String?;
        if (status == 'played') {
          played++;
        } else if (status == 'rejected') {
          rejected++;
        } else if (status == 'pending' || status == 'open' || status == null) {
          open++;
        } else {
          // Alle anderen Status zählen als offen
          open++;
        }
      }

      return PartyStatistics(
        totalWishes: total,
        chartPlayed: played,
        chartRejected: rejected,
        chartOpen: open,
        chartDeleted: deleted,
      );
    } catch (e) {
      debugLog('❌ PartyStatisticsService: Fehler beim Laden der Party-Statistik: $e');
      return const PartyStatistics(
        totalWishes: 0,
        chartPlayed: 0,
        chartRejected: 0,
        chartOpen: 0,
        chartDeleted: 0,
      );
    }
  }

  /// Stream für Party-Statistiken (Echtzeit-Updates)
  static Stream<PartyStatistics> loadForPartyStream({
    required String partyId,
    String? djId,
  }) {
    if (partyId.isEmpty) {
      return Stream.value(const PartyStatistics(
        totalWishes: 0,
        chartPlayed: 0,
        chartRejected: 0,
        chartOpen: 0,
        chartDeleted: 0,
      ));
    }

    // ERZwinge die effektive DJ-ID
    final effectiveDjId = _getEffectiveDjId(djId);
    debugLog('DEBUG STATS: Stream-Abfrage läuft für DJ-ID: $effectiveDjId (adminDjId: ${AppConfig.adminDjId})');

    Query query = FirebaseFirestore.instance
        .collection('wishes')
        .where('party_id', isEqualTo: partyId);

    // Verwende die effektive DJ-ID für den Filter
    if (effectiveDjId.isNotEmpty) {
      query = query.where('djId', isEqualTo: effectiveDjId);
    }

    return query.snapshots().map((snapshot) {
      final docs = snapshot.docs;
      final total = docs.length;

      int played = 0;
      int rejected = 0;
      int open = 0;
      int deleted = 0;

      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isDeleted = data['deleted'] as bool? ?? false;
        if (isDeleted) {
          deleted++;
          continue;
        }

        final status = data['status'] as String?;
        if (status == 'played') {
          played++;
        } else if (status == 'rejected') {
          rejected++;
        } else if (status == 'pending' || status == 'open' || status == null) {
          open++;
        } else {
          // Alle anderen Status zählen als offen
          open++;
        }
      }

      return PartyStatistics(
        totalWishes: total,
        chartPlayed: played,
        chartRejected: rejected,
        chartOpen: open,
        chartDeleted: deleted,
      );
    });
  }

  /// Findet die letzte abgeschlossene Party-Session für einen DJ
  /// Gibt die partyId der letzten Session zurück (mit endTime)
  /// Führt automatisch eine Bereinigung durch: Setzt offene Wünsche auf "not_played"
  static Future<String?> getLastCompletedPartyId(String djId) async {
    try {
      // ERZwinge die effektive DJ-ID
      final effectiveDjId = _getEffectiveDjId(djId);
      debugLog('DEBUG STATS: Abfrage läuft für DJ-ID: $effectiveDjId (adminDjId: ${AppConfig.adminDjId})');
      
      // Suche in music_history nach der letzten abgeschlossenen Session
      final sessionsQuery = await FirebaseFirestore.instance
          .collection('music_history')
          .where('djId', isEqualTo: effectiveDjId)
          .where('isActive', isEqualTo: false)
          .orderBy('endTime', descending: true)
          .limit(1)
          .get();

      if (sessionsQuery.docs.isEmpty) {
        return null;
      }

      final sessionData = sessionsQuery.docs.first.data() as Map<String, dynamic>;
      final partyId = sessionData['partyId'] as String?;
      
      // Bereinigung: Setze offene Wünsche auf "not_played" wenn Party beendet ist
      if (partyId != null && partyId.isNotEmpty && partyId != 'manual') {
        await _cleanupPendingWishesForEndedParty(partyId, effectiveDjId);
      }
      
      return partyId;
    } catch (e) {
      debugLog('❌ PartyStatisticsService: Fehler beim Finden der letzten Party: $e');
      return null;
    }
  }

  /// Bereinigt offene Wünsche einer beendeten Party (setzt sie auf "not_played")
  /// Wird automatisch aufgerufen, wenn eine beendete Party geladen wird
  /// Verwendet die übergebene djId für zusätzliche Sicherheit
  static Future<void> _cleanupPendingWishesForEndedParty(String partyId, String djId) async {
    try {
      // Prüfe ob Party existiert und beendet ist
      final partyDoc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .get();

      if (!partyDoc.exists) {
        return;
      }

      final partyData = partyDoc.data() as Map<String, dynamic>?;
      final endTimestamp = partyData?['end_date'] as Timestamp?;

      if (endTimestamp == null) {
        return;
      }

      final now = DateTime.now();
      final endDate = endTimestamp.toDate();

      // Nur bereinigen, wenn Party wirklich beendet ist
      if (now.compareTo(endDate) < 0) {
        return; // Party ist noch nicht beendet
      }

      // Finde pending-Wünsche für diese Party (mit djId-Filter für Sicherheit)
      Query wishesQuery = FirebaseFirestore.instance
          .collection('wishes')
          .where('status', isEqualTo: 'pending')
          .where('party_id', isEqualTo: partyId);
      
      // Zusätzlicher Filter nach djId für Sicherheit (verwendet die effektive DJ-ID)
      if (djId.isNotEmpty) {
        wishesQuery = wishesQuery.where('djId', isEqualTo: djId);
      }
      
      final wishesSnapshot = await wishesQuery.get();

      if (wishesSnapshot.docs.isEmpty) {
        return; // Keine pending-Wünsche
      }

      // Batch-Update für alle pending-Wünsche (max. 500 pro Batch)
      const BATCH_LIMIT = 450; // Puffer unter 500
      int processed = 0;

      for (int i = 0; i < wishesSnapshot.docs.length; i += BATCH_LIMIT) {
        final batch = FirebaseFirestore.instance.batch();
        final endIndex = (i + BATCH_LIMIT < wishesSnapshot.docs.length)
            ? i + BATCH_LIMIT
            : wishesSnapshot.docs.length;

        for (int j = i; j < endIndex; j++) {
          final wishDoc = wishesSnapshot.docs[j];
          batch.update(wishDoc.reference, {
            'status': 'not_played',
            'status_changed_at': FieldValue.serverTimestamp(),
            'status_reason': 'party_ended',
          });
          processed++;
        }

        await batch.commit();
      }

      debugLog('✅ PartyStatisticsService: $processed Wünsche auf "not_played" gesetzt');
    } catch (e) {
      debugLog('❌ PartyStatisticsService: Fehler bei der Bereinigung: $e');
      // Fehler nicht weiterwerfen, da dies eine Hintergrund-Bereinigung ist
    }
  }

  /// Findet die aktive Party-ID für einen DJ
  /// Prüft music_history (isActive: true) - fokussiert auf adminDjId
  /// Gibt null zurück wenn keine aktive Party gefunden (Fallback wird in _loadPartyId() gehandhabt)
  static Future<String?> getActivePartyId(String djId) async {
    try {
      // ERZwinge die effektive DJ-ID
      final effectiveDjId = _getEffectiveDjId(djId);
      
      // Fokussiere Suche auf music_history (schneller als parties durchsuchen)
      final activeSessionQuery = await FirebaseFirestore.instance
          .collection('music_history')
          .where('djId', isEqualTo: effectiveDjId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (activeSessionQuery.docs.isNotEmpty) {
        final sessionData = activeSessionQuery.docs.first.data() as Map<String, dynamic>;
        final partyId = sessionData['partyId'] as String?;
        if (partyId != null && partyId.isNotEmpty) {
          return partyId;
        }
      }

      // Keine aktive Party gefunden - Fallback wird in _loadPartyId() gehandhabt
      return null;
    } catch (e) {
      debugLog('❌ PartyStatisticsService: Fehler beim Finden der aktiven Party: $e');
      return null;
    }
  }

  /// Stream für aktive Party-ID (Echtzeit-Updates)
  /// Prüft music_history (isActive: true) - fokussiert auf adminDjId
  /// Gibt null zurück wenn keine aktive Party gefunden
  /// Reagiert in Echtzeit auf Änderungen des Party-Status
  static Stream<String?> getActivePartyIdStream(String djId) {
    try {
      // ERZwinge die effektive DJ-ID
      final effectiveDjId = _getEffectiveDjId(djId);
      
      // Fokussiere Suche auf music_history (schneller als parties durchsuchen)
      return FirebaseFirestore.instance
          .collection('music_history')
          .where('djId', isEqualTo: effectiveDjId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              final sessionData = snapshot.docs.first.data() as Map<String, dynamic>;
              final partyId = sessionData['partyId'] as String?;
              if (partyId != null && partyId.isNotEmpty) {
                return partyId;
              }
            }
            // Keine aktive Party gefunden
            return null;
          });
    } catch (e) {
      debugLog('❌ PartyStatisticsService: Fehler beim Erstellen des Active-Party-Streams: $e');
      return Stream.value(null);
    }
  }
}

