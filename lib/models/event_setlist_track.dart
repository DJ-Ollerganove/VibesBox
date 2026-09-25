import '../helpers/security_helper.dart';
import 'event_setlist_input.dart';

class EventSetlistTrack {
  const EventSetlistTrack({
    required this.title,
    required this.artist,
    this.reason = '',
    this.reasonLang = '',
    this.reasonI18n = const <String, String>{},
    this.duration,
    this.genre,
    this.bpm,
    this.musicalKey,
    this.camelot,
    this.market,
    this.moved = false,
  });

  final String title;
  final String artist;
  /// Nach Offen/Gespielt: bleibt in der gespeicherten Liste, nicht im Setlist-Reiter.
  final bool moved;
  final String reason;
  /// Sprache, in der [reason] geschrieben wurde (ISO-639-1).
  final String reasonLang;
  /// Übersetzungen der Begründung, Key = Sprachcode.
  final Map<String, String> reasonI18n;
  final String? duration;
  final String? genre;
  final int? bpm;
  final String? musicalKey;
  final String? camelot;
  /// Gäste-Markt-Code aus der KI (z. B. de, vi, pt-BR).
  final String? market;

  String get mixMetaLine {
    final parts = <String>[];
    final d = duration?.trim() ?? '';
    if (d.isNotEmpty) parts.add(d);
    if (bpm != null && bpm! >= 60 && bpm! <= 220) {
      parts.add('$bpm BPM');
    }
    final g = genre?.trim() ?? '';
    if (g.isNotEmpty) parts.add(g);
    final cam = camelot?.trim() ?? '';
    if (cam.isNotEmpty) parts.add(cam);
    return parts.join('  ·  ');
  }

  String sourceReasonLang() {
    final code = reasonLang.trim().toLowerCase();
    if (code.isNotEmpty) return code;
    return 'de';
  }

  bool needsReasonTranslation(String lang) {
    if (reason.trim().isEmpty) return false;
    final code = lang.trim().toLowerCase().split(RegExp(r'[-_]')).first;
    if (code.isEmpty) return false;
    if ((reasonI18n[code] ?? '').trim().isNotEmpty) return false;
    return sourceReasonLang() != code;
  }

  String reasonFor(String lang) {
    final code = lang.trim().toLowerCase().split(RegExp(r'[-_]')).first;
    final localized = (reasonI18n[code] ?? '').trim();
    if (localized.isNotEmpty) return localized;
    return reason;
  }

  EventSetlistTrack copyWith({
    String? title,
    String? artist,
    String? reasonLang,
    Map<String, String>? reasonI18n,
    String? reason,
    bool? moved,
    String? market,
    String? camelot,
    String? musicalKey,
  }) {
    return EventSetlistTrack(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      reason: reason ?? this.reason,
      reasonLang: reasonLang ?? this.reasonLang,
      reasonI18n: reasonI18n ?? this.reasonI18n,
      duration: duration,
      genre: genre,
      bpm: bpm,
      musicalKey: musicalKey ?? this.musicalKey,
      camelot: camelot ?? this.camelot,
      market: market ?? this.market,
      moved: moved ?? this.moved,
    );
  }

  Map<String, dynamic> toJson() {
    final safeTitle = _clip(title, 100);
    final safeArtist = _clip(artist, 100);
    final safeReason = _clip(reason, 240);
    final safeLang = _clip(reasonLang, 12).toLowerCase();
    final safeI18n = _sanitizeI18n(reasonI18n);
    final safeDuration = duration == null ? '' : _clip(duration!, 12);
    final safeGenre = genre == null ? '' : _clip(genre!, 40);
    final safeKey = musicalKey == null ? '' : _clip(musicalKey!, 12);
    final safeCamelot = camelot == null ? '' : _clip(camelot!, 8);
    final safeMarket = market == null ? '' : _clip(market!, 12).toLowerCase();
    return <String, dynamic>{
      'title': safeTitle,
      'artist': safeArtist,
      if (safeReason.isNotEmpty) 'reason': safeReason,
      if (safeLang.isNotEmpty) 'reason_lang': safeLang,
      if (safeI18n.isNotEmpty) 'reason_i18n': safeI18n,
      if (safeDuration.isNotEmpty) 'duration': safeDuration,
      if (safeGenre.isNotEmpty) 'genre': safeGenre,
      if (bpm != null) 'bpm': bpm,
      if (safeKey.isNotEmpty) 'key': safeKey,
      if (safeCamelot.isNotEmpty) 'camelot': safeCamelot,
      if (safeMarket.isNotEmpty) 'market': safeMarket,
      if (moved) 'moved': true,
    };
  }

  static EventSetlistTrack? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final title = _clip((map['title'] as String?) ?? '', 100);
    final artist = _clip((map['artist'] as String?) ?? '', 100);
    if (title.isEmpty || artist.isEmpty) return null;
    final key = (map['key'] as String?)?.trim() ??
        (map['musicalKey'] as String?)?.trim();
    return EventSetlistTrack(
      title: title,
      artist: artist,
      reason: _clip((map['reason'] as String?) ?? '', 240),
      reasonLang: _clip((map['reason_lang'] as String?) ?? '', 12),
      reasonI18n: _i18nMap(map['reason_i18n']),
      duration: _durationLabel(map['duration'] ?? map['length']),
      genre: _clipOrNull(map['genre'], 40),
      bpm: _asBpm(map['bpm'] ?? map['tempo']),
      musicalKey: key == null || key.isEmpty ? null : _clip(key, 12),
      camelot: _clipOrNull(map['camelot'], 8),
      market: _clipOrNull(map['market'] ?? map['marketId'], 12),
      moved: map['moved'] == true,
    );
  }

  static Map<String, String> _i18nMap(Object? raw) {
    if (raw is! Map) return const <String, String>{};
    return _sanitizeI18n(
      raw.map((key, value) => MapEntry(key.toString(), value?.toString() ?? '')),
    );
  }

  static Map<String, String> _sanitizeI18n(Map<String, String> raw) {
    final out = <String, String>{};
    raw.forEach((key, value) {
      final lang = _clip(key, 12).toLowerCase();
      final text = _clip(value, 240);
      if (lang.isEmpty || text.isEmpty) return;
      if (out.length >= 24) return;
      out[lang] = text;
    });
    return out;
  }

  static String _clip(String raw, int max) {
    return SecurityHelper.sanitize(raw, maxLength: max);
  }

  static String? _clipOrNull(Object? raw, int max) {
    final s = _clip(raw?.toString() ?? '', max);
    return s.isEmpty ? null : s;
  }

  static List<EventSetlistTrack> listFrom(Object? raw) {
    if (raw is! List) return const <EventSetlistTrack>[];
    final out = <EventSetlistTrack>[];
    for (final entry in raw) {
      final track = tryParse(entry);
      if (track == null) continue;
      out.add(track);
      if (out.length >= EventSetlistInput.maxStoredSongs) break;
    }
    return out;
  }

  static int? _asBpm(Object? raw) {
    num? n;
    if (raw is num) {
      n = raw;
    } else if (raw is String) {
      n = num.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
    }
    if (n == null) return null;
    final bpm = n.round();
    if (bpm < 60 || bpm > 220) return null;
    return bpm;
  }

  static String? _durationLabel(Object? raw) {
    if (raw == null) return null;
    if (raw is num) {
      final sec = raw.round();
      if (sec <= 30 || sec > 3600) return null;
      return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return s.length > 12 ? s.substring(0, 12) : s;
  }
}
