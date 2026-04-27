import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/pro_feature_guard.dart';
import '../../../services/subscription_sync_service.dart';
import '../../../utils/password_strength_utils.dart';
import '../../../utils/ui_constants.dart';
import '../../../widgets/password_strength_bar.dart';
import '../../../utils/debug_log.dart';

/// Dialog zum Ändern des Passworts. Controller werden lokal erstellt und nach Schließen disposed.
class ChangePasswordDialog {
  ChangePasswordDialog._();

  static Widget _buildVibesDialog({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          gradient: UIConstants.colorGreyGradient,
          border: Border.all(color: UIConstants.appOrange, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              content,
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          ),
        ),
      ),
    );
  }

  static InputDecoration _fieldDecoration({
    required String labelText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: UIConstants.appOrange),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: UIConstants.appOrange.withValues(alpha: 0.72),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: UIConstants.appOrange, width: 2),
      ),
      filled: true,
      fillColor: Colors.black,
      suffixIcon: suffixIcon,
    );
  }

  static String? _validatePassword(BuildContext context, String? value) {
    return PasswordStrengthUtils.validateForApp(
      l10n: AppLocalizations.of(context)!,
      value: value,
    );
  }

  /// Zeigt den Passwort-ändern-Dialog. Controller werden nach Schließen im PostFrameCallback disposed.
  static Future<void> show(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final localizations = AppLocalizations.of(context)!;
    final formKey = GlobalKey<FormState>();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _buildVibesDialog(
          title: localizations.change_password,
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: newPasswordController,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: _fieldDecoration(
                      labelText:
                          localizations.new_password,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.help_outline, size: 20),
                            tooltip:
                                localizations.password_requirements,
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => _buildVibesDialog(
                                  title:
                                      localizations.password_requirements,
                                  content: Text(
                                    '${localizations.password_must}\n'
                                    '• ${localizations.password_min_length}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(
                                          ctx,
                                          rootNavigator: true,
                                        ).pop();
                                        return;
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: UIConstants.appOrange,
                                      ),
                                      child: Text(localizations.ok),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              showNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                showNewPassword = !showNewPassword;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    obscureText: !showNewPassword,
                    validator: (value) => _validatePassword(context, value),
                  ),
                  const SizedBox(height: 8),
                  PasswordStrengthBar(password: newPasswordController.text),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    decoration: _fieldDecoration(
                      labelText:
                          localizations.confirm_new_password,
                      suffixIcon: IconButton(
                        icon: Icon(
                          showConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            showConfirmPassword = !showConfirmPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: !showConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations.password_confirm_required;
                      }
                      if (value != newPasswordController.text) {
                        return localizations.passwords_dont_match;
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context, rootNavigator: true).pop();
                return;
              },
              style: TextButton.styleFrom(
                foregroundColor: UIConstants.appOrange,
              ),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newPassword = newPasswordController.text;
                if (newPassword.length <
                    PasswordStrengthUtils.minPasswordLength) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          localizations.password_too_short,
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                  return;
                }
                try {
                  final currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            localizations.error_changing_password,
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      Navigator.of(context, rootNavigator: true).pop();
                    }
                    return;
                  }
                  final passwordToSet = newPasswordController.text;
                  debugLog(
                    '🔐 Passwort-Änderung: rufe currentUser.updatePassword auf...',
                  );
                  await currentUser.updatePassword(passwordToSet);
                  await currentUser.reload();
                  debugLog(
                    '🔐 Passwort-Änderung: updatePassword und reload erfolgreich.',
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          localizations.password_changed,
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  if (e is FirebaseAuthException) {
                    debugLog(
                      '🔥 Firebase Auth Fehler: ${e.code} - ${e.message}',
                    );
                  } else {
                    debugLog('🔐 Passwort-Änderung Fehler: $e');
                  }
                  if (!context.mounted) return;
                  if (e.toString().contains('requires-recent-login')) {
                    await showDialog<void>(
                      context: context,
                      builder: (dialogContext) => _buildVibesDialog(
                        title:
                            localizations.change_password,
                        content: Text(
                          localizations.recent_login_required,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              Navigator.of(
                                dialogContext,
                                rootNavigator: true,
                              ).pop();
                              if (context.mounted) {
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop();
                              }
                              await SubscriptionSyncService.logOut();
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool(
                                'show_security_relogin_snackbar',
                                true,
                              );
                              ProFeatureGuard.invalidateCache();
                              await FirebaseAuth.instance.signOut();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: UIConstants.appOrange,
                            ),
                            child: Text(localizations.ok),
                          ),
                        ],
                      ),
                    );
                    return;
                  }
                  String errorMessage =
                      localizations.error_changing_password;
                  if (e.toString().contains('weak-password')) {
                    errorMessage =
                        localizations.password_too_weak;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: UIConstants.appOrange,
              ),
              child: Text(localizations.change_password),
            ),
          ],
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    });
  }
}
