import '../helpers/security_helper.dart';

// Sanitization-Funktion: Entfernt potenziell gefährliche Zeichen und HTML-Tags
String sanitizeInput(String input) {
  return SecurityHelper.sanitize(input);
}

// Sanitization-Funktion speziell für Email-Adressen
// Entfernt HTML/JavaScript, behält aber Email-Format bei
String sanitizeEmail(String email) {
  return SecurityHelper.sanitize(email);
}
