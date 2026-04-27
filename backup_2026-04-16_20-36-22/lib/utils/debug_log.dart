import 'package:flutter/foundation.dart';

/// Nur in [kDebugMode]: Ausgabe über [debugPrint]. Release-Builds bleiben stumm.
void debugLog(Object? message) {
  if (kDebugMode) {
    debugPrint('$message');
  }
}
