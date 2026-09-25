/// Isoliertes Modell für einen Mix-Vorschlag (Prototyp Musikerkennung).
class SongRecommendation {
  const SongRecommendation({
    required this.title,
    required this.artist,
    this.coverUrl,
    this.bpm,
    this.musicalKey,
    this.camelot,
    this.genre,
    this.duration,
    this.spotifyId,
  });

  final String title;
  final String artist;
  final String? coverUrl;
  final double? bpm;
  final String? musicalKey;
  final String? camelot;
  final String? genre;
  final String? duration;
  final String? spotifyId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'artist': artist,
      if (coverUrl != null && coverUrl!.isNotEmpty) 'coverUrl': coverUrl,
      if (bpm != null) 'bpm': bpm,
      if (musicalKey != null && musicalKey!.isNotEmpty)
        'musicalKey': musicalKey,
      if (camelot != null && camelot!.isNotEmpty) 'camelot': camelot,
      if (genre != null && genre!.isNotEmpty) 'genre': genre,
      if (duration != null && duration!.isNotEmpty) 'duration': duration,
      if (spotifyId != null && spotifyId!.isNotEmpty) 'spotifyId': spotifyId,
    };
  }

  String get mixMetaLine {
    final parts = <String>[];
    if (bpm != null && bpm! >= 60 && bpm! <= 220) {
      parts.add('${bpm!.round()} BPM');
    }
    final cam = camelot?.trim() ?? '';
    if (cam.isNotEmpty) parts.add(cam);
    final d = duration?.trim() ?? '';
    if (d.isNotEmpty) parts.add(d);
    final g = genre?.trim() ?? '';
    if (g.isNotEmpty) parts.add(g);
    return parts.join('  ·  ');
  }

  factory SongRecommendation.fromJson(Map<String, dynamic> json) {
    final key = (json['key'] as String?)?.trim() ??
        (json['musicalKey'] as String?)?.trim();
    return SongRecommendation(
      title: (json['title'] as String?)?.trim() ?? '',
      artist: (json['artist'] as String?)?.trim() ?? '',
      coverUrl: (json['coverUrl'] as String?)?.trim(),
      bpm: _asBpm(json['bpm'] ?? json['tempo']),
      musicalKey: (key != null && key.isNotEmpty) ? key : null,
      camelot: (json['camelot'] as String?)?.trim(),
      genre: (json['genre'] as String?)?.trim(),
      duration: _durationLabel(json['duration'] ?? json['length']),
      spotifyId: (json['spotifyId'] as String?)?.trim(),
    );
  }

  static double? _asBpm(Object? raw) {
    num? n;
    if (raw is num) {
      n = raw;
    } else if (raw is String) {
      n = num.tryParse(raw.replaceAll(RegExp(r'[^0-9.]'), ''));
    }
    if (n == null) return null;
    final bpm = n.toDouble();
    if (bpm < 60 || bpm > 220) return null;
    return bpm;
  }

  static String? _durationLabel(Object? raw) {
    if (raw == null) return null;
    if (raw is num) {
      final sec = raw.round();
      if (sec <= 0 || sec > 3600) return null;
      return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return s.length > 12 ? s.substring(0, 12) : s;
  }
}
