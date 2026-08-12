import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/debug_log.dart';

/// Gemeinsame Auflösung von `music_history`-Sessions pro Party.
///
/// Problem: Schreiben (HistoryProvider) und UI/Heartbeat (ActivePartyService)
/// wählten unabhängig mit `limit(1)` — bei mehreren Sessions kann die UI
/// eine leere Session zeigen, während Tracks in einer anderen liegen.
class MusicHistorySessionResolver {
  MusicHistorySessionResolver._();

  /// Alle Sessions eines DJ für eine Party (`party_id` und Legacy `partyId`).
  static Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      fetchSessionsForParty({
    required FirebaseFirestore firestore,
    required String djId,
    required String partyId,
  }) async {
    if (partyId.isEmpty || partyId == 'manual' || djId.isEmpty) return [];

    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    Future<void> addQuery(String field) async {
      try {
        final snap = await firestore
            .collection('music_history')
            .where('djId', isEqualTo: djId)
            .where(field, isEqualTo: partyId)
            .get();
        for (final doc in snap.docs) {
          byId[doc.id] = doc;
        }
      } catch (e) {
        debugLog(
          'MusicHistorySessionResolver: Query $field fehlgeschlagen: $e',
        );
      }
    }

    await addQuery('party_id');
    await addQuery('partyId');
    return byId.values.toList();
  }

  /// Wählt die Session mit den meisten Tracks; bei Gleichstand die mit
  /// dem neuesten Track (sonst `startTime` / Doc-ID).
  static Future<String?> pickBestSessionId({
    required FirebaseFirestore firestore,
    required String djId,
    required String partyId,
  }) async {
    final sessions = await fetchSessionsForParty(
      firestore: firestore,
      djId: djId,
      partyId: partyId,
    );
    if (sessions.isEmpty) return null;
    if (sessions.length == 1) return sessions.first.id;

    String? bestId;
    var bestCount = -1;
    DateTime bestNewest = DateTime.fromMillisecondsSinceEpoch(0);

    for (final doc in sessions) {
      final tracksRef = doc.reference.collection('tracks');
      var count = 0;
      try {
        final agg = await tracksRef.count().get();
        count = agg.count ?? 0;
      } catch (_) {
        try {
          count = (await tracksRef.limit(50).get()).docs.length;
        } catch (e) {
          debugLog(
            'MusicHistorySessionResolver: Track-Count ${doc.id}: $e',
          );
        }
      }

      DateTime newest = DateTime.fromMillisecondsSinceEpoch(0);
      try {
        final newestSnap = await tracksRef
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
        if (newestSnap.docs.isNotEmpty) {
          final ts = newestSnap.docs.first.data()['timestamp'];
          if (ts is Timestamp) {
            newest = ts.toDate();
          } else if (ts is DateTime) {
            newest = ts;
          }
        }
      } catch (_) {
        // timestamp ggf. ohne Index / Feld — startTime der Session nutzen
        final start = doc.data()['startTime'];
        if (start is Timestamp) newest = start.toDate();
      }

      final betterCount = count > bestCount;
      final sameCountNewer =
          count == bestCount && newest.isAfter(bestNewest);
      if (betterCount || sameCountNewer || bestId == null) {
        bestId = doc.id;
        bestCount = count;
        bestNewest = newest;
      }
    }

    debugLog(
      'MusicHistorySessionResolver: Party $partyId → Session $bestId '
      '(Tracks≈$bestCount, ${sessions.length} Kandidaten)',
    );
    return bestId;
  }

  /// Findet beste Session oder legt eine neue an (kanonisch mit `party_id`).
  static Future<String?> ensureSession({
    required FirebaseFirestore firestore,
    required String djId,
    required String partyId,
    required String partyName,
    Map<String, dynamic> Function(Map<String, dynamic>)? sanitize,
  }) async {
    if (partyId.isEmpty || partyId == 'manual' || djId.isEmpty) return null;

    final existing = await pickBestSessionId(
      firestore: firestore,
      djId: djId,
      partyId: partyId,
    );
    if (existing != null) return existing;

    final sessionData = <String, dynamic>{
      'djId': djId,
      'party_id': partyId,
      'partyName': partyName,
      'startTime': FieldValue.serverTimestamp(),
      'endTime': null,
      'isActive': true,
    };
    final payload = sanitize != null ? sanitize(sessionData) : sessionData;
    final ref = await firestore.collection('music_history').add(payload);
    debugLog(
      'MusicHistorySessionResolver: neue Session ${ref.id} für Party $partyId',
    );
    return ref.id;
  }
}
