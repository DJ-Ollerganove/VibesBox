String unescapeHtml(String text) {
  if (text.isEmpty) return text;

  var current = text;
  for (var i = 0; i < 3; i++) {
    final decoded = _decodeHtmlOnce(current);
    if (decoded == current) break;
    current = decoded;
  }
  return current;
}

String _decodeHtmlOnce(String text) {
  var result = text;

  result = result.replaceAllMapped(RegExp(r'&#(x?[0-9A-Fa-f]+);'), (match) {
    final raw = match.group(1);
    if (raw == null || raw.isEmpty) return match.group(0)!;

    int? codePoint;
    if (raw.startsWith('x') || raw.startsWith('X')) {
      codePoint = int.tryParse(raw.substring(1), radix: 16);
    } else {
      codePoint = int.tryParse(raw, radix: 10);
    }
    if (codePoint == null) return match.group(0)!;
    return String.fromCharCode(codePoint);
  });

  const namedEntities = <String, String>{
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'nbsp': ' ',
    'auml': 'ä',
    'ouml': 'ö',
    'uuml': 'ü',
    'Auml': 'Ä',
    'Ouml': 'Ö',
    'Uuml': 'Ü',
    'szlig': 'ß',
    'euro': '€',
  };

  result = result.replaceAllMapped(RegExp(r'&([A-Za-z]+);'), (match) {
    final key = match.group(1);
    if (key == null) return match.group(0)!;
    return namedEntities[key] ?? match.group(0)!;
  });

  return result;
}
