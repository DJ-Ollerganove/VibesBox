/// 8-stellige Party-Codes: nur Ziffern in der DB; Formatierung nur für die Anzeige.
class PartyCodeUtils {
  PartyCodeUtils._();

  /// Normale Partys (Zufallsgenerierung).
  static const int normalMin = 10000000;
  static const int normalMax = 98999999;

  /// Feste Locations.
  static const int fixedMin = 99000000;
  static const int fixedMax = 99999999;

  static const int codeLength = 8;

  static String normalizeDigits(String input) =>
      input.replaceAll(RegExp(r'[^0-9]'), '');

  /// Anzeige: „1234 5678“ (ohne Bindestrich, konsistent mit QR/PDF).
  static String formatForDisplay(String? storedCode) {
    if (storedCode == null || storedCode.isEmpty) return '';
    final d = normalizeDigits(storedCode);
    if (d.length == codeLength) {
      return '${d.substring(0, 4)} ${d.substring(4)}';
    }
    return storedCode;
  }

  static bool isValidJoinLength(String raw) =>
      normalizeDigits(raw).length == codeLength;
}
