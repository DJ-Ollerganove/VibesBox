import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/dj_song_blacklist_entry.dart';
import '../models/dj_song_blacklist_prefs.dart';
import '../utils/debug_log.dart';
import 'active_party_service.dart';
import 'dj_song_blacklist_service.dart';
import 'open_wishes_visibility_service.dart';
import 'wish_management_service.dart';

/// Sicherheitsnetz: pending-Wünsche, die auf der Blacklist stehen, nach Abgelehnt.
class DjSongBlacklistGuard {
  DjSongBlacklistGuard._();

  static final DjSongBlacklistGuard instance = DjSongBlacklistGuard._();

  StreamSubscription<QuerySnapshot>? _wishSub;
  DjSongBlacklistPrefs _prefs = DjSongBlacklistPrefs.defaults;
  List<DjSongBlacklistEntry> _partyEntries = const [];
  List<QueryDocumentSnapshot> _lastPending = const [];
  String? _partyId;
  String? _djId;
  bool _listening = false;
  final Set<String> _busyIds = {};
  /// Bereits gegen aktuelle Blacklist geprüft (kein Treffer) — nicht bei jedem
  /// Pending-Snapshot erneut linear scannen.
  final Set<String> _clearedIds = {};

  void start(String? djId) {
    if (djId == null || djId.isEmpty) {
      stop();
      return;
    }
    if (_djId == djId && _listening) {
      _onSession();
      return;
    }
    stop();
    _djId = djId;
    _listening = true;
    final svc = DjSongBlacklistService.instance;
    svc.startWatching(djId);
    _prefs = svc.prefsNotifier.value;
    svc.prefsNotifier.addListener(_onPrefsNotifier);
    svc.activePartyEntriesNotifier.addListener(_onPartyEntriesNotifier);
    ActivePartyService.storedSessionNotifier.addListener(_onSession);
    _onSession();
  }

  void stop() {
    ActivePartyService.storedSessionNotifier.removeListener(_onSession);
    final svc = DjSongBlacklistService.instance;
    if (_listening) {
      svc.prefsNotifier.removeListener(_onPrefsNotifier);
      svc.activePartyEntriesNotifier.removeListener(_onPartyEntriesNotifier);
    }
    _wishSub?.cancel();
    _wishSub = null;
    svc.stopWatching();
    _listening = false;
    _djId = null;
    _partyId = null;
    _prefs = DjSongBlacklistPrefs.defaults;
    _partyEntries = const [];
    _lastPending = const [];
    _busyIds.clear();
    _clearedIds.clear();
  }

  void _onPrefsNotifier() {
    _prefs = DjSongBlacklistService.instance.prefsNotifier.value;
    _clearedIds.clear();
    final pid = _partyId;
    if (pid != null && pid.isNotEmpty) {
      unawaited(_handlePending(pid, _lastPending));
    }
  }

  void _onPartyEntriesNotifier() {
    _partyEntries =
        DjSongBlacklistService.instance.activePartyEntriesNotifier.value;
    _clearedIds.clear();
    final pid = _partyId;
    if (pid != null && pid.isNotEmpty) {
      unawaited(_handlePending(pid, _lastPending));
    }
  }

  void _onSession() {
    final pid = OpenWishesVisibilityService.resolveDjWishPartyId() ??
        ActivePartyService.getStoredSession()?.partyId ??
        ActivePartyService.currentPartyId;
    if (pid == _partyId && _wishSub != null) return;
    _partyId = pid;
    _wishSub?.cancel();
    _wishSub = null;
    _lastPending = const [];
    _busyIds.clear();
    _clearedIds.clear();
    DjSongBlacklistService.instance.startPartyWatching(pid);
    _partyEntries =
        DjSongBlacklistService.instance.activePartyEntriesNotifier.value;
    if (pid == null || pid.isEmpty) return;
    _wishSub = WishManagementService.getWishesStream(pid, 'pending').listen(
      (snap) {
        _lastPending = snap.docs;
        unawaited(_handlePending(pid, snap.docs));
      },
      onError: (e) => debugLog('DjSongBlacklistGuard wishes: $e'),
    );
  }

  Future<void> _handlePending(
    String partyId,
    List<QueryDocumentSnapshot> docs,
  ) async {
    if (docs.isEmpty) return;
    final currentIds = <String>{};
    for (final doc in docs) {
      if (doc.id.isNotEmpty) currentIds.add(doc.id);
    }
    _busyIds.removeWhere((id) => !currentIds.contains(id));
    _clearedIds.removeWhere((id) => !currentIds.contains(id));

    if (!_prefs.enabled) return;
    final entries = <DjSongBlacklistEntry>[
      ..._prefs.entries,
      ..._partyEntries,
    ];
    if (entries.isEmpty) return;
    final ids = <String>[];
    for (final doc in docs) {
      final id = doc.id;
      if (id.isEmpty || _busyIds.contains(id) || _clearedIds.contains(id)) {
        continue;
      }
      if (DjSongBlacklistService.instance.shouldSkipAutoReject(id)) {
        _clearedIds.add(id);
        continue;
      }
      final data = doc.data() as Map<String, dynamic>? ?? const {};
      if (data['auto_rejected_by_blacklist'] == true) {
        _clearedIds.add(id);
        continue;
      }
      final title = (data['title'] ?? data['song'] ?? '').toString();
      final artist = (data['artist'] ?? '').toString();
      if (!DjSongBlacklistEntry.matches(
        title: title,
        artist: artist,
        entries: entries,
      )) {
        _clearedIds.add(id);
        continue;
      }
      ids.add(id);
      _busyIds.add(id);
    }
    if (ids.isEmpty) return;
    try {
      await DjSongBlacklistService.instance.rejectWishIds(
        partyId: partyId,
        wishIds: ids,
      );
    } catch (e) {
      debugLog('DjSongBlacklistGuard reject: $e');
      for (final id in ids) {
        _busyIds.remove(id);
      }
    }
  }
}

void syncDjSongBlacklistGuard() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    DjSongBlacklistGuard.instance.stop();
    return;
  }
  DjSongBlacklistGuard.instance.start(uid);
}
