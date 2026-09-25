import 'package:cloud_functions/cloud_functions.dart';

import '../l10n/locale_helper.dart';
import '../models/event_setlist_input.dart';
import '../models/event_setlist_track.dart';
import '../utils/debug_log.dart';
import '../utils/setlist_music_request_guard.dart';
import 'openai_music_proxy_service.dart';
import 'pro_feature_guard.dart';

/// KI-Setliste: einfache 20er-Batches über openaiMusicProxy (nur KI, kein Extra-Filter).
class EventSetlistService {
  EventSetlistService._();

  static final EventSetlistService instance = EventSetlistService._();

  static const _batchSize = 20;

  Future<List<EventSetlistTrack>> generate({
    required EventSetlistInput input,
    void Function(int have, int target)? onProgress,
    void Function(List<EventSetlistTrack> soFar)? onPartial,
    bool Function()? isCancelled,
  }) async {
    if (!ProFeatureGuard.canUseProExclusiveNow()) {
      throw const SetlistRejectedException('Pro required');
    }
    final target = input.resolvedSongCount;
    if (!SetlistMusicRequestGuard.isMusicRequest(
      eventType: input.eventTypeBlob,
      preferred: input.preferredBlob,
      blacklist: input.blacklist,
      artistsMust: input.artistsMust,
    )) {
      throw const SetlistRejectedException(
        SetlistMusicRequestGuard.rejectedMessage,
      );
    }

    final out = <EventSetlistTrack>[];
    final seen = <String>{};
    var emptyStreak = 0;

    while (out.length < target) {
      if (isCancelled?.call() == true) break;
      onProgress?.call(out.length, target);
      final need = (target - out.length).clamp(1, _batchSize);
      final batch = await _fromOpenAi(
        input: input,
        need: need,
        already: out,
      );
      var added = 0;
      for (final track in batch) {
        if (isCancelled?.call() == true) break;
        if (_isBlacklisted(track, input.blacklist)) continue;
        final key = _workKey(track);
        if (key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        out.add(track);
        added++;
        if (out.length >= target) break;
      }
      if (added == 0) {
        emptyStreak++;
        if (emptyStreak >= 3) break;
      } else {
        emptyStreak = 0;
        onPartial?.call(List<EventSetlistTrack>.from(out));
      }
    }
    onProgress?.call(out.length, target);
    if (out.isNotEmpty) onPartial?.call(List<EventSetlistTrack>.from(out));
    return out;
  }

  Future<List<EventSetlistTrack>> _fromOpenAi({
    required EventSetlistInput input,
    required int need,
    required List<EventSetlistTrack> already,
  }) async {
    try {
      final raw = await OpenaiMusicProxyService.instance.setlistBatch(
        eventType: input.eventTypeBlob.trim(),
        preferred: input.preferredBlob.trim(),
        blacklist: input.blacklist.trim(),
        ageStructure: input.ageStructure.trim(),
        region: input.marketIds.isEmpty ? '' : input.marketIds.join(','),
        appLanguage: LocaleHelper.localeNotifier.value.languageCode,
        need: need,
        already: already
            .take(40)
            .map(
              (e) => <String, String>{
                'title': e.title,
                'artist': e.artist,
              },
            )
            .toList(),
        genres: input.genreIds
            .map((id) => EventSetlistInput.genrePromptLabels[id] ?? id)
            .toList(),
        artistsMust: input.artistsMust.trim(),
        marketIds: List<String>.from(input.marketIds),
        marketPercents: Map<String, int>.from(input.marketPercents),
        bpmBand: input.bpmBandId,
        energyCurve: input.energyCurveId,
        familiarity: input.familiarityId,
        scope: input.scopeId,
        occasionId: input.occasionId,
      );
      return EventSetlistTrack.listFrom(raw)
          .map(
            (t) => t.reasonLang.isNotEmpty
                ? t
                : t.copyWith(
                    reasonLang: LocaleHelper.localeNotifier.value.languageCode,
                  ),
          )
          .toList();
    } on FirebaseFunctionsException catch (e) {
      debugLog('EventSetlistService proxy: ${e.code} ${e.message}');
      if (e.code == 'invalid-argument') {
        throw SetlistRejectedException(
          (e.message ?? '').trim().isEmpty
              ? SetlistMusicRequestGuard.rejectedMessage
              : e.message!.trim(),
        );
      }
      return const <EventSetlistTrack>[];
    } catch (e) {
      debugLog('EventSetlistService proxy: $e');
      if (e is SetlistRejectedException) rethrow;
      return const <EventSetlistTrack>[];
    }
  }

  static bool _isBlacklisted(EventSetlistTrack track, String raw) {
    final parts = raw
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.length >= 2)
        .toList();
    if (parts.isEmpty) return false;
    final hay = '${track.title} ${track.artist}'.toLowerCase();
    return parts.any(hay.contains);
  }

  static String _workKey(EventSetlistTrack track) {
    final t = track.title.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final a = track.artist.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    if (t.isEmpty || a.isEmpty) return '';
    return '$t|$a';
  }
}
