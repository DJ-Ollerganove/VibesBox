import 'package:shared_preferences/shared_preferences.dart';

/// Persistiert die QR-Code-Dialog-Optionen in SharedPreferences (geräte-weit).
class QrDialogOptionsService {
  static final QrDialogOptionsService _instance =
      QrDialogOptionsService._internal();
  factory QrDialogOptionsService() => _instance;
  QrDialogOptionsService._internal();

  static const String _keyShowLocationName = 'qr_show_location_name';
  static const String _keyShowLocationAddress = 'qr_show_location_address';
  static const String _legacyKeyShowLocation = 'qr_show_location';
  static const String _keyShowPhone = 'qr_show_phone';
  static const String _keyShowEmail = 'qr_show_email';
  static const String _keyShowAlternativeEmail = 'qr_show_alternative_email';
  static const String _keyShowStartDate = 'qr_show_start_date';
  static const String _keyShowStartTime = 'qr_show_start_time';

  static const bool _defaultShowLocationName = true;
  static const bool _defaultShowLocationAddress = true;
  static const bool _defaultShowPhone = true;
  static const bool _defaultShowEmail = true;
  static const bool _defaultShowAlternativeEmail = true;
  /// Nie gespeichert → an (bestehende DJs behalten Datum/Uhrzeit sichtbar).
  static const bool _defaultShowStartDate = true;
  static const bool _defaultShowStartTime = true;

  Future<QrDialogOptions> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyLocation = prefs.getBool(_legacyKeyShowLocation);
      final hasNewKeys = prefs.containsKey(_keyShowLocationName) ||
          prefs.containsKey(_keyShowLocationAddress);
      final migratedDefault = legacyLocation ?? true;
      return QrDialogOptions(
        showLocationName: prefs.getBool(_keyShowLocationName) ??
            (hasNewKeys ? _defaultShowLocationName : migratedDefault),
        showLocationAddress: prefs.getBool(_keyShowLocationAddress) ??
            (hasNewKeys ? _defaultShowLocationAddress : migratedDefault),
        showPhone: prefs.getBool(_keyShowPhone) ?? _defaultShowPhone,
        showEmail: prefs.getBool(_keyShowEmail) ?? _defaultShowEmail,
        showAlternativeEmail:
            prefs.getBool(_keyShowAlternativeEmail) ??
            _defaultShowAlternativeEmail,
        showStartDate:
            prefs.getBool(_keyShowStartDate) ?? _defaultShowStartDate,
        showStartTime:
            prefs.getBool(_keyShowStartTime) ?? _defaultShowStartTime,
      );
    } catch (_) {
      return const QrDialogOptions();
    }
  }

  Future<void> save({
    bool? showLocationName,
    bool? showLocationAddress,
    bool? showPhone,
    bool? showEmail,
    bool? showAlternativeEmail,
    bool? showStartDate,
    bool? showStartTime,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (showLocationName != null) {
        await prefs.setBool(_keyShowLocationName, showLocationName);
      }
      if (showLocationAddress != null) {
        await prefs.setBool(_keyShowLocationAddress, showLocationAddress);
      }
      if (showPhone != null) await prefs.setBool(_keyShowPhone, showPhone);
      if (showEmail != null) await prefs.setBool(_keyShowEmail, showEmail);
      if (showAlternativeEmail != null) {
        await prefs.setBool(_keyShowAlternativeEmail, showAlternativeEmail);
      }
      if (showStartDate != null) {
        await prefs.setBool(_keyShowStartDate, showStartDate);
      }
      if (showStartTime != null) {
        await prefs.setBool(_keyShowStartTime, showStartTime);
      }
    } catch (_) {}
  }
}

class QrDialogOptions {
  final bool showLocationName;
  final bool showLocationAddress;
  final bool showPhone;
  final bool showEmail;
  final bool showAlternativeEmail;
  final bool showStartDate;
  final bool showStartTime;

  const QrDialogOptions({
    this.showLocationName = true,
    this.showLocationAddress = true,
    this.showPhone = true,
    this.showEmail = true,
    this.showAlternativeEmail = true,
    this.showStartDate = true,
    this.showStartTime = true,
  });
}
