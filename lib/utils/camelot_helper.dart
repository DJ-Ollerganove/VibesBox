/// Rekordbox-Tonart (ScaleName / Key) → Camelot wie 8A / 9B.
class CamelotHelper {
  CamelotHelper._();

  static final RegExp _camelot = RegExp(r'^0?([1-9]|1[0-2])([AB])$');

  static const Map<String, String> _fromTraditional = {
    'abm': '1A',
    'g#m': '1A',
    'b': '1B',
    'ebm': '2A',
    'd#m': '2A',
    'f#': '2B',
    'gb': '2B',
    'bbm': '3A',
    'a#m': '3A',
    'db': '3B',
    'c#': '3B',
    'fm': '4A',
    'ab': '4B',
    'g#': '4B',
    'cm': '5A',
    'eb': '5B',
    'd#': '5B',
    'gm': '6A',
    'bb': '6B',
    'a#': '6B',
    'dm': '7A',
    'f': '7B',
    'am': '8A',
    'c': '8B',
    'em': '9A',
    'g': '9B',
    'bm': '10A',
    'd': '10B',
    'f#m': '11A',
    'gbm': '11A',
    'a': '11B',
    'c#m': '12A',
    'dbm': '12A',
    'e': '12B',
  };

  static String? fromScaleName(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    s = s
        .replaceAll('♯', '#')
        .replaceAll('♭', 'b')
        .replaceAll(RegExp(r'\s+'), '');
    final camelotHit = _camelot.firstMatch(s.toUpperCase());
    if (camelotHit != null) {
      return '${camelotHit.group(1)}${camelotHit.group(2)}';
    }
    var key = s.toLowerCase();
    key = key
        .replaceAll('major', '')
        .replaceAll('minor', 'm')
        .replaceAll('dur', '')
        .replaceAll('moll', 'm')
        .replaceAll('maj', '')
        .replaceAll('min', 'm');
    if (key.endsWith('m') && key.length > 1 && key[key.length - 2] == 'm') {
      key = key.substring(0, key.length - 1);
    }
    final mapped = _fromTraditional[key];
    return mapped;
  }

  static String? formatBpm(num? bpm) {
    if (bpm == null || bpm <= 0) return null;
    final rounded = bpm.round();
    if ((bpm - rounded).abs() < 0.05) return '$rounded BPM';
    return '${bpm.toStringAsFixed(1)} BPM';
  }
}
