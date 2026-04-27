import 'package:flutter/foundation.dart';

/// Während [isRegistering] true ist, soll [MainPage] auf Auth-Events nicht sofort
/// Tab wechseln / Cold-Start ausführen (Race mit Registrierung + Verifizierungs-Mail).
class RegistrationFlowGuard {
  RegistrationFlowGuard._();

  static final ValueNotifier<bool> isRegistering = ValueNotifier<bool>(false);

  static void begin() {
    isRegistering.value = true;
  }

  static void end() {
    isRegistering.value = false;
  }
}
