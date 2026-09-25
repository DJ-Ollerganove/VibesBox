import 'package:flutter/foundation.dart';

/// DJ-VibesBox: eine Instanz, Vollbild-Overlay über der App (ohne zweite Firestore-Listener).
class VibesboxFullscreenService {
  VibesboxFullscreenService._();

  static final VibesboxFullscreenService instance = VibesboxFullscreenService._();

  final ValueNotifier<bool> isFullscreen = ValueNotifier(false);

  void enter() {
    if (isFullscreen.value) return;
    isFullscreen.value = true;
  }

  void exit() {
    if (!isFullscreen.value) return;
    isFullscreen.value = false;
  }

  void toggle() {
    isFullscreen.value = !isFullscreen.value;
  }
}
