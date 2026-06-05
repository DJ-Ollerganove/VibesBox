import 'dart:io' show Platform;

import '../config/app_config.dart';

/// RevenueCat: iOS → Apple-API-Key (`appl_…`), Android → Google-Play-Key (`goog_…`).
/// Andere `dart:io`-Plattformen: gleicher Fallback wie bisher (Google-Key).
String resolveRevenueCatApiKey() {
  if (Platform.isIOS) {
    return AppConfig.revenueCatApiKeyIos;
  }
  if (Platform.isAndroid) {
    return AppConfig.revenueCatApiKeyAndroid;
  }
  return AppConfig.revenueCatApiKeyAndroid;
}
