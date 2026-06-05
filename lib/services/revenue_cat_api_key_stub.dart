import '../config/app_config.dart';

/// Web / kein `dart:io`: RevenueCat wird ohnehin nicht konfiguriert ([kIsWeb] in Bootstrap).
String resolveRevenueCatApiKey() => AppConfig.revenueCatApiKeyAndroid;
