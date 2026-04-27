import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../utils/ui_constants.dart';

/// Ergebnis der E-Mail-Verifizierung (Deep-Link oder manueller Code): VibesBox-Look — grauer Verlauf,
/// orangefarbener Rahmen [#FF8C00], Logo oben, Status grün/rot, darunter Anweisungstext.
class EmailVerificationResultDialog extends StatelessWidget {
  const EmailVerificationResultDialog({
    super.key,
    required this.isSuccess,
    required this.statusText,
    required this.instructionText,
    required this.okLabel,
    required this.onDismiss,
  });

  final bool isSuccess;
  final String statusText;
  final String instructionText;
  final String okLabel;
  final VoidCallback onDismiss;

  static const String logoAsset = 'assets/icon/vibesbox-logo.png';

  @override
  Widget build(BuildContext context) {
    final statusColor = isSuccess
        ? UIConstants.verifyStatusSuccessGreen
        : UIConstants.verifyStatusErrorRed;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: UIConstants.verificationDialogBoxDecoration,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              logoAsset,
              height: 72,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  AppAssets.placeholder(height: 72),
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              instructionText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                height: 1.35,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onDismiss,
              style: FilledButton.styleFrom(
                backgroundColor: UIConstants.vibesBoxVerificationBorderOrange,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text(
                okLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
