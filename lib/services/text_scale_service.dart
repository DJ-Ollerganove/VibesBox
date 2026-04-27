import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/debug_log.dart';

/// App-interne Schriftstufen (zusätzlich zur System-Skalierung, die in [DJOgApp] gedeckelt wird).
class TextScaleService {
  TextScaleService._();
  static final TextScaleService instance = TextScaleService._();

  static const String _prefKey = 'user_text_scale_v1';
  static const List<double> allowedSteps = [0.8, 0.9, 1.0, 1.1, 1.2];

  final ValueNotifier<double> userFactor = ValueNotifier<double>(1.0);

  double get factor => userFactor.value;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getDouble(_prefKey);
      final v = raw ?? 1.0;
      userFactor.value = _nearestAllowed(v);
    } catch (e) {
      debugLog('⚠️ TextScaleService.load: $e');
      userFactor.value = 1.0;
    }
  }

  Future<void> setFactor(double value) async {
    final v = _nearestAllowed(value);
    userFactor.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefKey, v);
    } catch (e) {
      debugLog('⚠️ TextScaleService.setFactor: $e');
    }
  }

  /// Slider-Index 0…3 → Faktor
  static double factorFromStepIndex(int index) {
    final i = index.clamp(0, allowedSteps.length - 1);
    return allowedSteps[i];
  }

  static int stepIndexFromFactor(double factor) {
    var best = 0;
    var bestDiff = double.infinity;
    for (var i = 0; i < allowedSteps.length; i++) {
      final d = (allowedSteps[i] - factor).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = i;
      }
    }
    return best;
  }

  static double _nearestAllowed(double v) {
    if (allowedSteps.contains(v)) return v;
    var best = allowedSteps[0];
    var bestDiff = double.infinity;
    for (final s in allowedSteps) {
      final d = (s - v).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = s;
      }
    }
    return best;
  }
}
