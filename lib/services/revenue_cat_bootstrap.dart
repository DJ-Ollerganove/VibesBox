import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;
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
      // Debug: StoreKit-/Product-Fehler sichtbar (LogLevel.error versteckt die Ursache).
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.debug);
      }
      final apiKey = revenue_cat_api_key.resolveRevenueCatApiKey();
      final config = PurchasesConfiguration(apiKey);
      // StoreKit 2 ohne In-App-Purchase-Key in RC liefert oft leere Packages.
      // StoreKit 1 ist auf physischen Geräten/TestFlight robuster.
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        config.storeKitVersion = StoreKitVersion.storeKit1;
      }
      await Purchases.configure(config);
      final keyKind = apiKey.startsWith('appl_')
          ? 'appl'
          : apiKey.startsWith('goog_')
              ? 'goog'
              : 'other';
      debugLog('💳 RevenueCat initialisiert (key=$keyKind)');
    } catch (e) {
      // Nicht rethrowen: Main startet configure unawaited; Paywall sieht Folgefehler.
      debugLog('💳 RevenueCat Initialisierung fehlgeschlagen: $e');
    }
  }
}
