/// Hilfsfunktionen für Text-Normalisierung (z. B. Duplikat-Vergleich).
/// Nur für internen Vergleich – Anzeige bleibt unverändert.

import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Standardliste ignorierter Begriffe, wenn in Firestore (party_settings/current) nichts gesetzt ist.
const List<String> kIgnoredKeywordsDefault = [
  'Remix',
  'Mix',
  'Edit',
  'Radio',
  'Club',
  'Extended',
  'Video',
  'Version',
];

/// Kanonischer String für Vergleiche (Musikerkennung, Ähnlichkeit, konsistent mit Duplikat-Logik):
/// - Unicode NFC (stabile Kodierung, z. B. Umlaute)
/// - Trim, Mehrfach-Leerzeichen → ein Leerzeichen
/// - Kleinschreibung, Umlaute vereinheitlicht (ä→a, …)
/// - Sonderzeichen und Interpunktion entfernt (nur „Wort“-Zeichen und Leerzeichen)
String canonicalString(String s) {
  if (s.isEmpty) return '';
  String t = unorm.nfc(s);
  t = t.trim();
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  t = t.toLowerCase();
  t = t.replaceAll('ä', 'a').replaceAll('ö', 'o').replaceAll('ü', 'u').replaceAll('ß', 'ss');
  t = t.replaceAll(RegExp(r'[^\w\s]'), '');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t;
}

/// Normalisiert Text nur für den Duplikat-Vergleich:
/// - Unicode NFC
/// - Inhalte in (...) und [...] entfernen
/// - Begriffe aus [ignoredKeywords] am Ende des Titels entfernen (z. B. "Club Mix", "Remix")
/// - anschließend [canonicalString] (Kleinschreibung, Umlaute, Sonderzeichen, Whitespace)
///
/// [ignoredKeywords]: Liste aus Firestore (party_settings/current.ignored_keywords).
/// Wenn null oder leer, wird [kIgnoredKeywordsDefault] verwendet.
String normalizeTextForDuplicateCheck(String text, List<String>? ignoredKeywords) {
  if (text.isEmpty) return '';
  String s = unorm.nfc(text.trim());
  // Klammern inkl. Inhalt entfernen
  s = s.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ');
  s = s.replaceAll(RegExp(r'\s*\[[^\]]*\]\s*'), ' ');
  // Ignorierte Begriffe am Ende entfernen (mehrfach, bis stabil)
  final list = (ignoredKeywords != null && ignoredKeywords.isNotEmpty)
      ? ignoredKeywords
      : kIgnoredKeywordsDefault;
  if (list.isNotEmpty) {
    final escaped = list.map((k) => RegExp.escape(k)).join('|');
    if (escaped.isNotEmpty) {
      final trailingTerms = RegExp('\\s+($escaped)\\s*\$', caseSensitive: false);
      String prev = '';
      while (prev != s) {
        prev = s;
        s = s.replaceAll(trailingTerms, ' ').trim();
      }
    }
  }
  return canonicalString(s);
}
