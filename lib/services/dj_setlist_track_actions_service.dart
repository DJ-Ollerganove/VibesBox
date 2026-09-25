import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../helpers/security_helper.dart';
import '../models/dj_setlist_library_item.dart';
import '../models/event_setlist_track.dart';
import '../utils/debug_log.dart';
import '../utils/wish_paths.dart';
import 'dj_setlist_library_service.dart';
import 'dj_setlist_store_service.dart';
import 'dj_song_blacklist_service.dart';

/// Song aus DJ-Setliste entfernen bzw. als DJ-Wunsch nach Offen/Gespielt.
class DjSetlistTrackActionsService {
  DjSetlistTrackActionsService._();

  static final DjSetlistTrackActionsService instance =
      DjSetlistTrackActionsService._();

  Future<void> persistPartyTracks({
    required String partyId,
    required List<EventSetlistTrack> tracks,
  }) async {
    if (partyId.isEmpty) return;
    await DjSetlistStoreService.instance.replaceTracks(
      partyId: partyId,
      tracks: tracks,
    );
    await DjSetlistLibraryService.instance.replaceTracksByPartyId(
      partyId: partyId,
      tracks: tracks.map((t) => t.copyWith(moved: false)).toList(),
    );
  }

  Future<void> persistLibraryItem({
    required DjSetlistLibraryItem item,
    required List<EventSetlistTrack> tracks,
  }) async {
    if (item.isPartyStoreOnly) {
      final pid = item.partyId?.trim() ?? '';
      if (pid.isEmpty) return;
      await persistPartyTracks(partyId: pid, tracks: tracks);
      return;
    }
    await DjSetlistLibraryService.instance.replaceTracks(
      id: item.id,
      tracks: tracks,
    );
    final ids = item.partyIds.isNotEmpty
        ? item.partyIds
        : [
            if ((item.partyId ?? '').trim().isNotEmpty) item.partyId!.trim(),
          ];
    for (final pid in ids) {
      if (pid.isEmpty) continue;
      await DjSetlistStoreService.instance.replaceTracks(
        partyId: pid,
        tracks: tracks,
      );
    }
  }

  static const fromSetlistMarker = '__from_setlist__';

  List<EventSetlistTrack> markMoved(
    List<EventSetlistTrack> tracks,
    int index,
  ) {
    if (index < 0 || index >= tracks.length) return tracks;
    final next = [...tracks];
    next[index] = next[index].copyWith(moved: true);
    return next;
  }

  Future<void> createDjWish({
    required String partyId,
    required EventSetlistTrack track,
    required String status,
    bool fromSetlist = false,
    bool autoRecognized = false,
    String requestedByLabel = '',
  }) async {
    if (partyId.isEmpty) throw StateError('Keine Party');
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Nicht angemeldet');

    final partySnap = await FirebaseFirestore.instance
        .collection('parties')
        .doc(partyId)
        .get();
    final djId = (partySnap.data()?['created_by'] as String?)?.trim();
    if (djId == null || djId.isEmpty) {
      throw StateError('DJ-ID der Party konnte nicht ermittelt werden');
    }

    final by = fromSetlist
        ? fromSetlistMarker
        : (requestedByLabel.trim().isEmpty ? 'DJ' : requestedByLabel.trim());
    final wishData = <String, dynamic>{
      'name': '',
      'title': track.title,
      'artist': track.artist,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
      'duplicate_count': 0,
      'requested_by': [by],
      'greetings': <Map<String, dynamic>>[],
      'is_duplicate': false,
      'is_registered_user': true,
      'is_registered_users': <String, dynamic>{},
      'client_id': uid,
      'party_id': partyId,
      'dj_id': djId,
      'djId': djId,
      'isSeen': true,
      'is_dj_wish': true,
      if (fromSetlist) 'from_setlist': true,
      if (autoRecognized) 'auto_recognized': true,
    };
    if (status == 'played') {
      wishData['playedAt'] = FieldValue.serverTimestamp();
      wishData['played_at'] = FieldValue.serverTimestamp();
      if (autoRecognized) {
        wishData['recognized_at'] = FieldValue.serverTimestamp();
      }
    } else if (status == 'pending') {
      await DjSongBlacklistService.instance.applyRejectIfHit(
        wishData: wishData,
        djId: djId,
        title: track.title,
        artist: track.artist,
        partyId: partyId,
      );
    }

    try {
      await WishPaths.partyWishes(partyId)
          .add(SecurityHelper.sanitizeMap(wishData));
    } catch (e) {
      debugLog('DjSetlistTrackActionsService.createDjWish: $e');
      rethrow;
    }
  }

  /// Musikerkennung: alle noch nicht verschobenen Setlist-Treffer → Gespielt + moved.
  /// Ein Load + ein Persist; leichte Last nur bei erfolgreicher Erkennung.
  Future<int> markRecognizedMatchesPlayed({
    required String partyId,
    required String normalizedTitle,
    required String normalizedArtist,
    required List<String> ignored,
    required double threshold,
    required double Function(String a, String b) similarity,
    required String Function(String text, List<String> ignored) normalize,
  }) async {
    if (partyId.isEmpty) return 0;
    final tracks =
        await DjSetlistStoreService.instance.loadTracks(partyId);
    if (tracks.isEmpty) return 0;

    final matchIndexes = <int>[];
    for (var i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      if (t.moved) continue;
      final title = t.title.trim();
      final artist = t.artist.trim();
      if (title.isEmpty || artist.isEmpty) continue;
      final avg = (similarity(normalizedTitle, normalize(title, ignored)) +
              similarity(normalizedArtist, normalize(artist, ignored))) /
          2.0;
      if (avg >= threshold) matchIndexes.add(i);
    }
    if (matchIndexes.isEmpty) return 0;

    var next = [...tracks];
    for (final index in matchIndexes) {
      final track = next[index];
      try {
        await createDjWish(
          partyId: partyId,
          track: track,
          status: 'played',
          fromSetlist: true,
          autoRecognized: true,
        );
      } catch (e) {
        debugLog(
          'DjSetlistTrackActionsService.markRecognizedMatchesPlayed wish: $e',
        );
      }
      next = markMoved(next, index);
    }
    await persistPartyTracks(partyId: partyId, tracks: next);
    return matchIndexes.length;
  }
}
