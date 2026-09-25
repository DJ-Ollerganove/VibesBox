import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../helpers/security_helper.dart';
import '../models/dj_song_blacklist_entry.dart';
import '../utils/debug_log.dart';

/// Temporäre Blacklist einer einzelnen Party: `party_song_blacklists/{partyId}`.
/// Ein Dokument, Write nur beim Hinzufügen/Entfernen — kein Dauerschreiben.
class PartySongBlacklistService {
  PartySongBlacklistService._();

  static final PartySongBlacklistService instance = PartySongBlacklistService._();

  static const collection = 'party_song_blacklists';
  static const _maxEntries = 200;

  DocumentReference<Map<String, dynamic>> _doc(String partyId) {
    return FirebaseFirestore.instance.collection(collection).doc(partyId);
  }

  Stream<List<DjSongBlacklistEntry>> watch(String partyId) {
    if (partyId.isEmpty) {
      return Stream.value(const <DjSongBlacklistEntry>[]);
    }
    return _doc(partyId).snapshots().map((snap) {
      return DjSongBlacklistEntry.listFrom(snap.data()?['entries']);
    });
  }

  Future<List<DjSongBlacklistEntry>> load(String partyId) async {
    if (partyId.isEmpty) return const [];
    try {
      final snap = await _doc(partyId).get();
      return DjSongBlacklistEntry.listFrom(snap.data()?['entries']);
    } catch (e) {
      debugLog('PartySongBlacklistService.load: $e');
      return const [];
    }
  }

  Future<void> save({
    required String partyId,
    required List<DjSongBlacklistEntry> entries,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || partyId.isEmpty) {
      throw StateError('Nicht angemeldet');
    }
    final trimmed =
        entries.length > _maxEntries ? entries.sublist(0, _maxEntries) : entries;
    await _doc(partyId).set({
      'entries': trimmed.map((e) => e.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addEntry({
    required String partyId,
    String title = '',
    String artist = '',
  }) async {
    final t = SecurityHelper.sanitize(title, maxLength: 100);
    final a = SecurityHelper.sanitize(artist, maxLength: 100);
    if (t.isEmpty && a.isEmpty) return;
    final current = [...await load(partyId)];
    if (DjSongBlacklistEntry.matches(
      title: t,
      artist: a,
      entries: current,
    )) {
      return;
    }
    current.add(
      DjSongBlacklistEntry(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}',
        title: t,
        artist: a,
      ),
    );
    await save(partyId: partyId, entries: current);
  }

  Future<void> removeEntry({
    required String partyId,
    required String entryId,
  }) async {
    final current = await load(partyId);
    await save(
      partyId: partyId,
      entries: current.where((e) => e.id != entryId).toList(),
    );
  }
}
