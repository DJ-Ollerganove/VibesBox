import '../helpers/security_helper.dart';
import '../utils/text_utils.dart';

/// Ein Eintrag der DJ-Song-Blacklist: Titel, Interpret oder beides.
class DjSongBlacklistEntry {
  const DjSongBlacklistEntry({
    required this.id,
    this.title = '',
    this.artist = '',
  });

  final String id;
  final String title;
  final String artist;

  bool get hasTitle => title.trim().isNotEmpty;
  bool get hasArtist => artist.trim().isNotEmpty;

  String get displayLabel {
    if (hasTitle && hasArtist) return '${title.trim()} – ${artist.trim()}';
    if (hasTitle) return title.trim();
    return artist.trim();
  }

  /// Sortierschlüssel: Titel, sonst Interpret — eine alphabetische Liste.
  String get sortKey {
    if (hasTitle) return canonicalString(title);
    return canonicalString(artist);
  }

  static List<DjSongBlacklistEntry> sortedCopy(
    Iterable<DjSongBlacklistEntry> entries,
  ) {
    final out = entries.toList();
    out.sort((a, b) {
      final byKey = a.sortKey.compareTo(b.sortKey);
      if (byKey != 0) return byKey;
      return a.displayLabel.toLowerCase().compareTo(b.displayLabel.toLowerCase());
    });
    return out;
  }

  Map<String, dynamic> toJson() {
    final safeId = SecurityHelper.sanitize(id, maxLength: 80);
    final safeTitle = SecurityHelper.sanitize(title, maxLength: 100);
    final safeArtist = SecurityHelper.sanitize(artist, maxLength: 100);
    return <String, dynamic>{
      'id': safeId,
      if (safeTitle.isNotEmpty) 'title': safeTitle,
      if (safeArtist.isNotEmpty) 'artist': safeArtist,
    };
  }

  static DjSongBlacklistEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final title = SecurityHelper.sanitize(
      (map['title'] as String?) ?? '',
      maxLength: 100,
    );
    final artist = SecurityHelper.sanitize(
      (map['artist'] as String?) ?? '',
      maxLength: 100,
    );
    if (title.isEmpty && artist.isEmpty) return null;
    final id = SecurityHelper.sanitize(
      (map['id'] as String?) ?? '',
      maxLength: 80,
    );
    return DjSongBlacklistEntry(
      id: id.isEmpty ? 'e_${title.hashCode}_${artist.hashCode}' : id,
      title: title,
      artist: artist,
    );
  }

  static List<DjSongBlacklistEntry> listFrom(Object? raw) {
    if (raw is! List) return const [];
    final out = <DjSongBlacklistEntry>[];
    for (final entry in raw) {
      final parsed = tryParse(entry);
      if (parsed == null) continue;
      out.add(parsed);
      if (out.length >= 200) break;
    }
    return out;
  }

  static bool matches({
    required String title,
    required String artist,
    required List<DjSongBlacklistEntry> entries,
  }) {
    if (entries.isEmpty) return false;
    final t = canonicalString(title);
    final a = canonicalString(artist);
    if (t.isEmpty && a.isEmpty) return false;

    for (final e in entries) {
      if (e.hasTitle && e.hasArtist) {
        if (t == canonicalString(e.title) && a == canonicalString(e.artist)) {
          return true;
        }
      }
    }
    for (final e in entries) {
      if (e.hasTitle && !e.hasArtist && t.isNotEmpty) {
        if (t == canonicalString(e.title)) return true;
      }
    }
    for (final e in entries) {
      if (e.hasArtist && !e.hasTitle && a.isNotEmpty) {
        if (a == canonicalString(e.artist)) return true;
      }
    }
    return false;
  }
}
