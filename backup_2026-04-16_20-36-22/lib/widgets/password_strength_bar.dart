import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/password_strength_utils.dart';
import '../utils/ui_constants.dart';

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({
    super.key,
    required this.password,
  });

  final String password;

  Color _colorForLevel(PasswordStrengthLevel level) {
    switch (level) {
      case PasswordStrengthLevel.weak:
        return UIConstants.appRed;
      case PasswordStrengthLevel.medium:
        return UIConstants.colorYellow;
      case PasswordStrengthLevel.strong:
        return UIConstants.appGreen;
      case PasswordStrengthLevel.veryStrong:
        return UIConstants.appGreenSuccess;
    }
  }

  String _labelForLevel(AppLocalizations l, PasswordStrengthLevel level) {
    switch (level) {
      case PasswordStrengthLevel.weak:
        return l.password_strength_weak;
      case PasswordStrengthLevel.medium:
        return l.password_strength_medium;
      case PasswordStrengthLevel.strong:
        return l.password_strength_strong;
      case PasswordStrengthLevel.veryStrong:
        return l.password_strength_very_strong;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final result = PasswordStrengthUtils.evaluate(password);
    final activeColor = _colorForLevel(result.level);
    final levelLabel = _labelForLevel(l, result.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: List.generate(PasswordStrengthUtils.maxSegments, (
                  index,
                ) {
                  final active = index < result.filledSegments;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        right: index == PasswordStrengthUtils.maxSegments - 1
                            ? 0
                            : 6,
                      ),
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? activeColor
                            : Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              levelLabel,
              style: TextStyle(
                color: activeColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          l.password_info_hint,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
