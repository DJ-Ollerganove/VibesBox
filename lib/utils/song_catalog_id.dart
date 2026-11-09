/// Dieselbe Dokument-Id wie im Sync-Tool (`song_track_id.dart` + `identityTitleOf`).
/// Remix-Klammern bleiben in der Fassung, der Lied-Datensatz ist Interpret_Titel_Fassung.
String songCatalogDocId({
  required String artist,
  required String title,
}) {
  final split = splitCatalogTitleVersion(title);
  var id =
      '${_slug(artist)}_${_slug(split.title)}_${_slug(split.version)}';
  if (id.length > 700) id = id.substring(0, 700);
  return id;
}

String suggestionCatalogDocId({
  required String artist,
  required String title,
  required String scope,
  required String familiarity,
  required bool allowSameArtist,
}) {
  final track = songCatalogDocId(artist: artist, title: title);
  final same = allowSameArtist ? 'same' : 'nosame';
  var id = '${track}__${_slug(scope)}_${_slug(familiarity)}_$same';
  if (id.length > 700) id = id.substring(0, 700);
  return id;
}

({String title, String version}) splitCatalogTitleVersion(String raw) {
  final text = raw.trim();
  final match = _trailingVersion.firstMatch(text);
  if (match == null) return (title: text, version: 'Original');
  final base = (match.group(1) ?? '').trim();
  return (
    title: base.isEmpty ? text : base,
    version: _prettyVersion(match.group(2) ?? ''),
  );
}

String _prettyVersion(String raw) {
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

String _slug(String raw) {
  final squashed = _identity(raw);
  if (squashed.isEmpty) return 'x';
  return squashed.replaceAll(' ', '_');
}

String _identity(String raw) {
  var text = _fold(raw);
  text = text.replaceAll(_parenOrBracket, ' ');
  text = text.replaceAll(_featCut, ' ');
  return _squash(text);
}

String _fold(String raw) {
  return raw
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('ñ', 'n');
}

String _squash(String raw) {
  final buf = StringBuffer();
  var space = false;
  for (final unit in raw.codeUnits) {
    final isAlpha = (unit >= 97 && unit <= 122) || (unit >= 48 && unit <= 57);
    if (isAlpha) {
      if (space && buf.isNotEmpty) buf.write(' ');
      buf.writeCharCode(unit);
      space = false;
    } else {
      space = true;
    }
  }
  final latin = buf.toString().trim();
  if (latin.isNotEmpty) return latin;
  return raw
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

final _parenOrBracket = RegExp(r'[\(\[].*?[\)\]]');
final _featCut = RegExp(
  r'\s+(feat\.?|ft\.?|featuring|vs\.?|x)\s+.+$',
  caseSensitive: false,
);
final _trailingVersion = RegExp(
  r'^(.*?)[\s]*[\(\[][\s]*(extended mix|extended|club mix|radio edit|original mix|instrumental|remix|edit|mix)[\s]*[\)\]][\s]*$',
  caseSensitive: false,
);
