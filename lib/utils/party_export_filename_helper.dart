import 'package:intl/intl.dart';

/// Dateiname für QR-/PDF-Exporte: `{Vorlage}_{Partytitel}_{Datum}` (ohne Endung).
class PartyExportFilenameHelper {
  PartyExportFilenameHelper._();

  static const String qrImageFilePrefix = 'QR-Code';

  /// PDF-Vorlagen: `{Vorlage}_{Partytitel}_{Datum}` (ohne Endung).
  static String build({
    required String templateLabel,
    required String partyName,
    required DateTime partyStartDate,
  }) {
    final template = _sanitizeSegment(templateLabel);
    final title = _sanitizeSegment(partyName);
    final date = _formatPartyDate(partyStartDate);
    return '${template}_${title}_$date';
  }

  /// QR-Galerie-Bild: `QR-Code {Partytitel} {Datum}.jpg`
  static String buildQrImageFileName({
    required String partyName,
    required DateTime partyStartDate,
  }) {
    final title = _sanitizePartyNameForSpaces(partyName);
    final date = _formatPartyDate(partyStartDate);
    return '$qrImageFilePrefix $title $date.jpg';
  }

  static String _sanitizePartyNameForSpaces(String input) {
    var s = input.trim();
    if (s.isEmpty) return 'Party';
    s = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    if (s.length > 80) s = s.substring(0, 80).trim();
    return s.isEmpty ? 'Party' : s;
  }

  static String _formatPartyDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date.toLocal());
  }

  static String _sanitizeSegment(String input) {
    var s = input.trim();
    if (s.isEmpty) return 'Party';

    s = s.replaceAll('(', '_').replaceAll(')', '');
    s = s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    s = s.replaceAll(RegExp(r'\s+'), '_');
    s = s.replaceAll(RegExp(r'[_\-]+'), '_');
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');

    if (s.isEmpty) return 'Party';
    if (s.length > 80) {
      s = s.substring(0, 80).replaceAll(RegExp(r'_+$'), '');
    }
    return s;
  }
}
