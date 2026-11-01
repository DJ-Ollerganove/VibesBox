import 'package:cloud_functions/cloud_functions.dart';

import '../models/event_setlist_track.dart';
import '../utils/callable_payload_serializer.dart';
import '../utils/debug_log.dart';

/// Schreibt Songs in den globalen Katalog (Camelot, Key, BPM, …).
/// Fire-and-forget — blockiert die UI nicht.
class MusicCatalogService {
  MusicCatalogService._();

  static final MusicCatalogService instance = MusicCatalogService._();

  static const String _region = 'us-central1';
  static const String _name = 'upsertMusicCatalogTracks';
  static const int _chunk = 80;

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  /// [countAsSuggested]: true beim erstmaligen Speichern/Zuordnen einer Liste.
  /// [previous]: Stand vor der Änderung. Nur neue oder gelöschte Songs
  /// gehen in den Anlass-Pool, nicht eine reine Umsortierung.
  void syncSetlistTracks(
    List<EventSetlistTrack> tracks, {
    bool countAsSuggested = false,
    String? occasionId,
    List<EventSetlistTrack>? previous,
  }) {
    if (tracks.isEmpty) return;
    // ignore: unawaited_futures
    _sync(
      tracks,
      countAsSuggested: countAsSuggested,
      occasionId: occasionId,
      previous: previous,
    );
  }

  static String _songKey(EventSetlistTrack t) {
    return '${t.title.trim().toLowerCase()}|${t.artist.trim().toLowerCase()}';
  }

  Future<void> _sync(
    List<EventSetlistTrack> tracks, {
    required bool countAsSuggested,
    String? occasionId,
    List<EventSetlistTrack>? previous,
  }) async {
    try {
      final payloadTracks = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final t in tracks) {
        final title = t.title.trim();
        final artist = t.artist.trim();
        if (title.isEmpty || artist.isEmpty) continue;
        final key = '${title.toLowerCase()}|${artist.toLowerCase()}';
        if (seen.contains(key)) continue;
        seen.add(key);
        payloadTracks.add(<String, dynamic>{
          'title': title,
          'artist': artist,
          if ((t.camelot ?? '').trim().isNotEmpty) 'camelot': t.camelot!.trim(),
          if ((t.musicalKey ?? '').trim().isNotEmpty)
            'key': t.musicalKey!.trim(),
          if (t.bpm != null) 'bpm': t.bpm,
          if ((t.duration ?? '').trim().isNotEmpty) 'duration': t.duration!.trim(),
          if ((t.genre ?? '').trim().isNotEmpty) 'genre': t.genre!.trim(),
          if ((t.market ?? '').trim().isNotEmpty) 'market': t.market!.trim(),
        });
      }
      if (payloadTracks.isEmpty) return;

      final occasion = (occasionId ?? '').trim();
      final poolAdded = <Map<String, String>>[];
      final poolRetired = <Map<String, String>>[];
      if (occasion.isNotEmpty) {
        final prevBy = <String, EventSetlistTrack>{};
        for (final t in previous ?? const <EventSetlistTrack>[]) {
          final key = _songKey(t);
          if (key == '|' || t.title.trim().isEmpty || t.artist.trim().isEmpty) {
            continue;
          }
          prevBy[key] = t;
        }
        final nextKeys = <String>{};
        for (final t in tracks) {
          final title = t.title.trim();
          final artist = t.artist.trim();
          if (title.isEmpty || artist.isEmpty) continue;
          final key = '${title.toLowerCase()}|${artist.toLowerCase()}';
          if (!nextKeys.add(key)) continue;
          if (prevBy.containsKey(key)) continue;
          poolAdded.add(<String, String>{'title': title, 'artist': artist});
        }
        for (final entry in prevBy.entries) {
          if (nextKeys.contains(entry.key)) continue;
          poolRetired.add(<String, String>{
            'title': entry.value.title.trim(),
            'artist': entry.value.artist.trim(),
          });
        }
      }

      final callable = _functions.httpsCallable(
        _name,
        options: HttpsCallableOptions(timeout: const Duration(seconds: 55)),
      );
      final event =
          countAsSuggested ? 'setlist_suggested' : 'setlist_meta';

      for (var i = 0; i < payloadTracks.length; i += _chunk) {
        final end = (i + _chunk > payloadTracks.length)
            ? payloadTracks.length
            : i + _chunk;
        final chunk = payloadTracks.sublist(i, end);
        final first = i == 0;
        await callable.call(
          serializeForCallable(<String, dynamic>{
            'event': event,
            'tracks': chunk,
            if (first && occasion.isNotEmpty) 'occasionId': occasion,
            if (first && poolAdded.isNotEmpty) 'poolAdded': poolAdded,
            if (first && poolRetired.isNotEmpty) 'poolRetired': poolRetired,
          }),
        );
      }
    } catch (e) {
      debugLog('MusicCatalogService.syncSetlistTracks: $e');
    }
  }
}
