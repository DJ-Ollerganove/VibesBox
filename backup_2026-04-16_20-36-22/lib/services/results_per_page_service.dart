import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lädt und speichert "Ergebnisse pro Seite" benutzerbezogen unter users/{uid}/settings/results_per_page.
/// Fallback beim Laden: party_settings/current, danach Standardwert 10.
class ResultsPerPageService {
  static const int defaultResultsPerPage = 10;
  static const List<int> allowedValues = [5, 10, 15, 20, 25, 30];

  static int? _cached;

  /// Gibt den gecachten Wert zurück (nach erstem Aufruf von [load] oder [save]).
  static int get current => _cached ?? defaultResultsPerPage;

  static int? _parseResultsPerPage(dynamic v) {
    if (v is int && allowedValues.contains(v)) return v;
    return null;
  }

  /// Lädt results_per_page aus Firestore (zuerst users/{uid}/settings, Fallback party_settings/current).
  static Future<int> load() async {
    if (_cached != null) return _cached!;

    final uid = FirebaseAuth.instance.currentUser?.uid;

    // Kein User eingeloggt -> Standardwert
    if (uid == null || uid.isEmpty) {
      _cached = defaultResultsPerPage;
      return _cached!;
    }

    try {
      // 1. Versuch: users/{uid}/settings/results_per_page
      final userSettingsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('results_per_page');

      final userDoc = await userSettingsRef.get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final v = _parseResultsPerPage(data?['results_per_page']);
        if (v != null) {
          _cached = v;
          return _cached!;
        }
      }

      // 2. Fallback: party_settings/current (einmalig)
      final globalDoc = await FirebaseFirestore.instance
          .collection('party_settings')
          .doc('current')
          .get();

      if (globalDoc.exists) {
        final data = globalDoc.data();
        final v = _parseResultsPerPage(data?['results_per_page']);
        if (v != null) {
          _cached = v;
          return _cached!;
        }
      }
    } catch (_) {
      // Bei Fehlern: Standardwert verwenden
    }

    _cached = defaultResultsPerPage;
    return _cached!;
  }

  /// Speichert den Wert in users/{uid}/settings/results_per_page (nur bei eingeloggtem User).
  static Future<void> save(int value) async {
    if (!allowedValues.contains(value)) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      // Kein User eingeloggt – kein Schreibvorgang, Cache nicht ändern
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('results_per_page')
          .set({'results_per_page': value}, SetOptions(merge: true));
      _cached = value;
    } catch (_) {
      rethrow;
    }
  }
}
