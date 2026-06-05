import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// DJ-Einstellung: Ergebnisse pro Seite unter users/{uid}/settings/results_per_page.
/// Gilt für DJ-App und PWA-Gäste. Fallback beim Laden: party_settings/current, dann 20.
class ResultsPerPageService {
  static const int minResultsPerPage = 10;
  static const int maxResultsPerPage = 150;
  static const int stepResultsPerPage = 10;
  static const int defaultResultsPerPage = 20;

  static final List<int> allowedValues = List.generate(
    ((maxResultsPerPage - minResultsPerPage) ~/ stepResultsPerPage) + 1,
    (i) => minResultsPerPage + i * stepResultsPerPage,
  );

  static int? _cached;

  static int get current => _cached ?? defaultResultsPerPage;

  static int? parseValue(dynamic v) {
    if (v is int && allowedValues.contains(v)) return v;
    return null;
  }

  static int? _parseResultsPerPage(dynamic v) => parseValue(v);

  static Future<int> load() async {
    if (_cached != null) return _cached!;

    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      _cached = defaultResultsPerPage;
      return _cached!;
    }

    try {
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
      // Bei Fehlern: Standardwert
    }

    _cached = defaultResultsPerPage;
    return _cached!;
  }

  static Future<void> save(int value) async {
    if (parseValue(value) == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
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
