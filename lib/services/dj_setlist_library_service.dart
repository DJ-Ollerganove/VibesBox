import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../helpers/security_helper.dart';
import '../models/dj_setlist_library_item.dart';
import '../models/event_setlist_track.dart';
import '../utils/debug_log.dart';
import 'music_catalog_service.dart';

/// DJ-eigene Setlisten: `users/{uid}/dj_setlists/{id}` — ein Doc pro Liste.
class DjSetlistLibraryService {
  DjSetlistLibraryService._();

  static final DjSetlistLibraryService instance = DjSetlistLibraryService._();

  static const _sub = 'dj_setlists';

  CollectionReference<Map<String, dynamic>>? _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(_sub);
  }

  Stream<List<DjSetlistLibraryItem>> watchMine() {
    final col = _col();
    if (col == null) {
      return Stream.value(const <DjSetlistLibraryItem>[]);
    }
    return col.snapshots().map((snap) {
      final items = snap.docs
          .map((d) => DjSetlistLibraryItem.fromDoc(d.id, d.data()))
          .toList();
      items.sort((a, b) => b.id.compareTo(a.id));
      return items;
    });
  }

  /// Party-Setlisten des DJs (ein Query, nicht pro Song).
  Future<List<DjSetlistLibraryItem>> loadAssignedFromParties() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('dj_setlists')
          .where('createdBy', isEqualTo: uid)
          .get();
      final out = <DjSetlistLibraryItem>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final tracks = EventSetlistTrack.listFrom(data['tracks']);
        if (tracks.isEmpty) continue;
        final name = (data['partyName'] as String?)?.trim();
        out.add(
          DjSetlistLibraryItem.partyStoreOnly(
            partyId: doc.id,
            title: (name != null && name.isNotEmpty) ? name : 'Party-Setliste',
            tracks: tracks,
            partyName: name,
          ),
        );
      }
      return out;
    } catch (e) {
      debugLog('DjSetlistLibraryService.loadAssignedFromParties: $e');
      return const [];
    }
  }

  Future<String> save({
    required String title,
    required List<EventSetlistTrack> tracks,
    String? partyId,
    String? partyName,
    List<String>? partyIds,
    Map<String, String>? partyNames,
    String? existingId,
  }) async {
    final col = _col();
    if (col == null) throw StateError('Nicht angemeldet');
    final id = (existingId != null && existingId.isNotEmpty)
        ? existingId
        : 'sl_${DateTime.now().millisecondsSinceEpoch}';
    final safeTitle = SecurityHelper.sanitize(title, maxLength: 200);
    final ids = <String>[];
    final names = <String, String>{};
    if (partyIds != null) {
      for (final raw in partyIds) {
        final p = SecurityHelper.sanitize(raw, maxLength: 120);
        if (p.isEmpty || ids.contains(p)) continue;
        ids.add(p);
        if (ids.length >= 50) break;
      }
    }
    final single = SecurityHelper.sanitize(partyId ?? '', maxLength: 120);
    if (single.isNotEmpty && !ids.contains(single)) {
      ids.insert(0, single);
    }
    if (partyNames != null) {
      partyNames.forEach((key, value) {
        final k = SecurityHelper.sanitize(key, maxLength: 120);
        final v = SecurityHelper.sanitize(value, maxLength: 200);
        if (k.isEmpty || v.isEmpty) return;
        names[k] = v;
      });
    }
    final pname = SecurityHelper.sanitize(partyName ?? '', maxLength: 200);
    if (single.isNotEmpty && pname.isNotEmpty) {
      names[single] = pname;
    }

    final payload = <String, dynamic>{
      'title': safeTitle.isEmpty ? 'KI-Setliste' : safeTitle,
      'tracks': tracks.map((e) => e.toJson()).toList(),
      'targetCount': tracks.length,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (existingId == null || existingId.isEmpty) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    final touchParties = partyIds != null ||
        partyNames != null ||
        (partyId != null && partyId.trim().isNotEmpty) ||
        (partyName != null && partyName.trim().isNotEmpty);
    if (touchParties) {
      payload['partyIds'] = ids;
      payload['partyNames'] = names;
      if (ids.isNotEmpty) {
        payload['partyId'] = ids.first;
        final n0 = names[ids.first];
        if (n0 != null && n0.isNotEmpty) payload['partyName'] = n0;
      }
    }
    await col.doc(id).set(payload, SetOptions(merge: true));
    MusicCatalogService.instance.syncSetlistTracks(
      tracks,
      countAsSuggested: existingId == null || existingId.isEmpty,
    );
    return id;
  }

  /// Party einer bestehenden Library-Liste zuordnen (ohne neues Doc).
  Future<void> assignParty({
    required String listId,
    required String partyId,
    required String partyName,
    required List<EventSetlistTrack> tracks,
  }) async {
    final col = _col();
    if (col == null || listId.isEmpty || listId.startsWith('party_')) {
      throw StateError('Ungültige Setliste');
    }
    final pid = SecurityHelper.sanitize(partyId, maxLength: 120);
    final pname = SecurityHelper.sanitize(partyName, maxLength: 200);
    if (pid.isEmpty) throw StateError('Keine Party');
    final ref = col.doc(listId);
    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};
    final item = DjSetlistLibraryItem.fromDoc(listId, data);
    if (item.partyIds.contains(pid)) {
      await replaceTracks(id: listId, tracks: tracks);
      return;
    }
    final nextIds = [...item.partyIds, pid];
    final nextNames = Map<String, String>.from(item.partyNames);
    if (pname.isNotEmpty) nextNames[pid] = pname;
    await ref.set(
      {
        'tracks': tracks.map((e) => e.toJson()).toList(),
        'targetCount': tracks.length,
        'partyIds': nextIds,
        'partyNames': nextNames,
        'partyId': nextIds.first,
        if (nextNames[nextIds.first] != null)
          'partyName': nextNames[nextIds.first],
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    MusicCatalogService.instance.syncSetlistTracks(
      tracks,
      countAsSuggested: false,
    );
  }

  Future<void> replaceTracks({
    required String id,
    required List<EventSetlistTrack> tracks,
  }) async {
    final col = _col();
    if (col == null || id.isEmpty || id.startsWith('party_')) return;
    try {
      await col.doc(id).update({
        'tracks': tracks.map((e) => e.toJson()).toList(),
        'targetCount': tracks.length,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      MusicCatalogService.instance.syncSetlistTracks(
        tracks,
        countAsSuggested: false,
      );
    } catch (e) {
      debugLog('DjSetlistLibraryService.replaceTracks: $e');
      rethrow;
    }
  }

  Future<void> replaceTracksByPartyId({
    required String partyId,
    required List<EventSetlistTrack> tracks,
  }) async {
    final col = _col();
    if (col == null || partyId.isEmpty) return;
    try {
      final payload = <String, dynamic>{
        'tracks': tracks.map((e) => e.toJson()).toList(),
        'targetCount': tracks.length,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final seen = <String>{};
      final legacy = await col.where('partyId', isEqualTo: partyId).get();
      for (final doc in legacy.docs) {
        seen.add(doc.id);
        await col.doc(doc.id).update(payload);
      }
      final multi =
          await col.where('partyIds', arrayContains: partyId).get();
      for (final doc in multi.docs) {
        if (seen.contains(doc.id)) continue;
        await col.doc(doc.id).update(payload);
      }
    } catch (e) {
      debugLog('DjSetlistLibraryService.replaceTracksByPartyId: $e');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    final col = _col();
    if (col == null || id.isEmpty || id.startsWith('party_')) return;
    try {
      await col.doc(id).delete();
    } catch (e) {
      debugLog('DjSetlistLibraryService.delete: $e');
      rethrow;
    }
  }
}
