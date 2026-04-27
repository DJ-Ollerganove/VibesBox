String unescapeHtml(String text) {
  if (text.isEmpty) return text;

  var current = text;
  for (var i = 0; i < 8; i++) {
    final decoded = _decodeHtmlOnce(current);
    if (decoded == current) break;
    current = decoded;
  }
  return current;
}

String _decodeHtmlOnce(String text) {
  var result = text;

  // Numerisch mit Semikolon: &#39; &#x27;
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

  // HTML5: hex ohne Semikolon, z. B. "Don&#x27t" (häufig in Spotify/Metadaten-Strings)
  result = result.replaceAllMapped(
    RegExp(r'&#x([0-9A-Fa-f]{1,6})(?![0-9A-Fa-f])', caseSensitive: false),
    (match) {
      final hex = match.group(1);
      if (hex == null) return match.group(0)!;
      final cp = int.tryParse(hex, radix: 16);
      if (cp == null || cp < 0 || cp > 0x10ffff) return match.group(0)!;
      return String.fromCharCode(cp);
    },
  );

  // HTML5: dezimal ohne Semikolon, z. B. "&#39t" (seltener)
  result = result.replaceAllMapped(RegExp(r'&#([0-9]{1,7})(?![0-9])'), (match) {
    final dec = match.group(1);
    if (dec == null) return match.group(0)!;
    final cp = int.tryParse(dec, radix: 10);
    if (cp == null || cp < 0 || cp > 0x10ffff) return match.group(0)!;
    return String.fromCharCode(cp);
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

  // Benannte Entities ohne Semikolon (z. B. &quot gefolgt von Buchstabe/Leerzeichen)
  result = result.replaceAllMapped(
    RegExp(r'&(quot|apos|amp|lt|gt|nbsp)(?![a-zA-Z0-9#])', caseSensitive: false),
    (match) {
      final key = match.group(1);
      if (key == null) return match.group(0)!;
      return namedEntities[key.toLowerCase()] ?? match.group(0)!;
    },
  );

  return result;
}
