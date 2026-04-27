import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/app_config.dart';
import '../utils/debug_log.dart';

/// Startet [Purchases.configure] kurz verzögert und koppelt alle SDK-Aufrufe daran,
/// damit der Main-Thread beim Cold-Start weniger blockiert.
class RevenueCatBootstrap {
  RevenueCatBootstrap._();

  static Future<void>? _configureFuture;

  /// Wartet auf abgeschlossenes SDK-[configure] (nach kurzer Startverzögerung).
  static Future<void> ensureConfigured() async {
    if (kIsWeb) return;
    _configureFuture ??= _configure();
    await _configureFuture!;
  }

  static Future<void> _configure() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.error);
      }
      await Purchases.configure(
        PurchasesConfiguration(AppConfig.revenueCatApiKey),
      );
      debugLog('💳 RevenueCat initialisiert');
    } catch (e) {
      debugLog('💳 RevenueCat Initialisierung fehlgeschlagen: $e');
    }
  }
}
