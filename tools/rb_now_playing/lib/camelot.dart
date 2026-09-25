String? camelotFromScaleName(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s
      .replaceAll('♯', '#')
      .replaceAll('♭', 'b')
      .replaceAll(RegExp(r'\s+'), '');
  final camelot = RegExp(r'^0?([1-9]|1[0-2])([ABab])$').firstMatch(s);
  if (camelot != null) {
    return '${camelot.group(1)}${camelot.group(2)!.toUpperCase()}';
  }
  var key = s.toLowerCase();
  key = key
      .replaceAll('major', '')
      .replaceAll('minor', 'm')
      .replaceAll('dur', '')
      .replaceAll('moll', 'm')
      .replaceAll('maj', '')
      .replaceAll('min', 'm');
  const map = {
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
  return map[key];
}
