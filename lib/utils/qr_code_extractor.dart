/// Extrahiert den Party-Code (genau 8 Ziffern) aus VibesBox-QR-Inhalten.
///
/// Unterstützte Formate:
/// - https://vibesbox.app/?code=12345678
/// - djwunschbox://wunschbox?code=12345678
/// - Reine Ziffernfolge: 8-stellig
String? extractPartyCodeFromQr(String raw) {
  if (raw.isEmpty) return null;
  final trimmed = raw.trim();

  if (RegExp(r'^\d{8}$').hasMatch(trimmed)) return trimmed;

  try {
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final code = uri.queryParameters['code']?.trim();
      if (code != null &&
          code.length == 8 &&
          RegExp(r'^\d+$').hasMatch(code)) {
        return code;
      }
    }
  } catch (_) {}

  final codeMatch =
      RegExp(r'code=(\d{8})', caseSensitive: false).firstMatch(trimmed);
  if (codeMatch != null) {
    final g = codeMatch.group(1)!;
    if (g.length == 8) return g;
  }

  if (trimmed.toLowerCase().contains('vibesbox') ||
      trimmed.toLowerCase().contains('djwunschbox')) {
    final eight = RegExp(r'\d{8}').firstMatch(trimmed);
    if (eight != null) return eight.group(0);
  }

  final eight = RegExp(r'\d{8}').firstMatch(trimmed);
  if (eight != null) return eight.group(0);

  return null;
}
