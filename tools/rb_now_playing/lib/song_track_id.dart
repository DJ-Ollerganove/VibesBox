import 'dart:io';

import 'library_match.dart';

class TrackIdentity {
  const TrackIdentity({
    required this.id,
    required this.artist,
    required this.title,
    required this.version,
  });

  final String id;
  final String artist;
  final String title;
  final String version;
}

/// `interpret_titel_version` — kleingeschrieben, ohne Sonderzeichen.
TrackIdentity trackIdentityOf({
  required String artist,
  required String title,
  String? version,
}) {
  final split = splitTitleVersion(title);
  final ver = (version != null && version.trim().isNotEmpty)
      ? prettyVersion(version)
      : split.version;
  final artistSlug = slugTrackPart(artist);
  final titleSlug = slugTrackPart(split.title);
  final versionSlug = slugTrackPart(ver);
  var id = '${artistSlug}_${titleSlug}_$versionSlug';
  if (id.length > 700) id = id.substring(0, 700);
  return TrackIdentity(
    id: id,
    artist: artist.trim(),
    title: split.title,
    version: ver,
  );
}

/// Cache-Dokument: Song plus Musikraum/Bekanntheit/gleicher Interpret.
/// Anzahl 1–20 gehört nicht in den Schlüssel: 20 gecachte Titel decken 1–20 ab.
String suggestionCacheDocId({
  required String artist,
  required String title,
  required String scope,
  required String familiarity,
  required bool allowSameArtist,
  String? version,
}) {
  final track = trackIdentityOf(artist: artist, title: title, version: version);
  final same = allowSameArtist ? 'same' : 'nosame';
  var id =
      '${track.id}__${slugTrackPart(scope)}_${slugTrackPart(familiarity)}_$same';
  if (id.length > 700) id = id.substring(0, 700);
  return id;
}

({String title, String version}) splitTitleVersion(String raw) {
  final text = raw.trim();
  final match = _trailingVersion.firstMatch(text);
  if (match == null) {
    return (title: text, version: 'Original');
  }
  final base = (match.group(1) ?? '').trim();
  final ver = prettyVersion(match.group(2) ?? '');
  return (title: base.isEmpty ? text : base, version: ver);
}

String prettyVersion(String raw) {
  final lower = raw.trim().toLowerCase();
  if (lower.isEmpty) return 'Original';
  if (lower.contains('radio')) return 'Radio Edit';
  if (lower.contains('extended')) return 'Extended Mix';
  if (lower.contains('club')) return 'Club Mix';
  if (lower.contains('original')) return 'Original';
  if (lower.contains('instrumental')) return 'Instrumental';
  if (lower.contains('remix')) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
  if (lower == 'edit' || lower == 'mix') {
    final t = raw.trim();
    return '${t[0].toUpperCase()}${t.substring(1).toLowerCase()}';
  }
  return raw.trim();
}

String slugTrackPart(String raw) {
  final squashed = identityTitleOf(raw);
  if (squashed.isEmpty) return 'x';
  return squashed.replaceAll(' ', '_');
}

String metricsSoftwareId(String? softwareId) {
  switch (softwareId) {
    case 'enginedj':
      return 'engine_dj';
    case 'virtualdj':
      return 'virtualdj';
    case 'serato':
      return 'serato';
    case 'traktor':
      return 'traktor';
    case 'mixxx':
      return 'mixxx';
    case 'rekordbox':
      return 'rekordbox';
    default:
      return (softwareId == null || softwareId.isEmpty) ? 'unknown' : softwareId;
  }
}

/// z. B. `macos_15_6` / `windows_10_0_22631`.
String metricsOsKey() {
  final name = Platform.isMacOS
      ? 'macos'
      : Platform.isWindows
          ? 'windows'
          : Platform.operatingSystem;
  final version = Platform.operatingSystemVersion;
  final slug = '${name}_$version'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (slug.isEmpty) return 'unknown';
  return slug.length > 48 ? slug.substring(0, 48) : slug;
}

final _trailingVersion = RegExp(
  r'^(.*?)[\s]*[\(\[][\s]*(extended mix|extended|club mix|radio edit|original mix|instrumental|remix|edit|mix)[\s]*[\)\]][\s]*$',
  caseSensitive: false,
);
