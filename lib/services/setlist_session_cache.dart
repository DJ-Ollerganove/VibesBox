import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/event_setlist_track.dart';

/// Zwischenergebnis der Setlisten-Erstellung (überlebt Display-Aus / App-Kill).
class SetlistSessionCache {
  SetlistSessionCache._();

  static const _tracksKey = 'vb_setlist_session_tracks_v1';
  static const _elapsedKey = 'vb_setlist_session_elapsed_v1';
  static const _libraryIdKey = 'vb_setlist_session_library_id_v1';
  static const _generatingKey = 'vb_setlist_session_generating_v1';
  static const _targetKey = 'vb_setlist_session_target_v1';

  static Future<void> save({
    required List<EventSetlistTrack> tracks,
    String? elapsedLabel,
    String? libraryListId,
    bool generating = false,
    int target = 0,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (tracks.isEmpty && !generating) {
        await clear();
        return;
      }
      final raw = tracks.map((t) => t.toJson()).toList(growable: false);
      await prefs.setString(_tracksKey, jsonEncode(raw));
      final elapsed = (elapsedLabel ?? '').trim();
      if (elapsed.isEmpty) {
        await prefs.remove(_elapsedKey);
      } else {
        await prefs.setString(_elapsedKey, elapsed);
      }
      final lib = (libraryListId ?? '').trim();
      if (lib.isEmpty) {
        await prefs.remove(_libraryIdKey);
      } else {
        await prefs.setString(_libraryIdKey, lib);
      }
      await prefs.setBool(_generatingKey, generating);
      await prefs.setInt(_targetKey, target);
    } catch (_) {}
  }

  static Future<({
    List<EventSetlistTrack> tracks,
    String? elapsedLabel,
    String? libraryListId,
    bool generating,
    int target,
  })> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_tracksKey);
      if (encoded == null || encoded.isEmpty) {
        return (
          tracks: const <EventSetlistTrack>[],
          elapsedLabel: null,
          libraryListId: null,
          generating: false,
          target: 0,
        );
      }
      final decoded = jsonDecode(encoded);
      final tracks = EventSetlistTrack.listFrom(decoded);
      final elapsed = prefs.getString(_elapsedKey);
      final lib = prefs.getString(_libraryIdKey);
      return (
        tracks: tracks,
        elapsedLabel: (elapsed ?? '').trim().isEmpty ? null : elapsed!.trim(),
        libraryListId: (lib ?? '').trim().isEmpty ? null : lib!.trim(),
        generating: prefs.getBool(_generatingKey) ?? false,
        target: prefs.getInt(_targetKey) ?? 0,
      );
    } catch (_) {
      return (
        tracks: const <EventSetlistTrack>[],
        elapsedLabel: null,
        libraryListId: null,
        generating: false,
        target: 0,
      );
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tracksKey);
      await prefs.remove(_elapsedKey);
      await prefs.remove(_libraryIdKey);
      await prefs.remove(_generatingKey);
      await prefs.remove(_targetKey);
    } catch (_) {}
  }
}
