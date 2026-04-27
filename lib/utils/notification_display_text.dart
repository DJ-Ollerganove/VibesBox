import 'string_utils.dart';

/// Dekodiert HTML-Entities aus Firestore/API/Shazam (z. B. `&#x27;`, `&amp;`),
/// damit Benachrichtigungen und Statuszeile echte Apostrophe/Zeichen zeigen.
///
/// Verwendet [unescapeHtml] (u. a. `&#x27;` mit/ohne Semikolon) — zuverlässiger als
/// nur [HtmlUnescape] aus dem Paket `html_unescape`.
String decodeNotificationDisplayText(String input) {
  if (input.isEmpty) return input;
  return unescapeHtml(input);
}
