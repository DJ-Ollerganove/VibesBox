import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/dj_song_blacklist_entry.dart';
import '../models/dj_song_blacklist_prefs.dart';
import '../helpers/security_helper.dart';
import '../utils/debug_log.dart';
import '../utils/wish_paths.dart';
import 'party_song_blacklist_service.dart';

/// Ein Dokument `dj_song_blacklists/{djId}` — öffentlich lesbar für Wunsch-Submit.
class DjSongBlacklistService {
  DjSongBlacklistService._();

  static final DjSongBlacklistService instance = DjSongBlacklistService._();

  static const collection = 'dj_song_blacklists';

  final ValueNotifier<DjSongBlacklistPrefs> prefsNotifier =
      ValueNotifier(DjSongBlacklistPrefs.defaults);

  /// Temporäre Party-Blacklist der aktiven DJ-Party (Guard hält den Stream).
  final ValueNotifier<List<DjSongBlacklistEntry>> activePartyEntriesNotifier =
      ValueNotifier(const <DjSongBlacklistEntry>[]);

  StreamSubscription<DjSongBlacklistPrefs>? _prefsSub;
  String? _watchDjId;
  bool _prefsReady = false;

  StreamSubscription<List<DjSongBlacklistEntry>>? _partyEntriesSub;
  String? _watchPartyId;

  StreamSubscription<DjSongBlacklistPrefs>? _guestPrefsSub;
  StreamSubscription<List<DjSongBlacklistEntry>>? _guestPartySub;
  String? _guestWatchDjId;
  String? _guestWatchPartyId;
  bool _guestPrefsReady = false;
  DjSongBlacklistPrefs _guestPrefs = DjSongBlacklistPrefs.defaults;
  List<DjSongBlacklistEntry> _guestPartyEntries = const [];

  DocumentReference<Map<String, dynamic>> _doc(String djId) {
    return FirebaseFirestore.instance.collection(collection).doc(djId);
  }

  void startWatching(String? djId) {
    if (djId == null || djId.isEmpty) {
      stopWatching();
      return;
    }
    if (_watchDjId == djId && _prefsSub != null) return;
    _prefsSub?.cancel();
    _watchDjId = djId;
    _prefsReady = false;
    _prefsSub = watchPrefs(djId).listen(
      (prefs) {
        _prefsReady = true;
        prefsNotifier.value = prefs;
      },
      onError: (e) => debugLog('DjSongBlacklistService.watchPrefs: $e'),
    );
  }

  void stopWatching() {
    _prefsSub?.cancel();
    _prefsSub = null;
    _watchDjId = null;
    _prefsReady = false;
    prefsNotifier.value = DjSongBlacklistPrefs.defaults;
    stopPartyWatching();
  }

  /// Ein Stream für die aktive Party — Guard + UI teilen denselben Notifier.
  void startPartyWatching(String? partyId) {
    final p = (partyId ?? '').trim();
    if (p.isEmpty) {
      stopPartyWatching();
      return;
    }
    if (_watchPartyId == p && _partyEntriesSub != null) return;
    _partyEntriesSub?.cancel();
    _watchPartyId = p;
    activePartyEntriesNotifier.value = const [];
    _partyEntriesSub = PartySongBlacklistService.instance.watch(p).listen(
      (entries) => activePartyEntriesNotifier.value = entries,
      onError: (e) {
        debugLog('DjSongBlacklistService.partyWatch: $e');
        activePartyEntriesNotifier.value = const [];
      },
    );
  }

  void stopPartyWatching() {
    _partyEntriesSub?.cancel();
    _partyEntriesSub = null;
    _watchPartyId = null;
    activePartyEntriesNotifier.value = const [];
  }

  String? get watchedPartyId => _watchPartyId;

  /// Gast-Wunschbox: eigener Snapshot, unabhängig vom DJ-Guard.
  void startGuestWatching({String? djId, String? partyId}) {
    final d = (djId ?? '').trim();
    final p = (partyId ?? '').trim();
    if (d.isEmpty) {
      stopGuestWatching();
      return;
    }
    if (_guestWatchDjId == d && _guestPrefsSub != null && _guestWatchPartyId == p) {
      return;
    }
    _guestPrefsSub?.cancel();
    _guestPartySub?.cancel();
    _guestWatchDjId = d;
    _guestWatchPartyId = p;
    _guestPrefsReady = false;
    _guestPrefs = DjSongBlacklistPrefs.defaults;
    _guestPartyEntries = const [];
    _guestPrefsSub = watchPrefs(d).listen(
      (prefs) {
        _guestPrefsReady = true;
        _guestPrefs = prefs;
      },
      onError: (e) => debugLog('DjSongBlacklistService.guestWatchPrefs: $e'),
    );
    if (p.isEmpty) return;
    _guestPartySub = PartySongBlacklistService.instance.watch(p).listen(
      (entries) => _guestPartyEntries = entries,
      onError: (e) => debugLog('DjSongBlacklistService.guestWatchParty: $e'),
    );
  }

  void stopGuestWatching() {
    _guestPrefsSub?.cancel();
    _guestPrefsSub = null;
    _guestPartySub?.cancel();
    _guestPartySub = null;
    _guestWatchDjId = null;
    _guestWatchPartyId = null;
    _guestPrefsReady = false;
    _guestPrefs = DjSongBlacklistPrefs.defaults;
    _guestPartyEntries = const [];
  }

  Stream<List<DjSongBlacklistEntry>> watch(String djId) {
    return watchPrefs(djId).map((prefs) => prefs.entries);
  }

  Stream<DjSongBlacklistPrefs> watchPrefs(String djId) {
    if (djId.isEmpty) {
      return Stream.value(DjSongBlacklistPrefs.defaults);
    }
    return _doc(djId).snapshots().map((snap) {
      return DjSongBlacklistPrefs.fromDoc(snap.data());
    });
  }

  Future<DjSongBlacklistPrefs> loadPrefs(String djId) async {
    if (djId.isEmpty) return DjSongBlacklistPrefs.defaults;
    if (_watchDjId == djId && _prefsReady) return prefsNotifier.value;
    if (_guestWatchDjId == djId && _guestPrefsReady) return _guestPrefs;
    try {
      final snap = await _doc(djId).get();
      return DjSongBlacklistPrefs.fromDoc(snap.data());
    } catch (e) {
      debugLog('DjSongBlacklistService.loadPrefs: $e');
      return DjSongBlacklistPrefs.defaults;
    }
  }

  Future<List<DjSongBlacklistEntry>> load(String djId) async {
    return (await loadPrefs(djId)).entries;
  }

  Future<SongBlacklistOutcome> decide({
    required String djId,
    required String title,
    required String artist,
    String? partyId,
  }) async {
    final prefs = await loadPrefs(djId);
    final extra = (partyId != null &&
            partyId.isNotEmpty &&
            partyId == _guestWatchPartyId)
        ? _guestPartyEntries
        : ((partyId != null && partyId.isNotEmpty)
            ? await PartySongBlacklistService.instance.load(partyId)
            : const <DjSongBlacklistEntry>[]);
    return prefs.outcomeFor(
      title: title,
      artist: artist,
      extraEntries: extra,
    );
  }

  Future<bool> hits({
    required String djId,
    required String title,
    required String artist,
    String? partyId,
  }) async {
    final outcome = await decide(
      djId: djId,
      title: title,
      artist: artist,
      partyId: partyId,
    );
    return outcome != SongBlacklistOutcome.none;
  }

  Future<bool> applyRejectIfHit({
    required Map<String, dynamic> wishData,
    required String djId,
    required String title,
    required String artist,
    String? partyId,
  }) async {
    if (djId.isEmpty) return false;
    final outcome = await decide(
      djId: djId,
      title: title,
      artist: artist,
      partyId: partyId,
    );
    if (outcome != SongBlacklistOutcome.rejectToDj) return false;
    wishData.addAll(rejectPatch());
    return true;
  }

  Future<void> save({
    required String djId,
    required List<DjSongBlacklistEntry> entries,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || djId.isEmpty || uid != djId) {
      throw StateError('Nicht angemeldet');
    }
    final prefs = await loadPrefs(djId);
    await _writeDoc(
      djId: djId,
      songs: entries,
      enabled: prefs.enabled,
      guestBlock: prefs.guestBlock,
    );
  }

  Future<void> saveSettings({
    required String djId,
    required bool enabled,
    required bool guestBlock,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || djId.isEmpty || uid != djId) {
      throw StateError('Nicht angemeldet');
    }
    final songs = (await loadPrefs(djId)).entries;
    await _writeDoc(
      djId: djId,
      songs: songs,
      enabled: enabled,
      guestBlock: guestBlock,
    );
  }

  Future<void> _writeDoc({
    required String djId,
    required List<DjSongBlacklistEntry> songs,
    required bool enabled,
    required bool guestBlock,
  }) async {
    await _doc(djId).set({
      'entries': DjSongBlacklistPrefs.entriesPayload(
        songs: songs,
        enabled: enabled,
        guestBlock: guestBlock,
      ),
      'enabled': enabled,
      'guest_block': guestBlock,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> addEntry({
    required String djId,
    String title = '',
    String artist = '',
  }) async {
    final t = SecurityHelper.sanitize(title, maxLength: 100);
    final a = SecurityHelper.sanitize(artist, maxLength: 100);
    if (t.isEmpty && a.isEmpty) return;
    final current = [...await load(djId)];
    if (DjSongBlacklistEntry.matches(
      title: t,
      artist: a,
      entries: current,
    )) {
      return;
    }
    current.add(
      DjSongBlacklistEntry(
        id: 'e_${DateTime.now().millisecondsSinceEpoch}',
        title: t,
        artist: a,
      ),
    );
    await save(djId: djId, entries: current);
  }

  Future<void> removeEntry({
    required String djId,
    required String entryId,
  }) async {
    final current = await load(djId);
    await save(
      djId: djId,
      entries: current.where((e) => e.id != entryId).toList(),
    );
  }

  Map<String, dynamic> rejectPatch() => <String, dynamic>{
        'status': 'rejected',
        'auto_rejected_by_blacklist': true,
        'rejection_reason': 'song_blacklist',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejected_at': FieldValue.serverTimestamp(),
      };

  /// Wish-IDs, die Offen nicht nochmal als Live-Hinweis anzeigen soll (z. B. DJ hat selbst gespeichert).
  final Set<String> _skipLiveHintIds = {};

  void skipLiveHintFor(Iterable<String> wishIds) {
    for (final id in wishIds) {
      if (id.isNotEmpty) _skipLiveHintIds.add(id);
    }
  }

  bool takeLiveHintSkip(String wishId) => _skipLiveHintIds.remove(wishId);

  /// Nach „Zurück zu Offen“: Guard soll denselben Wunsch nicht sofort wieder ablehnen.
  final Set<String> _skipAutoRejectIds = {};

  void skipAutoRejectFor(Iterable<String> wishIds) {
    for (final id in wishIds) {
      if (id.isEmpty) continue;
      _skipAutoRejectIds.add(id);
      _skipLiveHintIds.add(id);
    }
  }

  bool shouldSkipAutoReject(String wishId) =>
      wishId.isNotEmpty && _skipAutoRejectIds.contains(wishId);

  Future<void> rejectWishIds({
    required String partyId,
    required List<String> wishIds,
  }) async {
    if (partyId.isEmpty || wishIds.isEmpty) return;
    final patch = rejectPatch();
    final batch = FirebaseFirestore.instance.batch();
    var n = 0;
    for (final id in wishIds) {
      if (id.isEmpty) continue;
      batch.update(WishPaths.partyWish(partyId, id), patch);
      n++;
      if (n >= 400) break;
    }
    if (n == 0) return;
    await batch.commit();
  }

  Stream<List<DjBlacklistRejectHit>>? _hitsStream;
  String? _hitsPartyId;

  Stream<List<DjBlacklistRejectHit>> watchHits(String partyId) {
    if (partyId.isEmpty) {
      return Stream.value(const <DjBlacklistRejectHit>[]);
    }
    if (_hitsPartyId == partyId && _hitsStream != null) {
      return _hitsStream!;
    }
    _hitsPartyId = partyId;
    _hitsStream = WishPaths.partyWishes(partyId)
        .where('status', isEqualTo: 'rejected')
        .snapshots()
        .map((snap) {
      final out = <DjBlacklistRejectHit>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['auto_rejected_by_blacklist'] != true &&
            data['rejection_reason'] != 'song_blacklist') {
          continue;
        }
        final title = (data['title'] ?? data['song'] ?? '').toString().trim();
        final artist = (data['artist'] ?? '').toString().trim();
        out.add(
          DjBlacklistRejectHit(
            id: doc.id,
            title: title,
            artist: artist,
          ),
        );
      }
      return out;
    }).asBroadcastStream();
    return _hitsStream!;
  }

  Stream<int> watchHitCount(String partyId) {
    return watchHits(partyId).map((hits) => hits.length);
  }
}

class DjBlacklistRejectHit {
  const DjBlacklistRejectHit({
    required this.id,
    required this.title,
    required this.artist,
  });

  final String id;
  final String title;
  final String artist;

  String get songLabel {
    if (title.isNotEmpty && artist.isNotEmpty) return '$title – $artist';
    if (title.isNotEmpty) return title;
    return artist;
  }
}
