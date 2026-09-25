import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_email_service.dart';
import '../utils/debug_log.dart';
import '../utils/sanitize.dart';
import '../utils/ui_constants.dart';
import 'common/pwa_widget_cell.dart';
import 'vibesbox_info_dialog.dart';
import '../app_scaffold_messenger.dart';

/// Dialog zum Anfordern einer Passwort-Reset-E-Mail (Login, nicht eingeloggt).
class ForgotPasswordDialog {
  ForgotPasswordDialog._();

  static bool _isLikelyFirebaseEmail(String email) {
    final sanitized = sanitizeEmail(email).trim();
    if (sanitized.isEmpty) return false;
    final basicPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    final asciiOnly = RegExp(r'^[\x00-\x7F]+$');
    return basicPattern.hasMatch(sanitized) && asciiOnly.hasMatch(sanitized);
  }

  static Future<void> show(
    BuildContext context, {
    String initialEmail = '',
  }) async {
    final parentContext = context;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (dialogContext) => _ForgotPasswordDialogContent(
        initialEmail: initialEmail,
        parentContext: parentContext,
      ),
    );
  }
}

class _ForgotPasswordDialogContent extends StatefulWidget {
  const _ForgotPasswordDialogContent({
    required this.initialEmail,
    required this.parentContext,
  });

  final String initialEmail;
  final BuildContext parentContext;

  @override
  State<_ForgotPasswordDialogContent> createState() =>
      _ForgotPasswordDialogContentState();
}

class _ForgotPasswordDialogContentState
    extends State<_ForgotPasswordDialogContent> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;
  bool _sendPressed = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  InputDecoration _emailDecoration(AppLocalizations l) {
    const orange = UIConstants.appOrange;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: orange, width: 1.5),
    );
    return InputDecoration(
      labelText: l.login_email_label,
      labelStyle: const TextStyle(color: orange),
      floatingLabelStyle: const TextStyle(color: orange),
      prefixIcon: const Icon(Icons.email_outlined, color: orange),
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: orange, width: 2),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSending = true);

    final email = sanitizeEmail(_emailController.text.trim());
    final l = AppLocalizations.of(context)!;

    try {
      await AuthEmailService.sendPasswordResetEmail(l: l, email: email);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (!widget.parentContext.mounted) return;
      await showVibesBoxInfoDialog(
        widget.parentContext,
        title: l.login_reset_sent_dialog_title,
        body: l.login_reset_sent_dialog_body(email),
      );
    } on FirebaseFunctionsException catch (e) {
      debugLog('❌ Reset-Email (Callable): ${e.code} ${e.message}');
      if (!mounted) return;
      final msg = e.code == 'resource-exhausted'
          ? l.error_too_many_requests
          : '${l.error}: ${e.message ?? e.code}';
      showVibesSnackBar(context, 
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      debugLog('❌ Fehler beim Senden der Reset-Email: $e');
      if (!mounted) return;
      showVibesSnackBar(context, 
        SnackBar(
          content: Text('${l.error}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _sendPressed = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: PwaWidgetCell(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.login_reset_dialog_title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l.login_reset_dialog_intro,
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: _emailDecoration(l),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return l.login_reset_email_required;
                    }
                    if (!ForgotPasswordDialog._isLikelyFirebaseEmail(trimmed)) {
                      return l.login_email_invalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isSending
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(l.cancel),
                    ),
                    const Spacer(),
                    _PressableOrangeButton(
                      label: l.login_reset_dialog_send,
                      isLoading: _isSending,
                      isPressed: _sendPressed,
                      onPressed: _isSending ? null : _submit,
                      onPressDown: () {
                        if (_isSending) return;
                        HapticFeedback.selectionClick();
                        setState(() => _sendPressed = true);
                      },
                      onPressUp: () {
                        if (_sendPressed) {
                          setState(() => _sendPressed = false);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PressableOrangeButton extends StatelessWidget {
  const _PressableOrangeButton({
    required this.label,
    required this.isLoading,
    required this.isPressed,
    required this.onPressed,
    required this.onPressDown,
    required this.onPressUp,
  });

  final String label;
  final bool isLoading;
  final bool isPressed;
  final VoidCallback? onPressed;
  final VoidCallback onPressDown;
  final VoidCallback onPressUp;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final scale = isPressed && enabled ? 0.96 : 1.0;
    final opacity = isPressed && enabled ? 0.88 : 1.0;

    return GestureDetector(
      onTapDown: enabled ? (_) => onPressDown() : null,
      onTapUp: enabled ? (_) => onPressUp() : null,
      onTapCancel: enabled ? onPressUp : null,
      onTap: enabled ? onPressed : null,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 80),
          child: FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: UIConstants.appOrange,
              foregroundColor: Colors.black,
              disabledBackgroundColor:
                  UIConstants.appOrange.withValues(alpha: 0.55),
              disabledForegroundColor: Colors.black54,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
