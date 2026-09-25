import '../helpers/security_helper.dart';
import '../l10n/locale_helper.dart';
import '../models/event_setlist_track.dart';
import '../utils/debug_log.dart';
import 'openai_music_proxy_service.dart';

/// Übersetzt gespeicherte Setlisten-Begründungen in die App-Sprache (ein Batch, kein Titel).
class SetlistReasonLocalizeService {
  SetlistReasonLocalizeService._();

  static final SetlistReasonLocalizeService instance =
      SetlistReasonLocalizeService._();

  static const _chunk = 40;

  Future<List<EventSetlistTrack>> ensure(
    List<EventSetlistTrack> tracks, {
    String? lang,
  }) async {
    final code = (lang ?? LocaleHelper.localeNotifier.value.languageCode)
        .trim()
        .toLowerCase()
        .split(RegExp(r'[-_]'))
        .first;
    if (code.isEmpty || tracks.isEmpty) return tracks;

    final needIdx = <int>[];
    for (var i = 0; i < tracks.length; i++) {
      if (tracks[i].needsReasonTranslation(code)) needIdx.add(i);
    }
    if (needIdx.isEmpty) return tracks;

    final next = [...tracks];
    try {
      for (var offset = 0; offset < needIdx.length; offset += _chunk) {
        final slice = needIdx.skip(offset).take(_chunk).toList();
        final sources = slice
            .map(
              (i) => SecurityHelper.sanitize(next[i].reason, maxLength: 240),
            )
            .toList();
        final translated =
            await OpenaiMusicProxyService.instance.translateReasons(
          targetLang: code,
          texts: sources,
        );
        for (var s = 0; s < slice.length; s++) {
          final idx = slice[s];
          final text = s < translated.length
              ? SecurityHelper.sanitize(translated[s], maxLength: 240)
              : '';
          if (text.isEmpty) continue;
          final cur = next[idx];
          next[idx] = cur.copyWith(
            reasonI18n: <String, String>{
              ...cur.reasonI18n,
              code: text,
            },
          );
        }
      }
    } catch (e) {
      debugLog('SetlistReasonLocalizeService.ensure: $e');
      return tracks;
    }
    return next;
  }
}
