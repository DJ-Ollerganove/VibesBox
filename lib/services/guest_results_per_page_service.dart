import 'package:shared_preferences/shared_preferences.dart';

import '../utils/debug_log.dart';
import 'results_per_page_service.dart';

/// Gast-App: Ergebnisse pro Seite — nur lokal (SharedPreferences), nicht Firestore.
class GuestResultsPerPageService {
  GuestResultsPerPageService._();

  static const String _prefKey = 'guest_results_per_page_v1';
  static const int defaultResultsPerPage = 20;

  static List<int> get allowedValues => ResultsPerPageService.allowedValues;

  static int? _cached;

  static int get current => _cached ?? defaultResultsPerPage;

  static int? parseValue(dynamic v) => ResultsPerPageService.parseValue(v);

  static Future<int> load() async {
    if (_cached != null) return _cached!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getInt(_prefKey);
      final parsed = raw != null ? parseValue(raw) : null;
      _cached = parsed ?? defaultResultsPerPage;
    } catch (e) {
      debugLog('⚠️ GuestResultsPerPageService.load: $e');
      _cached = defaultResultsPerPage;
    }
    return _cached!;
  }

  static Future<void> save(int value) async {
    if (parseValue(value) == null) return;
    _cached = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, value);
    } catch (e) {
      debugLog('⚠️ GuestResultsPerPageService.save: $e');
      rethrow;
    }
  }
}
