import 'package:shared_preferences/shared_preferences.dart';

/// Persistiert die QR-Code-Dialog-Optionen (Ort, Telefon, E-Mail, Alt.-E-Mail) in SharedPreferences.
/// Device-weit (ohne Login), klare Keys, Standard: alle true.
class QrDialogOptionsService {
  static final QrDialogOptionsService _instance = QrDialogOptionsService._internal();
  factory QrDialogOptionsService() => _instance;
  QrDialogOptionsService._internal();

  static const String _keyShowLocation = 'qr_show_location';
  static const String _keyShowPhone = 'qr_show_phone';
  static const String _keyShowEmail = 'qr_show_email';
  static const String _keyShowAlternativeEmail = 'qr_show_alternative_email';

  /// Standardwerte: alle true (sinnvolle Defaults für erstes Öffnen)
  static const bool _defaultShowLocation = true;
  static const bool _defaultShowPhone = true;
  static const bool _defaultShowEmail = true;
  static const bool _defaultShowAlternativeEmail = true;

  /// Lädt die gespeicherten Optionen. Fehlt ein Wert, wird der Standard verwendet.
  Future<QrDialogOptions> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return QrDialogOptions(
        showLocation: prefs.getBool(_keyShowLocation) ?? _defaultShowLocation,
        showPhone: prefs.getBool(_keyShowPhone) ?? _defaultShowPhone,
        showEmail: prefs.getBool(_keyShowEmail) ?? _defaultShowEmail,
        showAlternativeEmail: prefs.getBool(_keyShowAlternativeEmail) ?? _defaultShowAlternativeEmail,
      );
    } catch (_) {
      return const QrDialogOptions(
        showLocation: _defaultShowLocation,
        showPhone: _defaultShowPhone,
        showEmail: _defaultShowEmail,
        showAlternativeEmail: _defaultShowAlternativeEmail,
      );
    }
  }

  /// Speichert eine Option sofort in SharedPreferences.
  Future<void> save({
    bool? showLocation,
    bool? showPhone,
    bool? showEmail,
    bool? showAlternativeEmail,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (showLocation != null) await prefs.setBool(_keyShowLocation, showLocation);
      if (showPhone != null) await prefs.setBool(_keyShowPhone, showPhone);
      if (showEmail != null) await prefs.setBool(_keyShowEmail, showEmail);
      if (showAlternativeEmail != null) await prefs.setBool(_keyShowAlternativeEmail, showAlternativeEmail);
    } catch (_) {}
  }
}

/// Unveränderliches Objekt mit den vier QR-Dialog-Anzeige-Optionen.
class QrDialogOptions {
  final bool showLocation;
  final bool showPhone;
  final bool showEmail;
  final bool showAlternativeEmail;

  const QrDialogOptions({
    this.showLocation = true,
    this.showPhone = true,
    this.showEmail = true,
    this.showAlternativeEmail = true,
  });
}
