/// Globaler Debug-Schalter für detaillierte Konsolen-Ausgaben.
/// Wird ausschließlich per URL-Parameter aktiviert (z. B. ?x=99).
/// Im Normalbetrieb bleibt [isDebugEnabled] false.
class DebugConfig {
  DebugConfig._();

  static bool isDebugEnabled = false;
}
