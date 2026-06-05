import 'package:flutter/foundation.dart';

import 'navigation_service.dart';

/// Navigation von DJ-Startseiten-Widgets zu Haupttabs / VibesBox-Untertabs.
class DjWishNotificationNavigator {
  DjWishNotificationNavigator._();
  static final DjWishNotificationNavigator instance =
      DjWishNotificationNavigator._();

  /// [DjVibesBoxPage] sitzt bei DJ/Admin-Shell an Index 2 (Home=0, Party=1, …).
  static const int djVibesBoxMainTabIndex = 2;

  /// [HistoryPage] bei DJ/Admin-Shell an Index 4.
  static const int djHistoryTabIndex = 4;

  /// [DjVibesBoxPage] lauscht darauf und springt auf Tab „Offen“.
  final ValueNotifier<int> openOffenSignal = ValueNotifier<int>(0);

  /// [DjVibesBoxPage] lauscht darauf und springt auf Tab „Vorab“.
  final ValueNotifier<int> openVorabSignal = ValueNotifier<int>(0);

  void navigateToOpenWishesTab() {
    NavigationService().setTabIndex(djVibesBoxMainTabIndex, force: true);
    openOffenSignal.value++;
  }

  void navigateToVorabTab() {
    NavigationService().setTabIndex(djVibesBoxMainTabIndex, force: true);
    openVorabSignal.value++;
  }

  void navigateToHistoryTab() {
    NavigationService().setTabIndex(djHistoryTabIndex, force: true);
  }
}
