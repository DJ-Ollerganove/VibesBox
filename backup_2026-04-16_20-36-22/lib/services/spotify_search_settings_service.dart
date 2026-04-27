import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../utils/spotify_non_music_filter.dart';
import 'user_service.dart';
import '../utils/debug_log.dart';

/// Lädt und cached [admin_config/spotify_settings]: max. 1× Firestore / 24h (außer Sofort-Update nach Speichern).
class SpotifySearchSettingsService {
  SpotifySearchSettingsService._();
  static final SpotifySearchSettingsService instance = SpotifySearchSettingsService._();

  static const String _prefsKeyBlacklist = 'spotify_search_blacklist_json';
  static const String _prefsKeyMaxMs = 'spotify_max_song_duration_ms';
  static const String _prefsKeyLastSyncMs = 'spotify_settings_last_sync_ms';

  static const Duration _syncTtl = Duration(hours: 24);

  static const List<String> defaultSearchBlacklist = [
    'hörspiel',
    'hörbuch',
    'podcast',
    'tkkg',
    'audiobook',
    'die drei ???',
    'bibi blocksberg',
    'storytelling',
  ];

  static const int defaultMaxSongDurationMs = 900000;

  List<String> _keywordSubstringsLower = List<String>.from(defaultSearchBlacklist);
  int _maxSongDurationMs = defaultMaxSongDurationMs;

  List<String> get keywordSubstringsLower => List.unmodifiable(_keywordSubstringsLower);
  int get maxSongDurationMs => _maxSongDurationMs;

  void _applyToFilter() {
    SpotifyNonMusicFilter.configure(
      keywordSubstringsLower: _keywordSubstringsLower,
      maxTrackDurationMs: _maxSongDurationMs,
    );
  }

  static List<String> _normalizeBlacklist(List<dynamic>? raw) {
    if (raw == null) return List<String>.from(defaultSearchBlacklist);
    final out = <String>[];
    for (final e in raw) {
      if (e == null) continue;
      final s = e.toString().trim().toLowerCase();
      if (s.isNotEmpty) out.add(s);
    }
    return out;
  }

  static int _clampMaxMs(dynamic v) {
    if (v is int) {
      if (v >= 60000 && v <= 3600000) return v;
    }
    return defaultMaxSongDurationMs;
  }

  Future<void>? _loadInFlight;

  /// Lädt Prefs + optional Firestore; parallele Aufrufe teilen sich einen Lauf.
  /// Für Such-API vor [SpotifyNonMusicFilter]-Filterung nutzen.
  Future<void> ensureLoadedForSearch() async {
    if (_loadInFlight != null) {
      await _loadInFlight;
      return;
    }
    final f = loadOnStartup();
    _loadInFlight = f;
    try {
      await f;
    } finally {
      _loadInFlight = null;
    }
  }

  Future<void> loadOnStartup() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKeyBlacklist);
    final maxMs = prefs.getInt(_prefsKeyMaxMs);
    final lastSync = prefs.getInt(_prefsKeyLastSyncMs);

    if (jsonStr != null && jsonStr.isNotEmpty && maxMs != null) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>?;
        _keywordSubstringsLower = _normalizeBlacklist(list);
        _maxSongDurationMs = _clampMaxMs(maxMs);
      } catch (_) {
        _keywordSubstringsLower = List<String>.from(defaultSearchBlacklist);
        _maxSongDurationMs = defaultMaxSongDurationMs;
      }
    } else {
      _keywordSubstringsLower = List<String>.from(defaultSearchBlacklist);
      _maxSongDurationMs = defaultMaxSongDurationMs;
    }
    _applyToFilter();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final needsRemote = lastSync == null ||
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(lastSync),
            ) >
            _syncTtl;

    if (!needsRemote) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('admin_config')
          .doc('spotify_settings');
      final doc = await docRef.get();
      if (!doc.exists) {
        // Kein clientseitiges Seed in Firestore: nur Admin/DJ dürfen schreiben (firestore.rules).
        // Lokale Defaults + Prefs; zentrales Dokument legt ein Admin/DJ an oder über die DJ-Einstellungen.
        _keywordSubstringsLower = List<String>.from(defaultSearchBlacklist);
        _maxSongDurationMs = defaultMaxSongDurationMs;
        _applyToFilter();
        final now = DateTime.now().millisecondsSinceEpoch;
        await prefs.setString(_prefsKeyBlacklist, jsonEncode(_keywordSubstringsLower));
        await prefs.setInt(_prefsKeyMaxMs, _maxSongDurationMs);
        await prefs.setInt(_prefsKeyLastSyncMs, now);
        return;
      }

      final data = doc.data();
      if (data == null) {
        await prefs.setInt(_prefsKeyLastSyncMs, DateTime.now().millisecondsSinceEpoch);
        return;
      }

      final bl = _normalizeBlacklist(data['search_blacklist'] as List<dynamic>?);
      final ms = _clampMaxMs(data['max_song_duration_ms']);

      _keywordSubstringsLower = bl;
      _maxSongDurationMs = ms;
      _applyToFilter();

      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(_prefsKeyBlacklist, jsonEncode(_keywordSubstringsLower));
      await prefs.setInt(_prefsKeyMaxMs, _maxSongDurationMs);
      await prefs.setInt(_prefsKeyLastSyncMs, now);
      } catch (e) {
      // Offline / permission-denied (Gast): lokaler Cache bleibt
      debugLog('SpotifySearchSettingsService.loadOnStartup: $e');
    }
  }

  /// Lädt aktuelle Werte aus Prefs (nach UI-Öffnen).
  Future<void> reloadFromPrefsOnly() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKeyBlacklist);
    final maxMs = prefs.getInt(_prefsKeyMaxMs);
    if (jsonStr != null && jsonStr.isNotEmpty && maxMs != null) {
      try {
        final list = jsonDecode(jsonStr) as List<dynamic>?;
        _keywordSubstringsLower = _normalizeBlacklist(list);
        _maxSongDurationMs = _clampMaxMs(maxMs);
      } catch (_) {
        _keywordSubstringsLower = List<String>.from(defaultSearchBlacklist);
        _maxSongDurationMs = defaultMaxSongDurationMs;
      }
    } else {
      _keywordSubstringsLower = List<String>.from(defaultSearchBlacklist);
      _maxSongDurationMs = defaultMaxSongDurationMs;
    }
    _applyToFilter();
  }

  /// Firestore + Prefs; Filter sofort aktiv.
  Future<void> saveAndApplyLocal({
    required List<String> searchBlacklist,
    required int maxSongDurationMs,
  }) async {
    final u = UserService().currentUser.value;
    if (!AppConfig.isAdminRole(u)) {
      throw StateError(
        'spotify_settings: nur Admins dürfen in Firestore schreiben.',
      );
    }

    final normalized = <String>[];
    for (final e in searchBlacklist) {
      final s = e.trim().toLowerCase();
      if (s.isNotEmpty) normalized.add(s);
    }
    final ms = _clampMaxMs(maxSongDurationMs);

    await FirebaseFirestore.instance.collection('admin_config').doc('spotify_settings').set(
      {
        'search_blacklist': normalized,
        'max_song_duration_ms': ms,
      },
      SetOptions(merge: true),
    );

    _keywordSubstringsLower = normalized;
    _maxSongDurationMs = ms;
    _applyToFilter();

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_prefsKeyBlacklist, jsonEncode(_keywordSubstringsLower));
    await prefs.setInt(_prefsKeyMaxMs, _maxSongDurationMs);
    await prefs.setInt(_prefsKeyLastSyncMs, now);
  }
}
