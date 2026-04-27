import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

/// Speichert und synchronisiert die PDF-Anzeige-Optionen (Ort, Telefon, E-Mail, Alt.-E-Mail).
/// Liest beim Login aus Firestore, hält lokalen Cache (SharedPreferences), schreibt bei Toggle sofort lokal + Firestore.
class PdfDisplayOptionsService {
  static final PdfDisplayOptionsService _instance = PdfDisplayOptionsService._internal();
  factory PdfDisplayOptionsService() => _instance;
  PdfDisplayOptionsService._internal();

  static const String _prefix = 'pdf_opts_';

  static String _key(String uid, String field) => '$_prefix${uid}_$field';

  /// Speichert die Optionen eines UserModels im lokalen Cache (z. B. nach Firestore-Snapshot).
  static Future<void> cacheFromUserModel(UserModel userModel) async {
    await _cacheToPrefs(
      uid: userModel.id,
      showLocationOnPdf: userModel.showLocationOnPdf,
      showPhoneOnPdf: userModel.showPhoneOnPdf,
      showEmailOnPdf: userModel.showEmailOnPdf,
      showAltEmailOnPdf: userModel.showAltEmailOnPdf,
    );
  }

  static Future<void> _cacheToPrefs({
    required String uid,
    required bool showLocationOnPdf,
    required bool showPhoneOnPdf,
    required bool showEmailOnPdf,
    required bool showAltEmailOnPdf,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(uid, 'location'), showLocationOnPdf);
      await prefs.setBool(_key(uid, 'phone'), showPhoneOnPdf);
      await prefs.setBool(_key(uid, 'email'), showEmailOnPdf);
      await prefs.setBool(_key(uid, 'altEmail'), showAltEmailOnPdf);
    } catch (_) {}
  }

  /// Liest die aktuellen Optionen für den angegebenen User.
  /// Priorität: 1) userModel wenn uid stimmt, 2) SharedPreferences, 3) Default (alle false).
  Future<PdfDisplayOptions> getOptions(
    String uid, {
    bool? showLocationOnPdf,
    bool? showPhoneOnPdf,
    bool? showEmailOnPdf,
    bool? showAltEmailOnPdf,
  }) async {
    // Explizit übergebene Werte (z. B. aus UserModel) haben Vorrang
    if (showLocationOnPdf != null && showPhoneOnPdf != null &&
        showEmailOnPdf != null && showAltEmailOnPdf != null) {
      return PdfDisplayOptions(
        showLocationOnPdf: showLocationOnPdf,
        showPhoneOnPdf: showPhoneOnPdf,
        showEmailOnPdf: showEmailOnPdf,
        showAltEmailOnPdf: showAltEmailOnPdf,
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return PdfDisplayOptions(
        showLocationOnPdf: prefs.getBool(_key(uid, 'location')) ?? false,
        showPhoneOnPdf: prefs.getBool(_key(uid, 'phone')) ?? false,
        showEmailOnPdf: prefs.getBool(_key(uid, 'email')) ?? false,
        showAltEmailOnPdf: prefs.getBool(_key(uid, 'altEmail')) ?? false,
      );
    } catch (_) {
      return const PdfDisplayOptions(
        showLocationOnPdf: false,
        showPhoneOnPdf: false,
        showEmailOnPdf: false,
        showAltEmailOnPdf: false,
      );
    }
  }

  /// Aktualisiert die Optionen: sofort lokal, danach Firestore.
  Future<void> updateOptions({
    required String uid,
    bool? showLocationOnPdf,
    bool? showPhoneOnPdf,
    bool? showEmailOnPdf,
    bool? showAltEmailOnPdf,
  }) async {
    try {
      final current = await getOptions(uid);
      final updated = PdfDisplayOptions(
        showLocationOnPdf: showLocationOnPdf ?? current.showLocationOnPdf,
        showPhoneOnPdf: showPhoneOnPdf ?? current.showPhoneOnPdf,
        showEmailOnPdf: showEmailOnPdf ?? current.showEmailOnPdf,
        showAltEmailOnPdf: showAltEmailOnPdf ?? current.showAltEmailOnPdf,
      );

      // 1) Lokal sofort
      await _cacheToPrefs(
        uid: uid,
        showLocationOnPdf: updated.showLocationOnPdf,
        showPhoneOnPdf: updated.showPhoneOnPdf,
        showEmailOnPdf: updated.showEmailOnPdf,
        showAltEmailOnPdf: updated.showAltEmailOnPdf,
      );

      // 2) Firestore
      final data = <String, dynamic>{
        'showLocationOnPdf': updated.showLocationOnPdf,
        'showPhoneOnPdf': updated.showPhoneOnPdf,
        'showEmailOnPdf': updated.showEmailOnPdf,
        'showAltEmailOnPdf': updated.showAltEmailOnPdf,
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      // Lokaler Update ist bereits erfolgt; Firestore-Fehler ignorieren oder loggen
    }
  }
}

/// Unveränderliches Objekt mit den vier PDF-Anzeige-Optionen.
class PdfDisplayOptions {
  final bool showLocationOnPdf;
  final bool showPhoneOnPdf;
  final bool showEmailOnPdf;
  final bool showAltEmailOnPdf;

  const PdfDisplayOptions({
    this.showLocationOnPdf = false,
    this.showPhoneOnPdf = false,
    this.showEmailOnPdf = false,
    this.showAltEmailOnPdf = false,
  });
}
