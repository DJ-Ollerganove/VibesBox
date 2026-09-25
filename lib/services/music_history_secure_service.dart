import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';

import 'app_diagnostic_log_service.dart';
import 'history_save_log_service.dart';

class MusicHistorySaveResult {
  const MusicHistorySaveResult({
    required this.partyId,
    required this.sessionId,
    required this.trackId,
    required this.title,
    required this.artist,
  });

  final String partyId;
  final String sessionId;
  final String trackId;
  final String title;
  final String artist;
}

/// Serverseitiges Speichern in music_history (Admin SDK).
class MusicHistorySecureService {
  MusicHistorySecureService._();

  static const String _region = 'us-central1';
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  static Future<MusicHistorySaveResult> saveTrack({
    required String partyId,
    required String title,
    required String artist,
    double? bpm,
    String? camelot,
    String? key,
    int? durationSec,
    String? source,
  }) async {
    HistorySaveLogService.log(
      'CALLABLE',
      'saveMusicHistoryTrackSecure party=$partyId title=$title artist=$artist',
    );
    try {
      final callable = _functions.httpsCallable('saveMusicHistoryTrackSecure');
      final raw = await callable
          .call<Map<String, dynamic>>({
            'partyId': partyId,
            'title': title,
            'artist': artist,
            if (bpm != null) 'bpm': bpm,
            if (camelot != null && camelot.isNotEmpty) 'camelot': camelot,
            if (key != null && key.isNotEmpty) 'key': key,
            if (durationSec != null && durationSec > 0) 'durationSec': durationSec,
            if (source != null && source.isNotEmpty) 'source': source,
          })
          .timeout(const Duration(seconds: 20));
      final data = Map<String, dynamic>.from(raw.data);
      final result = MusicHistorySaveResult(
        partyId: (data['partyId'] ?? partyId).toString(),
        sessionId: (data['sessionId'] ?? '').toString(),
        trackId: (data['trackId'] ?? '').toString(),
        title: (data['title'] ?? title).toString(),
        artist: (data['artist'] ?? artist).toString(),
      );
      HistorySaveLogService.log(
        'CALLABLE_OK',
        'session=${result.sessionId} track=${result.trackId}',
      );
      return result;
    } on TimeoutException catch (e) {
      HistorySaveLogService.log(
        'CALLABLE_ERR',
        'timeout 20s $e',
      );
      diagLog('HISTORY', 'saveMusicHistoryTrackSecure TIMEOUT');
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      HistorySaveLogService.log(
        'CALLABLE_ERR',
        'code=${e.code} msg=${e.message} details=${e.details}',
      );
      diagLog(
        'HISTORY',
        'saveMusicHistoryTrackSecure FEHLER code=${e.code} msg=${e.message}',
      );
      rethrow;
    }
  }
}
