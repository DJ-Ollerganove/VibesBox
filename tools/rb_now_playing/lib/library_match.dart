class LibraryTrack {
  LibraryTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.bpm,
    this.musicalKey,
    this.lengthSec,
    this.playCount = 0,
    this.location,
  })  : identityTitle = identityTitleOf(title),
        identityArtist = identityArtistOf(artist);

  factory LibraryTrack.fromJson(Map<String, dynamic> json) {
    return LibraryTrack(
      id: (json['i'] ?? json['id'] ?? '').toString(),
      title: (json['t'] ?? json['title'] ?? '').toString(),
      artist: (json['a'] ?? json['artist'] ?? '').toString(),
      bpm: (json['b'] ?? json['bpm']) is num
          ? (json['b'] ?? json['bpm']).toDouble()
          : null,
      musicalKey: (json['k'] ?? json['key'])?.toString(),
      lengthSec: json['l'] is int
          ? json['l'] as int
          : json['lengthSec'] is int
              ? json['lengthSec'] as int
              : null,
      playCount: json['p'] is int
          ? json['p'] as int
          : json['playCount'] is int
              ? json['playCount'] as int
              : 0,
      location: (json['f'] ?? json['location'])?.toString(),
    );
  }

  final String id;
  final String title;
  final String artist;
  final double? bpm;
  final String? musicalKey;
  final int? lengthSec;
  final int playCount;
  final String? location;
  final String identityTitle;
  final String identityArtist;

  bool get isTidal {
    final loc = (location ?? '').toLowerCase();
    return loc.startsWith('tidal:');
  }

  bool get canDragToRekordbox => isRekordboxDragPath(location);

  LibraryTrack copyWith({int? playCount}) {
    return LibraryTrack(
      id: id,
      title: title,
      artist: artist,
      bpm: bpm,
      musicalKey: musicalKey,
      lengthSec: lengthSec,
      playCount: playCount ?? this.playCount,
      location: location,
    );
  }

  Map<String, dynamic> toJson() => {
        'i': id,
        't': title,
        'a': artist,
        if (bpm != null) 'b': bpm,
        if (musicalKey != null && musicalKey!.isNotEmpty) 'k': musicalKey,
        if (lengthSec != null) 'l': lengthSec,
        if (playCount > 0) 'p': playCount,
        if (location != null && location!.isNotEmpty) 'f': location,
      };
}

bool isRekordboxDragPath(String? loc) {
  if (loc == null || loc.isEmpty) return false;
  if (loc.startsWith('/')) return true;
  if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(loc)) return true;
  return loc.toLowerCase().startsWith('tidal:tracks:');
}

/// Datei oder Tidal-URI aus den Pfadformaten der DJ-Programme.
String? toDragLocation(String? raw) {
  if (raw == null) return null;
  final text = raw.trim();
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();
  final id = _tidalTrackId(lower) ?? _tidalTrackId(text);
  if (id != null) return 'tidal:tracks:$id';
  return text;
}

String? _tidalTrackId(String raw) {
  final patterns = [
    RegExp(r'streaming://tidal/(\d+)', caseSensitive: false),
    RegExp(r'tidal:tracks:(\d+)', caseSensitive: false),
    RegExp(r'tidal://(?:track|tracks)/(\d+)', caseSensitive: false),
    RegExp(r'tidal\.com/(?:browse/)?(?:track|tracks)/(\d+)', caseSensitive: false),
    RegExp(r'netsearch://[^/]*tidal[^/]*/(?:track|tracks)/(\d+)', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(raw);
    if (match != null) return match.group(1);
  }
  return null;
}

class LibraryMatch {
  const LibraryMatch({required this.track, required this.score});

  final LibraryTrack track;
  final double score;
}

/// Findet in der lokalen Rekordbox-Bibliothek den passenden Titel.
/// Bei mehreren Treffern gewinnt immer der mit den meisten Plays.
class LibraryIndex {
  LibraryIndex(List<LibraryTrack> tracks)
      : _tracks = List<LibraryTrack>.unmodifiable(tracks);

  final List<LibraryTrack> _tracks;

  bool get isEmpty => _tracks.isEmpty;
  int get length => _tracks.length;
  List<LibraryTrack> get tracks => _tracks;

  LibraryTrack? match(String title, String artist) {
    return matchScored(title, artist)?.track;
  }

  LibraryMatch? matchScored(String title, String artist) {
    final qId = identityTitleOf(title);
    final qArtist = identityArtistOf(artist);
    if (qId.length < 2) return null;

    LibraryTrack? best;
    var bestPlays = -1;
    var bestScore = -1.0;

    for (final track in _tracks) {
      if (track.identityTitle.length < 2) continue;
      final titleSim = _workSimilarity(qId, track.identityTitle);
      if (titleSim < 0.82) continue;
      final artistSim = _artistSimilarity(qArtist, track.identityArtist);
      final corresponding = titleSim >= 0.88
          ? artistSim >= 0.55
          : artistSim >= 0.72;
      if (!corresponding) continue;
      final score = titleSim * 0.75 + artistSim * 0.25;
      if (track.playCount > bestPlays ||
          (track.playCount == bestPlays && score > bestScore)) {
        best = track;
        bestPlays = track.playCount;
        bestScore = score;
      }
    }
    if (best == null) return null;
    return LibraryMatch(track: best, score: bestScore);
  }
}

/// Remix, Radio Edit, Live usw. gelten als derselbe Song.
bool isSameWork({
  required String titleA,
  required String artistA,
  required String titleB,
  required String artistB,
}) {
  final ta = identityTitleOf(titleA);
  final tb = identityTitleOf(titleB);
  if (ta.length < 2 || tb.length < 2) return false;
  final titleSim = _workSimilarity(ta, tb);
  final artistSim = _artistSimilarity(
    identityArtistOf(artistA),
    identityArtistOf(artistB),
  );
  if (titleSim >= 0.88 && artistSim >= 0.55) return true;
  if (titleSim >= 0.94 && ta.replaceAll(' ', '').length >= 10) return true;
  final shorter = ta.length <= tb.length ? ta : tb;
  final longer = ta.length <= tb.length ? tb : ta;
  if (shorter.length >= 6 &&
      longer.startsWith('$shorter ') &&
      artistSim >= 0.55) {
    return true;
  }
  return false;
}

String workKeyOf(String title, String artist) {
  final t = identityTitleOf(title).replaceAll(' ', '');
  final a = identityArtistOf(artist).replaceAll(' ', '');
  if (t.length < 2) return '';
  return '$t|$a';
}

/// Aktuell laufenden Song (inkl. Remix/Version) und doppelte Werke entfernen.
List<Map<String, dynamic>> withoutSameAsPlaying(
  List<Map<String, dynamic>> items, {
  required String seedTitle,
  required String seedArtist,
  String? seedLocation,
  int keep = 5,
  List<Map<String, dynamic>> alsoSkip = const [],
}) {
  final out = <Map<String, dynamic>>[];
  final seenWorks = <String>{workKeyOf(seedTitle, seedArtist)};
  final seenLoc = <String>{
    if (seedLocation != null && seedLocation.isNotEmpty) seedLocation,
  };
  for (final skip in alsoSkip) {
    final t = (skip['title'] ?? '').toString();
    final a = (skip['artist'] ?? '').toString();
    final k = workKeyOf(t, a);
    if (k.isNotEmpty) seenWorks.add(k);
    final loc = (skip['location'] ?? '').toString();
    if (loc.isNotEmpty) seenLoc.add(loc);
  }
  for (final item in items) {
    final title = (item['title'] ?? '').toString();
    final artist = (item['artist'] ?? '').toString();
    if (title.trim().isEmpty) continue;
    if (isSameWork(
      titleA: seedTitle,
      artistA: seedArtist,
      titleB: title,
      artistB: artist,
    )) {
      continue;
    }
    var skipped = false;
    for (final skip in alsoSkip) {
      if (isSameWork(
        titleA: (skip['title'] ?? '').toString(),
        artistA: (skip['artist'] ?? '').toString(),
        titleB: title,
        artistB: artist,
      )) {
        skipped = true;
        break;
      }
    }
    if (skipped) continue;
    final loc = (item['location'] ?? '').toString();
    if (loc.isNotEmpty && seenLoc.contains(loc)) continue;
    final key = workKeyOf(title, artist);
    if (key.isEmpty || seenWorks.contains(key)) continue;
    seenWorks.add(key);
    if (loc.isNotEmpty) seenLoc.add(loc);
    out.add(item);
    if (out.length >= keep) break;
  }
  return out;
}

String identityTitleOf(String raw) {
  var text = _fold(raw);
  text = text.replaceAll(_parenOrBracket, ' ');
  text = text.replaceAll(_featCut, ' ');
  return _squash(text);
}

String identityArtistOf(String raw) {
  var text = _fold(raw);
  text = text.replaceAll(_parenOrBracket, ' ');
  text = text.replaceAll(_artistJoin, ' ');
  return _squash(text);
}

double _workSimilarity(String a, String b) {
  if (a == b) return 1;
  final ratio = _levenshteinRatio(a, b);
  final jaccard = _tokenJaccard(a, b);
  final contain = _containsAsWork(a, b);
  var best = ratio > jaccard ? ratio : jaccard;
  if (contain && best < 0.9) best = 0.9;
  return best;
}

double _artistSimilarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0.8;
  if (a == b) return 1;
  if (_artistPhraseHit(a, b)) return 0.92;
  final ratio = _levenshteinRatio(a, b);
  final jaccard = _tokenJaccard(a, b);
  return ratio > jaccard ? ratio : jaccard;
}

bool _artistPhraseHit(String a, String b) {
  final shorter = a.length <= b.length ? a : b;
  final longer = a.length <= b.length ? b : a;
  if (shorter.length < 4) return false;
  if (longer.contains(shorter)) return true;
  return (' $longer ').contains(' $shorter ');
}

bool _containsAsWork(String a, String b) {
  final shorter = a.length <= b.length ? a : b;
  final longer = a.length <= b.length ? b : a;
  if (shorter.length < 8 && shorter.split(' ').length < 2) return false;
  if (longer.length > shorter.length * 3) return false;
  if (longer.startsWith('$shorter ') || longer == shorter) return true;
  final shortTokens = shorter.split(' ').where((t) => t.length > 1).toList();
  if (shortTokens.length < 2) return false;
  var from = 0;
  for (final token in shortTokens) {
    final at = longer.indexOf(token, from);
    if (at < 0) return false;
    from = at + token.length;
  }
  return true;
}

double _tokenJaccard(String a, String b) {
  final sa = a.split(' ').where((t) => t.isNotEmpty).toSet();
  final sb = b.split(' ').where((t) => t.isNotEmpty).toSet();
  if (sa.isEmpty || sb.isEmpty) return 0;
  final inter = sa.intersection(sb).length;
  final union = sa.union(sb).length;
  return union == 0 ? 0 : inter / union;
}

double _levenshteinRatio(String a, String b) {
  if (a == b) return 1;
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 1;
  return 1 - (_levenshtein(a, b) / maxLen);
}

int _levenshtein(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  if ((a.length - b.length).abs() > 12 && a.length > 8 && b.length > 8) {
    return a.length > b.length ? a.length : b.length;
  }
  final m = a.length;
  final n = b.length;
  var prev = List<int>.generate(n + 1, (i) => i);
  var curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    final ca = a.codeUnitAt(i - 1);
    for (var j = 1; j <= n; j++) {
      final cost = ca == b.codeUnitAt(j - 1) ? 0 : 1;
      final del = prev[j] + 1;
      final ins = curr[j - 1] + 1;
      final sub = prev[j - 1] + cost;
      var v = del < ins ? del : ins;
      if (sub < v) v = sub;
      curr[j] = v;
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}

String _fold(String raw) {
  var text = raw.toLowerCase();
  text = text
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
  return text;
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
  return buf.toString().trim();
}

final _parenOrBracket = RegExp(r'[\(\[].*?[\)\]]');
final _featCut = RegExp(
  r'\s+(feat\.?|ft\.?|featuring|vs\.?|x)\s+.+$',
  caseSensitive: false,
);
final _artistJoin = RegExp(
  r'\s*(?:feat\.?|ft\.?|featuring|vs\.?|versus|\bx\b|&|/|,|\+)\s*',
  caseSensitive: false,
);
