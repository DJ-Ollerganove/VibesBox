import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../utils/debug_log.dart';
import 'revenue_cat_api_key_stub.dart'
    if (dart.library.io) 'revenue_cat_api_key_io.dart' as revenue_cat_api_key;

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
      final apiKey = revenue_cat_api_key.resolveRevenueCatApiKey();
      await Purchases.configure(
        PurchasesConfiguration(apiKey),
      );
      debugLog('💳 RevenueCat initialisiert');
    } catch (e) {
      debugLog('💳 RevenueCat Initialisierung fehlgeschlagen: $e');
    }
  }
}
