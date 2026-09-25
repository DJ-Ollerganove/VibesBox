import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../helpers/security_helper.dart';
import '../models/event_setlist_track.dart';
import '../utils/debug_log.dart';
import 'music_catalog_service.dart';

/// Ein Dokument pro Party: `dj_setlists/{partyId}` — nicht in Offen/Vorab.
class DjSetlistStoreService {
  DjSetlistStoreService._();

  static final DjSetlistStoreService instance = DjSetlistStoreService._();

  static const _collection = 'dj_setlists';

  DocumentReference<Map<String, dynamic>> _doc(String partyId) {
    return FirebaseFirestore.instance.collection(_collection).doc(partyId);
  }

  Stream<List<EventSetlistTrack>> watch(String partyId) {
    if (partyId.isEmpty) {
      return Stream.value(const <EventSetlistTrack>[]);
    }
    return _doc(partyId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return const <EventSetlistTrack>[];
      return EventSetlistTrack.listFrom(data['tracks']);
    });
  }

  Future<List<EventSetlistTrack>> loadTracks(String partyId) async {
    if (partyId.isEmpty) return const <EventSetlistTrack>[];
    try {
      final snap = await _doc(partyId).get();
      if (!snap.exists) return const <EventSetlistTrack>[];
      return EventSetlistTrack.listFrom(snap.data()?['tracks']);
    } catch (e) {
      debugLog('DjSetlistStoreService.loadTracks: $e');
      return const <EventSetlistTrack>[];
    }
  }

  /// Nur Anzahl für Badges — hält keine Track-Liste im Stream-State.
  Stream<int> watchTrackCount(String partyId) {
    if (partyId.isEmpty) return Stream.value(0);
    return _doc(partyId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return 0;
      final tc = data['targetCount'];
      if (tc is int && tc >= 0) {
        if (tc > 0) return tc;
        // targetCount 0 kann „leer“ bedeuten — Tracks kurz prüfen.
      }
      if (tc is num && tc.toInt() > 0) return tc.toInt();
      final raw = data['tracks'];
      if (raw is! List) return 0;
      return raw.length;
    });
  }

  Future<bool> exists(String partyId) async {
    if (partyId.isEmpty) return false;
    final snap = await _doc(partyId).get();
    if (!snap.exists) return false;
    return EventSetlistTrack.listFrom(snap.data()?['tracks']).isNotEmpty;
  }

  Future<Set<String>> partyIdsWithLists() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return <String>{};
    try {
      final snap = await FirebaseFirestore.instance
          .collection(_collection)
          .where('createdBy', isEqualTo: uid)
          .get();
      final ids = <String>{};
      for (final doc in snap.docs) {
        if (EventSetlistTrack.listFrom(doc.data()['tracks']).isEmpty) continue;
        ids.add(doc.id);
      }
      return ids;
    } catch (e) {
      debugLog('DjSetlistStoreService.partyIdsWithLists: $e');
      return <String>{};
    }
  }

  Future<void> save({
    required String partyId,
    required List<EventSetlistTrack> tracks,
    String? partyName,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || partyId.isEmpty) {
      throw StateError('Nicht angemeldet');
    }
    try {
      final payload = <String, dynamic>{
        'tracks': tracks.map((e) => e.toJson()).toList(),
        'createdBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'targetCount': tracks.length,
      };
      final name = SecurityHelper.sanitize(partyName ?? '', maxLength: 200);
      if (name.isNotEmpty) payload['partyName'] = name;
      await _doc(partyId).set(payload);
      // Zähler nur über Library-Save (sonst Doppelzählung mit Export-Menü).
      MusicCatalogService.instance.syncSetlistTracks(
        tracks,
        countAsSuggested: false,
      );
    } catch (e) {
      debugLog('DjSetlistStoreService.save: $e');
      rethrow;
    }
  }

  Future<void> replaceTracks({
    required String partyId,
    required List<EventSetlistTrack> tracks,
  }) async {
    if (partyId.isEmpty) return;
    try {
      await _doc(partyId).update({
        'tracks': tracks.map((e) => e.toJson()).toList(),
        'targetCount': tracks.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      MusicCatalogService.instance.syncSetlistTracks(
        tracks,
        countAsSuggested: false,
      );
    } catch (e) {
      debugLog('DjSetlistStoreService.replaceTracks: $e');
      rethrow;
    }
  }

  Future<void> delete(String partyId) async {
    if (partyId.isEmpty) return;
    try {
      await _doc(partyId).delete();
    } catch (e) {
      debugLog('DjSetlistStoreService.delete: $e');
      rethrow;
    }
  }
}
