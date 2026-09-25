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
  void syncSetlistTracks(
    List<EventSetlistTrack> tracks, {
    bool countAsSuggested = false,
  }) {
    if (tracks.isEmpty) return;
    // ignore: unawaited_futures
    _sync(tracks, countAsSuggested: countAsSuggested);
  }

  Future<void> _sync(
    List<EventSetlistTrack> tracks, {
    required bool countAsSuggested,
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
        await callable.call(
          serializeForCallable(<String, dynamic>{
            'event': event,
            'tracks': chunk,
          }),
        );
      }
    } catch (e) {
      debugLog('MusicCatalogService.syncSetlistTracks: $e');
    }
  }
}
