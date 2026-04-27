import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_email_service.dart';

/// Wird angezeigt, solange [User.emailVerified] für E-Mail-Accounts noch false ist.
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key});

  static const Color accentOrange = Color(0xFFFF8C42);
  static const String logoAsset = 'assets/icon/vibesbox-logo.png';

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _busy = false;

  Future<void> _resend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final l = AppLocalizations.of(context)!;
      if (l == null) return;
      await AuthEmailService.sendVerificationEmail(
        l: l,
        user: user,
        userName: user.displayName ?? user.email?.split('@').first ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.success),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      final msg = e.code == 'resource-exhausted'
          ? (loc.error_too_many_requests)
          : '${loc.error}: ${e.message ?? e.code}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.error}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await user.reload();
      // Nur diese Seite wird per setState neu gebaut. MainPage nutzt authStateChangesDistinctByUid()
      // (gleiche UID → oft kein Rebuild); die Schranke springt u. a. bei App-Resume
      // ([FirestoreEmailVerifiedGate]), nach erfolgreichem Verify-Deep-Link (setState in MainPage) frei.
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.error}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signOut();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                VerifyEmailPage.logoAsset,
                height: 88,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 72,
                    color: VerifyEmailPage.accentOrange,
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                l.verify_email_title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l != null
                    ? (email.isNotEmpty
                        ? l.verify_email_message_for(email)
                        : l.verify_email_message.replaceAll('{email}', ''))
                    : 'Bitte bestätige deine E-Mail-Adresse. Wir haben dir einen Link gesendet.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.4,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              _accentButton(
                label: l.verify_email_resend,
                onPressed: _busy ? null : _resend,
              ),
              const SizedBox(height: 12),
              _accentButton(
                label: l.verify_email_refresh,
                onPressed: _busy ? null : _reload,
                outlined: true,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy ? null : _signOut,
                child: Text(
                  l.verify_email_logout,
                  style: const TextStyle(
                    color: VerifyEmailPage.accentOrange,
                    fontSize: 16,
                  ),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: VerifyEmailPage.accentOrange,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accentButton({
    required String label,
    required VoidCallback? onPressed,
    bool outlined = false,
  }) {
    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: VerifyEmailPage.accentOrange,
          side: const BorderSide(color: VerifyEmailPage.accentOrange, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: VerifyEmailPage.accentOrange,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
