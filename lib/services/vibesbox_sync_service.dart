import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/song_recommendation.dart';
import '../utils/camelot_helper.dart';
import '../utils/debug_log.dart';
import 'party_autostart_service.dart';
import 'rb_tool_service.dart';
import 'shazam_service.dart';
import 'user_self_settings_service.dart';
import 'user_service.dart';

/// Rekordbox-Tool (VibesBox Sync) statt Mikrofon-Erkennung.
/// Sichtbar mit Einzelfreigabe, für das Plattform-Admin-Konto,
/// oder für jeden DJ wenn `admin_config/sync_tool.enabled_for_all` an ist.
class VibesBoxSyncService extends ChangeNotifier {
  VibesBoxSyncService._();
  static final VibesBoxSyncService instance = VibesBoxSyncService._();

  static String _prefsKey(String uid) => 'vibesbox_sync_enabled_$uid';
  static const Duration idleAfter = Duration(minutes: 10);

  bool _enabled = false;
  bool _enabledForAll = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _accessSub;
  bool _reportedConnected = false;
  String _device = '';
  bool _initialized = false;
  bool _ingestInFlight = false;
  bool _authInFlight = false;
  bool _authAgain = false;
  bool _persistInFlight = false;
  String? _uid;
  String? _lastIngestKey;
  Timer? _idleTimer;
  Timer? _historyRetryTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveSub;
  int _listenGen = 0;
  bool _liveDocAbsent = false;
  Map<String, dynamic>? _nowPlaying;
  List<SongRecommendation> _suggestions = const [];
  String? _suggestionsSeed;
  bool _suggestionsReady = false;

  bool get enabled => _enabled;

  /// Admin-Startseite: ein Dokument, kein Schreiben auf alle DJ-Konten.
  bool get enabledForAll => _enabledForAll;
  /// Eingeloggt heißt: in der Datenbank steht diese Verbindung noch.
  /// Ein zugeklapptes Tool trennt sie nicht.
  bool get connected => _reportedConnected;
  String get deviceLabel => _device;
  Map<String, dynamic>? get nowPlaying => _nowPlaying;
  List<SongRecommendation> get suggestions => _suggestions;
  bool get suggestionsLoading {
    if (!_enabled || !connected || _nowPlaying == null) return false;
    final seed = _seedOf(_nowPlaying!);
    if (seed.isEmpty) return false;
    return !_suggestionsReady || _suggestionsSeed != seed;
  }

  bool get isVisibleForCurrentUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final adminUid = AppConfig.adminDjId;
    if (adminUid != null && user.uid == adminUid) return true;
    final model = UserService().currentUser.value;
    if (model == null || model.id != user.uid) return false;
    if (model.vibesboxSyncAccess) return true;
    return _enabledForAll && AppConfig.isDjRole(model);
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_onAuthChanged(user));
    });
    UserService().currentUser.addListener(_onUserModel);
    _accessSub ??= FirebaseFirestore.instance
        .collection('admin_config')
        .doc('sync_tool')
        .snapshots()
        .listen((snap) {
      final next = snap.data()?['enabled_for_all'] == true;
      if (next == _enabledForAll) return;
      _enabledForAll = next;
      notifyListeners();
      unawaited(_onAuthChanged(FirebaseAuth.instance.currentUser));
    });
    await _onAuthChanged(FirebaseAuth.instance.currentUser);
  }

  void _onUserModel() {
    unawaited(_onAuthChanged(FirebaseAuth.instance.currentUser));
  }

  Future<void> setEnabled(bool value) async {
    if (!isVisibleForCurrentUser && value) return;
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    _persistInFlight = true;
    try {
      await _persistEnabled(value);
    } finally {
      _persistInFlight = false;
    }
    if (value) {
      await ShazamService().setExternalRecognitionSourceActiveAsync(true);
      if (ShazamService().isEnabled) {
        await PartyAutostartService().setManualRecognitionEnabled(false);
      }
      final now = _nowPlaying;
      if (connected && now != null) {
        _lastIngestKey = null;
        unawaited(_ingestNowPlaying(now));
      }
    } else {
      await ShazamService().setExternalRecognitionSourceActiveAsync(false);
      await _clearNowPlayingDisplay();
    }
  }

  Future<void> _persistEnabled(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey(uid), value);
    } catch (e) {
      debugLog('VibesBox Sync: Prefs speichern fehlgeschlagen: $e');
    }
    try {
      await UserSelfSettingsService.instance.write({
        'vibesbox_sync_enabled': value,
      });
    } catch (e) {
      debugLog('VibesBox Sync: Cloud-Speichern fehlgeschlagen: $e');
    }
  }

  Future<bool> _readEnabled(String uid) async {
    final model = UserService().currentUser.value;
    if (model != null &&
        model.id == uid &&
        model.hasVibesboxSyncEnabledField) {
      return model.vibesboxSyncEnabled;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefsOn = prefs.getBool(_prefsKey(uid)) ?? false;
      if (prefsOn) {
        unawaited(_persistEnabled(true));
      }
      return prefsOn;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    if (_authInFlight) {
      _authAgain = true;
      return;
    }
    _authInFlight = true;
    try {
      do {
        _authAgain = false;
        await _applyAuthUser(FirebaseAuth.instance.currentUser);
      } while (_authAgain);
    } finally {
      _authInFlight = false;
    }
  }

  Future<void> _applyAuthUser(User? user) async {
    final nextUid = user?.uid;
    if (nextUid == null) {
      await _stopListen();
      _liveDocAbsent = false;
      _uid = null;
      _reportedConnected = false;
      _device = '';
      _nowPlaying = null;
      _suggestions = const [];
      _suggestionsSeed = null;
      _suggestionsReady = false;
      _lastIngestKey = null;
      if (_enabled) {
        _enabled = false;
        await ShazamService().setExternalRecognitionSourceActiveAsync(false);
        notifyListeners();
      }
      return;
    }

    if (!isVisibleForCurrentUser) {
      final waitingForProfile = UserService().currentUser.value == null;
      if (waitingForProfile) {
        _uid = nextUid;
        return;
      }
      await _stopListen();
      _liveDocAbsent = false;
      _uid = nextUid;
      _reportedConnected = false;
      _device = '';
      _nowPlaying = null;
      _suggestions = const [];
      _suggestionsSeed = null;
      _suggestionsReady = false;
      _lastIngestKey = null;
      if (_enabled) {
        _enabled = false;
        await ShazamService().setExternalRecognitionSourceActiveAsync(false);
        notifyListeners();
      }
      return;
    }

    if (_uid != nextUid) {
      _liveDocAbsent = false;
    }
    _uid = nextUid;
    if (!_persistInFlight) {
      final nextEnabled = await _readEnabled(nextUid);
      if (nextEnabled != _enabled) {
        _enabled = nextEnabled;
        notifyListeners();
      }
      await ShazamService().setExternalRecognitionSourceActiveAsync(_enabled);
    }

    if (_enabled && ShazamService().isEnabled) {
      await PartyAutostartService().setManualRecognitionEnabled(false);
    }
    if (_liveSub == null && !_liveDocAbsent) {
      await _startListen();
    }
  }

  /// Erst zuhören, wenn `rb_tool_live` existiert. Der erste erlaubte
  /// Snapshot auf ein fehlendes Dokument hat den Prozess beendet.
  Future<void> attachAfterPairingCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _liveSub != null) return;
    _listenGen++;
    _liveDocAbsent = false;
    await _stopListen();
    _attachLive(uid);
  }

  Future<void> _startListen() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final gen = ++_listenGen;
    await _stopListen();
    final exists = await _liveDocExists(uid);
    if (gen != _listenGen) return;
    if (FirebaseAuth.instance.currentUser?.uid != uid) return;
    if (exists == null) return;
    if (!exists) {
      _liveDocAbsent = true;
      return;
    }
    _liveDocAbsent = false;
    _attachLive(uid);
  }

  /// null = Lesen fehlgeschlagen, später noch einmal versuchen.
  Future<bool?> _liveDocExists(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('rb_tool_live')
          .doc(uid)
          .get();
      return snap.exists;
    } catch (e) {
      debugLog('VibesBox Sync: Live-Dokument nicht lesbar: $e');
      return null;
    }
  }

  void _attachLive(String uid) {
    _liveSub = RbToolService.instance.liveStream(uid).listen(
      _onLive,
      onError: (e) {
        debugLog('VibesBox Sync: Live-Stream Fehler: $e');
      },
    );
  }

  Future<void> _stopListen() async {
    _idleTimer?.cancel();
    _historyRetryTimer?.cancel();
    await _liveSub?.cancel();
    _liveSub = null;
  }

  void _onLive(DocumentSnapshot<Map<String, dynamic>> snap) {
    try {
      _applyLive(snap);
    } catch (e, st) {
      debugLog('VibesBox Sync: Live-Snapshot verworfen: $e\n$st');
    }
  }

  void _applyLive(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    final nextConnected = data?['connected'] == true;
    final nextDevice = _deviceOf(data);
    final nowRaw = data?['nowPlaying'];
    final hold = nowRaw is Map && nowRaw['hold'] == true;
    final skipHistory =
        hold || (nowRaw is Map && nowRaw['skipHistory'] == true);
    final now = nowRaw is Map
        ? <String, dynamic>{
            'title': nowRaw['title'],
            'artist': nowRaw['artist'],
            'bpm': nowRaw['bpm'],
            'key': nowRaw['key'] ?? nowRaw['musicalKey'],
            'camelot': nowRaw['camelot'],
            'durationSec': nowRaw['durationSec'] ?? nowRaw['duration'],
            if (hold) 'hold': true,
            if (skipHistory) 'skipHistory': true,
          }
        : null;

    var changed = false;
    if (nextConnected != _reportedConnected) {
      _reportedConnected = nextConnected;
      changed = true;
    }
    if (nextDevice != _device) {
      _device = nextDevice;
      changed = true;
    }
    if (!_mapEquals(_nowPlaying, now)) {
      _nowPlaying = now;
      changed = true;
    }
    final nextSeed = _normalizedSeed(now);
    final parsed = _parseSuggestions(nowRaw is Map ? nowRaw : null);
    final forSeed = nowRaw is Map
        ? (nowRaw['suggestionsFor'] ?? '').toString().trim()
        : '';
    final ready = nextSeed != null && forSeed == nextSeed;
    final keepHeld = hold && !ready && nextSeed != null && nextSeed == _suggestionsSeed;
    if (!keepHeld &&
        (ready != _suggestionsReady ||
            nextSeed != _suggestionsSeed ||
            !_suggestionListEquals(_suggestions, parsed))) {
      _suggestionsReady = ready;
      _suggestionsSeed = nextSeed;
      _suggestions = ready ? parsed : const [];
      changed = true;
    }
    if (changed) notifyListeners();

    if (!_enabled) return;
    if (!connected || now == null) {
      unawaited(_clearNowPlayingDisplay());
      return;
    }
    unawaited(_ingestNowPlaying(now));
  }

  static String? _normalizedSeed(Map<String, dynamic>? now) {
    if (now == null) return null;
    final seed = _seedOf(now);
    return seed.isEmpty ? null : seed;
  }

  Future<void> _clearNowPlayingDisplay() async {
    _idleTimer?.cancel();
    _historyRetryTimer?.cancel();
    if (_lastIngestKey == 'idle') return;
    try {
      ShazamService().clearExternalRecognition();
      _lastIngestKey = 'idle';
      if (_nowPlaying != null) {
        _nowPlaying = null;
        _suggestions = const [];
        _suggestionsSeed = null;
        _suggestionsReady = false;
        notifyListeners();
      }
    } catch (e) {
      debugLog('VibesBox Sync: Idle-Anzeige fehlgeschlagen: $e');
    }
  }

  void _armIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(idleAfter, () {
      unawaited(_clearNowPlayingDisplay());
    });
  }

  void _armHistoryRetry() {
    _historyRetryTimer?.cancel();
    _historyRetryTimer = Timer(const Duration(seconds: 15), () {
      final now = _nowPlaying;
      if (!_enabled || !connected || now == null) return;
      _lastIngestKey = null;
      unawaited(_ingestNowPlaying(now));
    });
  }

  /// Nach App-Resume: FGS nachziehen und fehlgeschlagenen History-Write erneut versuchen.
  Future<void> flushAfterResume() async {
    if (!_enabled) return;
    await ShazamService().syncForegroundAfterAppResumed();
    final now = _nowPlaying;
    if (!connected || now == null) return;
    _lastIngestKey = null;
    await _ingestNowPlaying(now);
  }

  Future<void> _ingestNowPlaying(Map<String, dynamic> now) async {
    if (_ingestInFlight) return;
    final title = (now['title'] as String? ?? '').trim();
    final artist = (now['artist'] as String? ?? '').trim();
    final bpm = _asBpm(now['bpm']);
    final key = (now['key'] as String? ?? '').trim();
    final camelotRaw = (now['camelot'] as String? ?? '').trim();
    final camelot = CamelotHelper.fromScaleName(
      camelotRaw.isNotEmpty ? camelotRaw : key,
    );
    final durationSec = _asDurationSec(now['durationSec'] ?? now['duration']);
    final skipHistory = now['skipHistory'] == true || now['hold'] == true;
    final ingestKey = '$title|$artist|${bpm ?? ''}|${camelot ?? ''}|${durationSec ?? ''}|$skipHistory';
    if (ingestKey == _lastIngestKey) return;
    _ingestInFlight = true;
    try {
      final saved = await ShazamService().ingestExternalRecognition(
        title: title,
        artist: artist,
        bpm: bpm,
        camelot: camelot,
        musicalKey: key.isEmpty ? null : key,
        durationSec: durationSec,
        skipHistory: skipHistory,
      );
      if (saved) {
        _lastIngestKey = ingestKey;
        _historyRetryTimer?.cancel();
        _armIdleTimer();
      } else {
        debugLog('VibesBox Sync: History noch nicht geschrieben, Retry geplant');
        _armHistoryRetry();
      }
    } catch (e) {
      debugLog('VibesBox Sync: Ingest fehlgeschlagen: $e');
      _armHistoryRetry();
    } finally {
      _ingestInFlight = false;
    }
  }

  static String _deviceOf(Map<String, dynamic>? data) {
    final raw = (data?['source'] ?? '').toString().trim();
    if (raw.isEmpty || raw == 'rekordbox') return '';
    return raw;
  }

  static String _seedOf(Map<String, dynamic> now) {
    final title = now['title'] is String ? (now['title'] as String).trim() : '';
    final artist =
        now['artist'] is String ? (now['artist'] as String).trim() : '';
    if (title.isEmpty || artist.isEmpty) return '';
    return '$title|$artist';
  }

  static List<SongRecommendation> _parseSuggestions(Map? nowRaw) {
    if (nowRaw == null) return const [];
    final raw = nowRaw['suggestions'];
    if (raw is! List) return const [];
    final out = <SongRecommendation>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final rec = SongRecommendation.fromJson(
        Map<String, dynamic>.from(entry),
      );
      if (rec.title.isEmpty || rec.artist.isEmpty) continue;
      out.add(rec);
      if (out.length >= 20) break;
    }
    return out;
  }

  static bool _suggestionListEquals(
    List<SongRecommendation> a,
    List<SongRecommendation> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].title != b[i].title || a[i].artist != b[i].artist) {
        return false;
      }
    }
    return true;
  }

  static bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key]?.toString() != b[key]?.toString()) return false;
    }
    return true;
  }

  static int? _asDurationSec(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.round();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }

  static double? _asBpm(dynamic value) {
    if (value is num && value > 0) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null && parsed > 0) return parsed;
    }
    return null;
  }
}
