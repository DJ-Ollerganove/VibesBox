import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/saved_tracks_constants.dart';
import '../models/saved_track_model.dart';
import '../utils/callable_payload_serializer.dart';
import '../utils/debug_log.dart';
import '../utils/string_utils.dart';

enum SavedTrackAddResult { added, alreadyExists }

/// Merkliste: Firestore `users/{auth.uid}/saved_tracks/{docId}`.
/// Gespeichert: Titel, Interpret, optional party_id + source_wish_id, bookmarked_at.
class SavedTracksService {
  SavedTracksService._();

  static final ValueNotifier<Set<String>> savedDedupeKeys =
      ValueNotifier<Set<String>>({});

  static final ValueNotifier<List<SavedTrack>> savedTracks =
      ValueNotifier<List<SavedTrack>>([]);

  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _subscription;
  static String? _watchUid;
  static const String _callableRegion = 'us-central1';

  static CollectionReference<Map<String, dynamic>> _collection(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(SavedTracksConstants.subcollection);
  }

  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _callableRegion);

  static String dedupeKey(String title, String artist) {
    String norm(String s) =>
        unescapeHtml(s).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return '${norm(title)}|${norm(artist)}';
  }

  static String documentIdFor(String title, String artist) {
    final key = dedupeKey(title, artist);
    if (key.length <= 150) {
      return key.replaceAll(RegExp(r'[/\s.]'), '_');
    }
    final digest = base64Url.encode(utf8.encode(key));
    final compact = digest.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return 'k_${compact.substring(0, compact.length.clamp(0, 120))}';
  }

  static List<SavedTrack> _parseSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    final tracks = snap.docs.map(SavedTrack.fromFirestore).toList()
      ..sort((a, b) => b.bookmarkedAt.compareTo(a.bookmarkedAt));
    return tracks;
  }

  static void _publish(List<SavedTrack> tracks) {
    savedTracks.value = List<SavedTrack>.from(tracks);
    savedDedupeKeys.value =
        tracks.map((t) => dedupeKey(t.title, t.artist)).toSet();
    debugLog('📋 Merkliste: ${tracks.length} Titel');
  }

  static void _attachListener(String uid) {
    if (_watchUid == uid && _subscription != null) return;
    _subscription?.cancel();
    _watchUid = uid;
    _subscription = _collection(uid).snapshots().listen(
      (snap) => _publish(_parseSnapshot(snap)),
      onError: (e) => debugLog('❌ Merkliste Snapshot: $e'),
    );
  }

  static void startWatchingForCurrentUser() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      stopWatching();
      return;
    }
    _attachListener(uid);
  }

  static void stopWatching() {
    _subscription?.cancel();
    _subscription = null;
    _watchUid = null;
    _publish(const []);
  }

  static bool isSaved(String title, String artist) {
    return savedDedupeKeys.value.contains(dedupeKey(title, artist));
  }

  static SavedTrack _trackFromAdd({
    required String docId,
    required String title,
    required String artist,
    String? partyId,
    String? sourceWishId,
  }) {
    return SavedTrack(
      id: docId,
      title: title,
      artist: artist,
      bookmarkedAt: DateTime.now(),
      partyId: partyId,
      sourceWishId: sourceWishId,
    );
  }

  static void _optimisticAdd(SavedTrack track) {
    final key = dedupeKey(track.title, track.artist);
    final next = savedTracks.value
        .where((t) => dedupeKey(t.title, t.artist) != key)
        .toList()
      ..add(track)
      ..sort((a, b) => b.bookmarkedAt.compareTo(a.bookmarkedAt));
    _publish(next);
  }

  static void _optimisticRemove(String key) {
    _publish(
      savedTracks.value
          .where((t) => dedupeKey(t.title, t.artist) != key)
          .toList(),
    );
  }

  static Future<SavedTrackAddResult> addTrack({
    required String title,
    required String artist,
    String? partyId,
    String? sourceWishId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('not_authenticated');
    }
    _attachListener(uid);

    final t = unescapeHtml(title).trim();
    final a = unescapeHtml(artist).trim();
    if (t.isEmpty && a.isEmpty) {
      throw ArgumentError('title oder artist erforderlich');
    }

    final pid = partyId?.trim();
    final wishId = sourceWishId?.trim();

    final docId = documentIdFor(t, a);
    final ref = _collection(uid).doc(docId);

    final existing = await ref.get(const GetOptions(source: Source.server));
    if (existing.exists) {
      debugLog('📋 Merkliste: bereits vorhanden users/$uid/saved_tracks/$docId');
      return SavedTrackAddResult.alreadyExists;
    }

    final payload = <String, dynamic>{
      'title': t,
      'artist': a,
      'bookmarked_at': FieldValue.serverTimestamp(),
    };
    if (pid != null && pid.isNotEmpty) payload['party_id'] = pid;
    if (wishId != null && wishId.isNotEmpty) {
      payload['source_wish_id'] = wishId;
    }

    SavedTrackAddResult result;
    try {
      await ref.set(payload);
      debugLog('📋 Merkliste gespeichert: users/$uid/saved_tracks/$docId');
      result = SavedTrackAddResult.added;
    } on FirebaseException catch (e) {
      debugLog('⚠️ Merkliste Firestore set (${e.code}): ${e.message}');
      result = await _addTrackViaCallable(
        title: t,
        artist: a,
        partyId: pid,
        sourceWishId: wishId,
      );
    }

    if (result == SavedTrackAddResult.added) {
      _optimisticAdd(
        _trackFromAdd(
          docId: docId,
          title: t,
          artist: a,
          partyId: pid,
          sourceWishId: wishId,
        ),
      );
    }

    return result;
  }

  static Future<SavedTrackAddResult> _addTrackViaCallable({
    required String title,
    required String artist,
    String? partyId,
    String? sourceWishId,
  }) async {
    final trackPayload = <String, dynamic>{
      'title': title,
      'artist': artist,
      if (partyId != null && partyId.isNotEmpty) 'party_id': partyId,
      if (sourceWishId != null && sourceWishId.isNotEmpty)
        'source_wish_id': sourceWishId,
    };
    final callable = _functions.httpsCallable('manageSavedTrack');
    final result = await callable.call<dynamic>({
      'action': 'add',
      'track': serializeForCallable(trackPayload),
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    debugLog('📋 Merkliste Callable add: $data');
    return data['alreadyExists'] == true
        ? SavedTrackAddResult.alreadyExists
        : SavedTrackAddResult.added;
  }

  static Future<void> removeTrack({
    required String title,
    required String artist,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    _attachListener(uid);

    final t = unescapeHtml(title).trim();
    final a = unescapeHtml(artist).trim();
    final key = dedupeKey(t, a);
    final docId = documentIdFor(t, a);
    _optimisticRemove(key);

    try {
      await _collection(uid).doc(docId).delete();
      debugLog('📋 Merkliste gelöscht: users/$uid/saved_tracks/$docId');
    } on FirebaseException catch (e) {
      debugLog('⚠️ Merkliste delete (${e.code}): ${e.message}');
      final callable = _functions.httpsCallable('manageSavedTrack');
      await callable.call<dynamic>({
        'action': 'remove',
        'title': t,
        'artist': a,
      });
    }
  }
}
