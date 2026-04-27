import '../l10n/app_localizations.dart';

enum PasswordStrengthLevel { weak, medium, strong, veryStrong }

class PasswordStrengthResult {
  const PasswordStrengthResult({
    required this.level,
    required this.filledSegments,
    required this.isValidByPolicy,
  });

  final PasswordStrengthLevel level;
  final int filledSegments;
  final bool isValidByPolicy;
}

class PasswordStrengthUtils {
  PasswordStrengthUtils._();

  static const int minPasswordLength = 8;
  static const int maxSegments = 4;

  static String? validateForApp({
    required AppLocalizations l10n,
    required String? value,
  }) {
    if (value == null || value.isEmpty) {
      return l10n.password_required;
    }
    if (value.length < minPasswordLength) {
      return l10n.password_too_short;
    }
    return null;
  }

  static PasswordStrengthResult evaluate(String password) {
    if (password.isEmpty) {
      return const PasswordStrengthResult(
        level: PasswordStrengthLevel.weak,
        filledSegments: 0,
        isValidByPolicy: false,
      );
    }

    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasAsciiSpecial = password.contains(RegExp(r'[^\w\s]', unicode: true));
    final hasUtf8Extended = password.contains(RegExp(r'[^\x00-\x7F]'));

    var score = 0;
    if (password.length >= minPasswordLength) score++;
    if (password.length >= 12) score++;
    if (password.length >= 16) score++;
    if (hasLower) score++;
    if (hasUpper) score++;
    if (hasDigit) score++;
    if (hasAsciiSpecial) score++;
    if (hasUtf8Extended) score++;

    var filled = 1;
    var level = PasswordStrengthLevel.weak;

    if (score >= 3) {
      filled = 2;
      level = PasswordStrengthLevel.medium;
    }
    if (score >= 5) {
      filled = 3;
      level = PasswordStrengthLevel.strong;
    }
    if (score >= 7) {
      filled = 4;
      level = PasswordStrengthLevel.veryStrong;
    }

    // Konsistenz: unter Mindestlänge nie als "stark/grün" anzeigen.
    if (password.length < minPasswordLength) {
      filled = 1;
      level = PasswordStrengthLevel.weak;
    }

    return PasswordStrengthResult(
      level: level,
      filledSegments: filled.clamp(0, maxSegments),
      isValidByPolicy: password.length >= minPasswordLength,
    );
  }
}
