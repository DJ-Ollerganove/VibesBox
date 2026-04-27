import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../helpers/security_helper.dart';
import '../../../utils/sanitize.dart' show sanitizeInput, sanitizeEmail;
import '../../../utils/ui_constants.dart';
import '../../../utils/debug_log.dart';
/// Zentrale Klasse für die Profil-Bearbeiten-Dialoge (Daten, Name, E-Mail).
/// Controller werden von der ProfilPage übergeben; Callbacks für UI-Updates (z. B. onSaved).
class ProfileEditDialogs {
  ProfileEditDialogs._();

  static bool _isNameBlocked(String name) {
    final normalizedName = name.trim().toUpperCase();
    final blockedNames = ['DJ', 'OLLERGANOVE', 'GANOVE', 'OLLER', 'ADMIN'];
    if (blockedNames.contains(normalizedName)) return true;
    final inappropriateWords = [
      'FUCK',
      'SHIT',
      'ASS',
      'BITCH',
      'DAMN',
      'HELL',
      'CUNT',
      'SLUT',
      'WHORE',
      'BASTARD',
      'DICK',
    ];
    for (final word in inappropriateWords) {
      if (normalizedName.contains(word)) return true;
    }
    return false;
  }

  static bool _isLikelyFirebaseEmail(String email) {
    final candidate = sanitizeEmail(email).trim();
    if (candidate.isEmpty) {
      return false;
    }
    final basicPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    final asciiOnly = RegExp(r'^[\x00-\x7F]+$');
    return basicPattern.hasMatch(candidate) && asciiOnly.hasMatch(candidate);
  }

  static void _disposeControllerAfterFrame(TextEditingController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
  }

  /// Einheitlicher Dialog-Stil (oranger Rahmen, grauer Verlauf). Auch für andere Dialoge (z. B. Account löschen) nutzbar.
  static Widget styledDialog({
    required BuildContext context,
    required String title,
    required Widget content,
    List<Widget>? actions,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          gradient: UIConstants.colorGreyGradient,
          border: Border.all(color: UIConstants.appOrange, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              content,
              if (actions != null && actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Zeigt den Haupt-Dialog "Daten ändern" (Persönliche Daten / Passwort). Gibt 'personal', 'password' oder null zurück.
  static Future<String?> showMainEditDialog(
    BuildContext context,
    User user, {
    required bool isGuest,
  }) async {
    final localizations = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => styledDialog(
        context: context,
        title: localizations.profile_edit_data_title,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline, color: Colors.white70),
              title: Text(
                isGuest
                    ? (localizations.profile_guest_name_label)
                    : (localizations.profile_personal_data),
                style: TextStyle(color: Colors.grey[200]),
              ),
              onTap: () =>
                  Navigator.of(context, rootNavigator: true).pop('personal'),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: Colors.white70),
              title: Text(
                localizations.change_password,
                style: TextStyle(color: Colors.grey[200]),
              ),
              onTap: () =>
                  Navigator.of(context, rootNavigator: true).pop('password'),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: Colors.white70),
              title: Text(
                localizations.change_email,
                style: TextStyle(color: Colors.grey[200]),
              ),
              onTap: () =>
                  Navigator.of(context, rootNavigator: true).pop('email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              return;
            },
            child: Text(localizations.cancel),
          ),
        ],
      ),
    );
    return result;
  }

  static InputDecoration _personalFieldDecoration(
    BuildContext context,
    String labelText, {
    IconData icon = Icons.person_outline,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.grey[400]),
      prefixIcon: Icon(icon, color: Colors.white54),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: UIConstants.appOrange),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: UIConstants.appOrange.withValues(alpha: 0.7)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: UIConstants.appOrange, width: 2),
      ),
      filled: true,
      fillColor: Colors.black,
    );
  }

  /// Zeigt den Dialog "Persönliche Daten" (DJ Name, Echter Name, Telefon). Controller und onSaved werden übergeben.
  static Future<void> showPersonalDataDialog(
    BuildContext context,
    User user, {
    required bool isGuest,
    required TextEditingController djNameController,
    required TextEditingController realNameController,
    required TextEditingController phoneController,
    VoidCallback? onSaved,
  }) async {
    if (!context.mounted) return;
    final localizations = AppLocalizations.of(context)!;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() as Map<String, dynamic>? ?? {};
    djNameController.text =
        user.displayName ?? data['displayName'] as String? ?? '';
    realNameController.text = data['realName'] as String? ?? '';
    phoneController.text = data['phoneNumber'] as String? ?? '';
    final formKey = GlobalKey<FormState>();
    if (!context.mounted) return;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (!didPop) {
            FocusManager.instance.primaryFocus?.unfocus();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (dialogContext.mounted)
                Navigator.of(dialogContext, rootNavigator: true).pop(false);
            });
          }
        },
        child: styledDialog(
          context: context,
          title: isGuest
              ? (localizations.profile_guest_name_title)
              : (localizations.profile_personal_data),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: djNameController,
                    maxLength: 50,
                    decoration: _personalFieldDecoration(
                      dialogContext,
                      isGuest
                          ? (localizations.profile_field_name)
                          : (localizations.dj_name_label),
                      icon: Icons.person_outline,
                    ),
                    style: const TextStyle(color: Colors.white),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return localizations.name_cannot_be_empty;
                      if (v.trim().length < 3)
                        return localizations.name_too_short;
                      if (_isNameBlocked(v))
                        return localizations.name_not_allowed;
                      return null;
                    },
                  ),
                  if (!isGuest) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: realNameController,
                      maxLength: 80,
                      decoration: _personalFieldDecoration(
                        dialogContext,
                        localizations.real_name_label,
                        icon: Icons.badge_outlined,
                      ),
                      style: const TextStyle(color: Colors.white),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneController,
                      maxLength: 40,
                      decoration: _personalFieldDecoration(
                        dialogContext,
                        localizations.phone_label,
                        icon: Icons.phone_outlined,
                      ),
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (dialogContext.mounted)
                    Navigator.of(dialogContext, rootNavigator: true).pop(false);
                });
              },
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (dialogContext.mounted)
                      Navigator.of(
                        dialogContext,
                        rootNavigator: true,
                      ).pop(true);
                  });
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: UIConstants.appOrange,
              ),
              child: Text(localizations.save),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || saved != true) return;
    final newDjName = SecurityHelper.sanitize(
      sanitizeInput(djNameController.text.trim()),
      maxLength: 50,
    );
    final newRealName = SecurityHelper.sanitize(
      realNameController.text.trim(),
      maxLength: 80,
    );
    final newPhone = SecurityHelper.sanitize(
      phoneController.text.trim(),
      maxLength: 40,
    );
    try {
      await user.updateDisplayName(newDjName);
      await user.reload();
      final updateData = <String, dynamic>{'displayName': newDjName};
      if (!isGuest) {
        updateData['realName'] = newRealName.isEmpty
            ? FieldValue.delete()
            : newRealName;
        updateData['phoneNumber'] = newPhone.isEmpty
            ? FieldValue.delete()
            : newPhone;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(SecurityHelper.sanitizeMap(updateData), SetOptions(merge: true));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.name_changed),
            backgroundColor: Colors.green,
          ),
        );
        onSaved?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.error_changing_name} $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Zeigt den Dialog "Name ändern". nameController und onSaved werden übergeben.
  static Future<void> showEditNameDialog(
    BuildContext context,
    User user, {
    required TextEditingController nameController,
    VoidCallback? onSaved,
  }) async {
    if (!context.mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final localizations = AppLocalizations.of(context)!;
    nameController.text = user.displayName ?? '';
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (!didPop) {
            FocusManager.instance.primaryFocus?.unfocus();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (dialogContext.mounted)
                Navigator.of(dialogContext, rootNavigator: true).pop(false);
            });
          }
        },
        child: AlertDialog(
          title: Text(localizations.change_name),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: nameController,
                maxLength: 50,
                decoration: InputDecoration(
                  labelText: localizations.new_name,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return localizations.name_cannot_be_empty;
                  }
                  if (value.trim().length < 3) {
                    return localizations.name_too_short;
                  }
                  if (_isNameBlocked(value)) {
                    return localizations.name_not_allowed;
                  }
                  return null;
                },
                autofocus: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusManager.instance.primaryFocus?.unfocus();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (dialogContext.mounted)
                    Navigator.of(dialogContext, rootNavigator: true).pop(false);
                });
              },
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (dialogContext.mounted)
                      Navigator.of(
                        dialogContext,
                        rootNavigator: true,
                      ).pop(true);
                  });
                }
              },
              child: Text(localizations.save),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;
    if (confirmed != true) return;
    final newName = SecurityHelper.sanitize(
      sanitizeInput(nameController.text.trim()),
      maxLength: 50,
    );
    final oldName = user.displayName ?? '';
    try {
      await user.updateDisplayName(newName);
      await user.reload();
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
              SecurityHelper.sanitizeMap({
                'displayName': newName,
                'email': user.email,
              }),
              SetOptions(merge: true),
            );
      } catch (e) {
        debugLog('Firestore users update fehlgeschlagen: $e');
      }
      if (oldName.isNotEmpty) {
        try {
          final wishesQuery = await FirebaseFirestore.instance
              .collection('wishes')
              .where('name', isEqualTo: oldName)
              .get();
          if (wishesQuery.docs.isNotEmpty) {
            final batch = FirebaseFirestore.instance.batch();
            for (final doc in wishesQuery.docs) {
              batch.update(
                doc.reference,
                SecurityHelper.sanitizeMap({'name': newName}),
              );
            }
            await batch.commit();
          }
        } catch (e) {
          debugLog('Wünsche-Update fehlgeschlagen: $e');
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.name_changed,
            ),
            backgroundColor: Colors.green,
          ),
        );
        onSaved?.call();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.error_changing_name} $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Zeigt den Dialog "E-Mail ändern". emailController und onSaved werden übergeben.
  static Future<void> showEditEmailDialog(
    BuildContext context,
    User user, {
    required TextEditingController emailController,
    VoidCallback? onSaved,
  }) async {
    if (!context.mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final localizations = AppLocalizations.of(context)!;
    if (user.email == null || user.email!.trim().isEmpty) return;

    final passwordController = TextEditingController();
    final confirmEmailController = TextEditingController();
    final reauthFormKey = GlobalKey<FormState>();
    final emailFormKey = GlobalKey<FormState>();

    TextButton compactActionButton({
      required BuildContext dialogContext,
      required String label,
      required VoidCallback onPressed,
    }) {
      return TextButton(
        onPressed: () {
          if (!dialogContext.mounted) return;
          onPressed();
        },
        style: TextButton.styleFrom(
          foregroundColor: UIConstants.appOrange,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label.toUpperCase()),
      );
    }

    try {
      final reauthConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => styledDialog(
          context: dialogContext,
          title: localizations.confirm_password,
          content: Form(
            key: reauthFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localizations.email_change_reauth_hint,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: _personalFieldDecoration(
                    dialogContext,
                    localizations.your_password,
                    icon: Icons.lock_outline,
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return localizations.password_cannot_be_empty;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            compactActionButton(
              dialogContext: dialogContext,
              label: localizations.cancel,
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(false),
            ),
            compactActionButton(
              dialogContext: dialogContext,
              label: localizations.confirm,
              onPressed: () {
                if (reauthFormKey.currentState?.validate() != true) return;
                Navigator.of(dialogContext, rootNavigator: true).pop(true);
              },
            ),
          ],
        ),
      );

      if (!context.mounted || reauthConfirmed != true) return;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: passwordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      if (!context.mounted) return;
      emailController.clear();
      confirmEmailController.clear();

      final newEmail = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => styledDialog(
          context: dialogContext,
          title: localizations.change_email,
          content: Form(
            key: emailFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  maxLength: 200,
                  autofocus: true,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _personalFieldDecoration(
                    dialogContext,
                    localizations.new_email_address,
                    icon: Icons.email_outlined,
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    final email = sanitizeEmail((value ?? '').trim());
                    if (email.isEmpty) {
                      return localizations.email_cannot_be_empty;
                    }
                    if (!_isLikelyFirebaseEmail(email)) {
                      return localizations.login_invalid_email;
                    }
                    if (email.toLowerCase() ==
                        (user.email ?? '').toLowerCase()) {
                      return localizations.email_already_current;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmEmailController,
                  maxLength: 200,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _personalFieldDecoration(
                    dialogContext,
                    localizations.profile_alternative_email_dialog_confirm,
                    icon: Icons.mark_email_read_outlined,
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    final repeated = sanitizeEmail((value ?? '').trim());
                    if (repeated.isEmpty) {
                      return localizations.email_cannot_be_empty;
                    }
                    if (!_isLikelyFirebaseEmail(repeated)) {
                      return localizations.login_invalid_email;
                    }
                    if (repeated !=
                        sanitizeEmail(emailController.text.trim())) {
                      return localizations
                          .profile_alternative_email_validation_mismatch;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            compactActionButton(
              dialogContext: dialogContext,
              label: localizations.cancel,
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(),
            ),
            compactActionButton(
              dialogContext: dialogContext,
              label: localizations.email_change_send_link,
              onPressed: () {
                if (emailFormKey.currentState?.validate() != true) return;
                Navigator.of(
                  dialogContext,
                  rootNavigator: true,
                ).pop(sanitizeEmail(emailController.text.trim()));
              },
            ),
          ],
        ),
      );

      if (!context.mounted || newEmail == null || newEmail.isEmpty) return;

      await user.verifyBeforeUpdateEmail(newEmail);
      final currentUserEmail = user.email ?? '';

      final requestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('email_changes')
          .doc();

      await requestRef.set(
        SecurityHelper.sanitizeMap({
          'old_email': currentUserEmail,
          'new_email': newEmail,
          'timestamp_request': FieldValue.serverTimestamp(),
          'status_link': 'unbestätigt',
          'timestamp_link_confirmed': null,
        }),
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
            SecurityHelper.sanitizeMap({
              'pendingEmail': newEmail,
              'emailChangeRequestedAt': Timestamp.now(),
              'email_history': FieldValue.arrayUnion([
                {
                  'old_email': currentUserEmail,
                  'new_email': newEmail,
                  'requested_at': FieldValue.serverTimestamp(),
                  'confirmed_at': null,
                  'type': 'email_change',
                  'request_id': requestRef.id,
                },
              ]),
            }),
            SetOptions(merge: true),
          );

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => styledDialog(
          context: dialogContext,
          title: localizations.change_email,
          content: Text(
            localizations.email_change_check_inbox,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            compactActionButton(
              dialogContext: dialogContext,
              label: localizations.ok,
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(),
            ),
          ],
        ),
      );
      onSaved?.call();
    } catch (e) {
      if (!context.mounted) return;
      String errorMessage =
          localizations.error_sending_confirmation;
      final err = e.toString();
      if (err.contains('email-already-in-use') ||
          err.contains('already exists')) {
        errorMessage =
            localizations.email_already_in_use;
      } else if (err.contains('invalid-email')) {
        errorMessage =
            localizations.invalid_email_address;
      } else if (err.contains('wrong-password') ||
          err.contains('invalid-credential')) {
        errorMessage =
            localizations.wrong_password;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => styledDialog(
          context: dialogContext,
          title: localizations.error,
          content: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            compactActionButton(
              dialogContext: dialogContext,
              label: localizations.ok,
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(),
            ),
          ],
        ),
      );
    } finally {
      _disposeControllerAfterFrame(passwordController);
      _disposeControllerAfterFrame(confirmEmailController);
    }
  }
}
