import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../utils/ui_constants.dart';
import 'email_verification_result_dialog.dart';
import '../utils/debug_log.dart';

/// Nach Registrierung von [LoginPage]: VibesBox-Look ([UIConstants.verificationDialogBoxDecoration]),
/// Logo, manueller oobCode ([UIConstants.verificationOobCodeInputDecoration]),
/// Erfolg/Fehler wie Deep-Link über [EmailVerificationResultDialog].
class EmailVerificationDialog extends StatefulWidget {
  const EmailVerificationDialog({
    super.key,
    required this.email,
  });

  final String email;

  static const String logoAsset = 'assets/icon/vibesbox-logo.png';

  @override
  State<EmailVerificationDialog> createState() =>
      _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog> {
  final _manualCodeController = TextEditingController();
  bool _busy = false;
  bool _manualSuccess = false;

  @override
  void dispose() {
    _manualCodeController.dispose();
    super.dispose();
  }

  Future<void> _applyManualCode() async {
    final raw = _manualCodeController.text;
    final oob = AuthService.extractOobCodeFromInput(raw);
    if (oob == null || oob.isEmpty) {
      final l = AppLocalizations.of(context)!;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => EmailVerificationResultDialog(
          isSuccess: false,
          statusText: l.verify_error_title,
          instructionText: l.verify_error_instruction_login,
          okLabel: l.ok,
          onDismiss: () => Navigator.of(ctx).pop(),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService.applyEmailVerificationCode(oob);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _manualSuccess = true;
      });
    } on FirebaseAuthException catch (e, st) {
      debugLog('Manuelle Verifizierung: $e\n$st');
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => EmailVerificationResultDialog(
          isSuccess: false,
          statusText: l.verify_error_title,
          instructionText: l.verify_error_instruction_login,
          okLabel: l.ok,
          onDismiss: () => Navigator.of(ctx).pop(),
        ),
      );
    } catch (e, st) {
      debugLog('Manuelle Verifizierung: $e\n$st');
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => EmailVerificationResultDialog(
          isSuccess: false,
          statusText: l.verify_error_title,
          instructionText: l.verify_error_instruction_login,
          okLabel: l.ok,
          onDismiss: () => Navigator.of(ctx).pop(),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_manualSuccess) {
      return EmailVerificationResultDialog(
        isSuccess: true,
        statusText: l.verify_success_title,
        instructionText: l.verify_success_instruction,
        okLabel: l.ok,
        onDismiss: () => Navigator.of(context).pop(),
      );
    }

    final title = l.verify_email_title;
    final body = l.verify_email_message_for(widget.email);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: UIConstants.verificationDialogBoxDecoration,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                EmailVerificationDialog.logoAsset,
                height: 72,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) =>
                    AppAssets.placeholder(height: 72),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.35,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.manual_code_hint,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _manualCodeController,
                enabled: !_busy,
                style: const TextStyle(color: Colors.white),
                decoration: UIConstants.verificationOobCodeInputDecoration(
                  hintText: l.manual_code_hint,
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _applyManualCode,
                style: FilledButton.styleFrom(
                  backgroundColor: UIConstants.vibesBoxVerificationBorderOrange,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        l.verify_manual_check,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          if (context.mounted) Navigator.of(context).pop();
                          return;
                        }
                        try {
                          await user.reload();
                        } catch (_) {}
                        if (!context.mounted) return;
                        if (FirebaseAuth.instance.currentUser?.emailVerified ==
                            true) {
                          Navigator.of(context).pop();
                        } else {
                          final msg = l.verify_email_still_pending;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(msg),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: UIConstants.vibesBoxVerificationBorderOrange
                      .withValues(alpha: 0.85),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(
                  l.verify_email_check,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: Text(
                  l.ok,
                  style: const TextStyle(
                    color: UIConstants.vibesBoxVerificationBorderOrange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
