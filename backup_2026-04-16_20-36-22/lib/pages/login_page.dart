import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../constants/app_assets.dart';
import '../helpers/security_helper.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_email_service.dart';
import '../services/device_block_fusion_service.dart';
import '../services/saved_login_email_store.dart';
import '../services/registration_flow_guard.dart';
import '../services/subscription_sync_service.dart';
import '../services/user_service.dart';
import '../utils/password_strength_utils.dart';
import '../utils/role_helper.dart';
import '../utils/sanitize.dart';
import '../utils/ui_constants.dart';
import '../widgets/email_verification_dialog.dart';
import '../widgets/password_strength_bar.dart';
import 'verify_email_page.dart';
import '../utils/debug_log.dart';

/// Lässt die App zu, wenn [users/{uid}.email_verified_override] == true.
/// Wird von [MainPage] genutzt, wenn Firebase [emailVerified] noch false ist.
///
/// **Niemals** eine zweite [MainPage] nesten – das dupliziert initState, Listener und
/// kann Native-Crashes / Speicherlecks auslösen. Stattdessen [onEmailVerifiedOverride].
class FirestoreEmailVerifiedGate extends StatefulWidget {
  const FirestoreEmailVerifiedGate({
    super.key,
    required this.user,
    this.onEmailVerifiedOverride,
  });

  final User user;

  /// Einmal aufrufen, wenn Firestore „Override“ gesetzt hat – die äußere [MainPage] setzt dann ihr Flag.
  final VoidCallback? onEmailVerifiedOverride;

  @override
  State<FirestoreEmailVerifiedGate> createState() =>
      _FirestoreEmailVerifiedGateState();
}

class _FirestoreEmailVerifiedGateState extends State<FirestoreEmailVerifiedGate>
    with WidgetsBindingObserver {
  bool _overrideCallbackFired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshVerificationStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshVerificationStatus();
    }
  }

  Future<void> _refreshVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;
    try {
      await user.reload();
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
        _notifyGateSatisfied();
      } else {
        setState(() {});
      }
    } catch (_) {}
  }

  void _notifyGateSatisfied() {
    if (_overrideCallbackFired) return;
    _overrideCallbackFired = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onEmailVerifiedOverride?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null && authUser.emailVerified) {
      _notifyGateSatisfied();
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const VerifyEmailPage();
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final data = snap.data?.data();
        final overrideOk =
            data != null && data['email_verified_override'] == true;
        if (overrideOk ||
            FirebaseAuth.instance.currentUser?.emailVerified == true) {
          _notifyGateSatisfied();
          // Kurz Loader: Parent-[MainPage] baut nach setState ohne Gate neu auf.
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const VerifyEmailPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.startInRegister = false});

  final bool startInRegister;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true; // true = Login, false = Registrierung
  bool _isLoading = false;
  bool _showPassword = true;
  bool _showConfirmPassword = true;
  bool _rememberEmail = false; // Checkbox zum Merken der E-Mail-Adresse
  /// Vor Registrierung: null = Rollenwahl, 'Gast' | 'DJ' = Formular
  String? _selectedRole;

  /// Blockiert mehrfaches Öffnen des Bestätigungs-Dialogs (Auth-/Rebuild-Spikes).
  bool _verificationDialogShown = false;

  static const String _registrationOverlayLogoAsset =
      'assets/icon/vibesbox-logo.png';

  @override
  void initState() {
    super.initState();

    // /register soll direkt im Registrieren-Modus starten
    if (widget.startInRegister) {
      _isLogin = false;
    }
    _loadSavedCredentials();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkAndShowSecuritySnackbar(),
    );
  }

  Future<void> _checkAndShowSecuritySnackbar() async {
    final prefs = await SharedPreferences.getInstance();
    final show = prefs.getBool('show_security_relogin_snackbar') ?? false;
    if (!show || !mounted) return;
    await prefs.remove('show_security_relogin_snackbar');
    if (!mounted) return;
    final context = this.context;
    final msg = AppLocalizations.of(context)!.login_security_snackbar;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
    );
  }

  Future<void> _loadSavedCredentials() async {
    final savedEmail = await SavedLoginEmailStore.read();

    if (savedEmail != null && savedEmail.trim().isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberEmail = true;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  InputDecoration _orangeDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    const orange = UIConstants.appOrange;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: orange, width: 1.5),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: orange, width: 2),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    );
    final focusedErrorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.red, width: 2),
    );
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: orange),
      floatingLabelStyle: const TextStyle(color: orange),
      prefixIcon: Icon(prefixIcon, color: orange),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.black,
      enabledBorder: border,
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
      focusedErrorBorder: focusedErrorBorder,
    );
  }

  bool _isLikelyFirebaseEmail(String email) {
    final sanitized = sanitizeEmail(email).trim();
    if (sanitized.isEmpty) return false;
    // Firebase-kompatibel/pragmatisch: ASCII-only und klassisches user@domain.tld Muster.
    final basicPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    final asciiOnly = RegExp(r'^[\x00-\x7F]+$');
    return basicPattern.hasMatch(sanitized) && asciiOnly.hasMatch(sanitized);
  }

  Widget _buildLoginFlowDialog({
    required String title,
    required String content,
    required List<Widget> actions,
    bool verticalActions = false,
    double verticalActionGap = 12,
  }) {
    Widget actionBar;
    if (verticalActions) {
      actionBar = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) SizedBox(height: verticalActionGap),
            actions[i],
          ],
        ],
      );
    } else {
      actionBar =
          Row(mainAxisAlignment: MainAxisAlignment.end, children: actions);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: UIConstants.colorGreyGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: UIConstants.appOrange, width: 2),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            actionBar,
          ],
        ),
      ),
    );
  }

  String? _validatePassword(BuildContext context, String? value) {
    return PasswordStrengthUtils.validateForApp(
      l10n: AppLocalizations.of(context)!,
      value: value,
    );
  }

  void _showDjConfirmDialog() {
    final l = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => _buildLoginFlowDialog(
        title: l.dj_confirm_title,
        content: l.dj_confirm_message,
        verticalActions: true,
        verticalActionGap: 14,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedRole = 'Gast');
            },
            style: TextButton.styleFrom(
              foregroundColor: UIConstants.appOrange,
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Text(
              l.dj_confirm_no,
              softWrap: true,
              textAlign: TextAlign.center,
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _selectedRole = 'DJ');
            },
            style: FilledButton.styleFrom(
              backgroundColor: UIConstants.appOrange,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Text(
              l.dj_confirm_yes,
              softWrap: true,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelectionScaffold(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = true;
                      _selectedRole = null;
                    });
                  },
                  child: Text(
                    l.login_switch_to_login,
                    style: const TextStyle(color: UIConstants.appOrange),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icon/vibesbox-logo.png',
                      height: 140,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return AppAssets.placeholder(height: 140);
                      },
                    ),
                    const SizedBox(height: 36),
                    Text(
                      l.role_selection_title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => setState(() => _selectedRole = 'Gast'),
                        style: FilledButton.styleFrom(
                          backgroundColor: UIConstants.appOrange,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          l.i_am_guest,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _showDjConfirmDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: UIConstants.appOrange,
                          side: const BorderSide(
                            color: UIConstants.appOrange,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          l.i_am_dj,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    // Sanitize Email gegen Schadcode (Passwort wird NICHT sanitisiert, da Sonderzeichen wichtig sind)
    final email = sanitizeEmail(_emailController.text.trim());
    final password = _passwordController
        .text; // Passwort nicht sanitisieren - Sonderzeichen sind wichtig!

    setState(() => _isLoading = true);

    bool profileLoadFailed = false;

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      try {
        await DeviceBlockFusionService.applyIfNeeded(userCredential.user!);
      } catch (e, st) {
        debugLog('DeviceBlockFusion nach Login: $e\n$st');
      }

      // Login-Zähler und Firestore-Profil (mit hochsicherer Silent-Retry für role_id)
      if (userCredential.user != null) {
        try {
          const int maxRetries = 5;
          const Duration retryDelay = Duration(milliseconds: 800);
          final usersRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid);

          DocumentSnapshot? lastDoc = await usersRef.get();
          Map<String, dynamic>? userDocData =
              lastDoc?.data() as Map<String, dynamic>?;

          // Login-Sperre: inaktiv („gelöscht“) oder gesperrt – vor Weiterleitung prüfen
          final status = (userDocData?['status'] as String?)
              ?.trim()
              .toLowerCase();
          if (status == 'inaktiv') {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            setState(() => _isLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.login_error_inactive,
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          if (status == 'gesperrt' || status == 'blocked') {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            setState(() => _isLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.login_error_banned,
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          final blockedFlag = userDocData?['is_blocked'] == true;
          if (blockedFlag) {
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            setState(() => _isLoading = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.login_error_banned,
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          bool hasValidRoleId(Map<String, dynamic>? data) {
            if (data == null) return false;
            final r = data['role_id'];
            if (r == null) return false;
            return (r is String && r.trim().isNotEmpty);
          }

          String? loadedRoleId = hasValidRoleId(userDocData)
              ? (userDocData!['role_id'] as String).trim()
              : null;

          // Silent-Retry: 5 Versuche, je 800 ms Abstand, Lade-Indikator bleibt aktiv
          if (loadedRoleId == null) {
            for (int attempt = 1; attempt <= maxRetries && mounted; attempt++) {
              await Future.delayed(retryDelay);
              if (!mounted) return;
              lastDoc = await usersRef.get();
              userDocData = lastDoc?.data() as Map<String, dynamic>?;
              if (hasValidRoleId(userDocData)) {
                loadedRoleId = (userDocData!['role_id'] as String).trim();
                debugLog(
                  'Profil-Daten nach Retry $attempt geladen (role_id vorhanden).',
                );
                break;
              }
            }
          }

          int currentCount = 0;
          Timestamp? previousLogin;
          if (lastDoc != null && lastDoc.exists && userDocData != null) {
            final loginCountValue = userDocData['loginCount'];
            if (loginCountValue is int) {
              currentCount = loginCountValue;
            } else if (loginCountValue is num) {
              currentCount = loginCountValue.toInt();
            }
            final lastLoginValue = userDocData['lastLogin'];
            if (lastLoginValue is Timestamp) {
              previousLogin = lastLoginValue;
            }
            debugLog('Aktueller Login-Zähler aus Firestore: $currentCount');
          }

          final newCount = currentCount + 1;
          final now = Timestamp.now();
          bool needsCreatedAt =
              userDocData == null || userDocData['created_at'] == null;

          // role_id aus Firestore übernehmen (kein E-Mail-Override mehr)
          final roleIdToSet = loadedRoleId;

          final updateData = <String, dynamic>{
            'email': userCredential.user!.email,
            'displayName': userCredential.user!.displayName,
            'loginCount': newCount,
            'lastLogin': now,
            'previousLogin': previousLogin,
          };
          if (roleIdToSet != null) {
            updateData['role_id'] = roleIdToSet;
          }
          if (needsCreatedAt) {
            updateData['created_at'] = now;
          }

          await usersRef.set(
            SecurityHelper.sanitizeMap(updateData),
            SetOptions(merge: true),
          );
          debugLog('Login-Zähler erfolgreich aktualisiert: $newCount');

          // Eskalation: role_id nach 5 Retries weiterhin nicht vorhanden
          if (loadedRoleId == null) {
            await SubscriptionSyncService.logOut();
            await FirebaseAuth.instance.signOut();
            if (!mounted) return;
            setState(() => _isLoading = false);
            if (!mounted) return;
            await _showProfileLoadErrorDialog(context);
            profileLoadFailed = true;
            return;
          }
        } catch (e) {
          debugLog('Firestore login update fehlgeschlagen: $e');
        }
      }

      if (profileLoadFailed) return;

      // RevenueCat mit Firebase-UID verknüpfen und Pro-Status in Firestore syncen
      await SubscriptionSyncService.logIn(userCredential.user!.uid);
      SubscriptionSyncService.syncSubscriptionStatus(userCredential.user!.uid);

      // DJ-Logo vorladen (Session Caching)
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        final data = userDoc.data();
        final djLogoUrl =
            data?['djLogoUrl'] ??
            data?['dj_logo_url']; // Prüfe beide Keys (CamelCase und SnakeCase)

        if (djLogoUrl != null && djLogoUrl is String && djLogoUrl.isNotEmpty) {
          await UserService().preloadDjLogo(djLogoUrl);
        }
      } catch (e) {
        debugLog('Logo-Preload beim Login fehlgeschlagen: $e');
      }

      // Speichere optional nur die E-Mail (kein Passwort-Storage).
      if (_rememberEmail) {
        await SavedLoginEmailStore.write(email);
      } else {
        await SavedLoginEmailStore.clear();
      }

      // Erfolgreich eingeloggt - zurück navigieren
      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(context, e.code)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isNameBlocked(String name) {
    final normalizedName = name.trim().toUpperCase();

    // Blockierte Namen
    final blockedNames = ['DJ', 'OLLERGANOVE', 'GANOVE', 'OLLER', 'ADMIN'];
    if (blockedNames.contains(normalizedName)) {
      return true;
    }

    // Blacklist für unangemessene Begriffe
    final inappropriateWords = [
      // Schimpfwörter
      'FUCK', 'SHIT', 'ASS', 'BITCH', 'DAMN', 'HELL',
      'CUNT', 'SLUT', 'WHORE', 'BASTARD', 'DICK',
      'PUSSY', 'COCK', 'TITS', 'BOOBS', 'NIGGER',
      'FAGGOT', 'RETARD', 'IDIOT', 'STUPID',
      // Sexuelle Begriffe
      'SEX', 'PORN', 'PENIS', 'VAGINA', 'ORGASM',
      'MASTURBAT', 'EROTIC', 'NAKED', 'NUDE',
      'HARDCORE', 'XXX', 'ADULT', 'EROTIC',
      // Weitere unangemessene Begriffe
      'RAPE', 'VIOLENCE', 'HATE', 'KILL',
    ];

    for (final word in inappropriateWords) {
      if (normalizedName.contains(word)) {
        return true;
      }
    }

    return false;
  }

  /// Zeigt den Eskalations-Dialog, wenn role_id nach 5 Retries nicht geladen werden konnte.
  Future<void> _showProfileLoadErrorDialog(BuildContext context) async {
    final supportEmail = AppConfig.supportEmail;
    final l = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          l.login_profile_load_error_title,
        ),
        content: Text(
          l.login_profile_load_error_body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.retry_button),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse('mailto:$supportEmail');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Text(l.login_contact_support),
          ),
        ],
      ),
    );
  }

  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final role = _selectedRole;
    if (role != 'Gast' && role != 'DJ') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.role_selection_required,
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Sanitize Email gegen Schadcode
    final email = sanitizeEmail(_emailController.text.trim());

    // Blockiere Registrierung mit der offiziellen Kontakt-E-Mail (Schutz der Adresse).
    // Admin-Berechtigung nach Login erfolgt ausschließlich über Firestore role_id, nicht über E-Mail.
    if (email == AppConfig.adminEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.login_email_registration_blocked,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Prüfe auf blockierte Namen
    final name = sanitizeInput(_nameController.text.trim());
    if (_isNameBlocked(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.login_name_blocked,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // WICHTIG:
    // Keine globale users-Collection-Abfrage VOR Registrierung.
    // E-Mail-Duplikate werden zuverlässig über FirebaseAuthException
    // (email-already-in-use) gehandhabt.

    setState(() => _isLoading = true);

    var verificationEmailSendFailed = false;
    UserCredential? credential;

    RegistrationFlowGuard.begin();
    try {
      // sendAuthEmail braucht idToken → erst createUser, dann await sendVerificationEmail (Callable-Future).

      credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: sanitizeEmail(_emailController.text.trim()),
        password: _passwordController.text,
      );

      await credential.user?.updateDisplayName(
        SecurityHelper.sanitize(_nameController.text.trim(), maxLength: 50),
      );
      await credential.user?.reload();

      if (credential.user != null && mounted) {
        final locForEmail = AppLocalizations.of(context)!;
        try {
          // Wartet auf das Future der Callable (sendAuthEmail) bis Antwort/Fehler vom Server
          await AuthEmailService.sendVerificationEmail(
            l: locForEmail,
            user: credential.user!,
            userName: name,
            registrationRole: role ?? 'Gast',
          );
        } on FirebaseFunctionsException catch (e) {
          verificationEmailSendFailed = true;
          debugLog('Auth-E-Mail (Callable): ${e.code} ${e.message}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  locForEmail.login_verification_email_send_failed,
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 10),
              ),
            );
          }
        } catch (e, st) {
          verificationEmailSendFailed = true;
          debugLog('Auth-E-Mail: $e\n$st');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  locForEmail.login_verification_email_send_failed,
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 10),
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(context, e.code)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Gate erst nach vollständigem Mail-Ablauf (await oben) — nicht vor Firestore/RevenueCat
      RegistrationFlowGuard.end();
    }

    // Ab hier: MainPage darf wieder auf Auth reagieren (Cold-Start nachgelagert).
    if (credential != null && credential.user != null) {
      try {
        final authUid = await _waitForAuthenticatedUid(credential!.user!.uid);
        if (authUid == null) {
          throw StateError('auth_not_ready');
        }
        final roleId = await _resolveRoleIdForRegistration(role ?? 'Gast');
        if (roleId == null || roleId.trim().isEmpty) {
          throw StateError('role_id_missing');
        }

        const maxProfileWriteAttempts = 2;
        Object? lastProfileError;
        for (var attempt = 0; attempt < maxProfileWriteAttempts; attempt++) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(authUid)
                .set(
                  SecurityHelper.sanitizeMap({
                    'email': credential.user!.email,
                    'displayName':
                        (credential.user!.displayName != null &&
                            credential.user!.displayName!.trim().isNotEmpty)
                        ? credential.user!.displayName!.trim()
                        : name,
                    'loginCount': 1,
                    'lastLogin': Timestamp.now(),
                    'created_at': Timestamp.now(),
                    'role_id': roleId,
                    'status': 'aktiv',
                  }),
                  SetOptions(merge: true),
                );
            lastProfileError = null;
            break;
          } catch (e, st) {
            lastProfileError = e;
            debugLog(
              'Firestore registration update Versuch ${attempt + 1}/$maxProfileWriteAttempts: $e\n$st',
            );
            if (attempt < maxProfileWriteAttempts - 1) {
              await Future<void>.delayed(const Duration(milliseconds: 500));
            }
          }
        }
        if (lastProfileError != null) {
          throw lastProfileError;
        }
      } catch (e, st) {
        debugLog('Firestore registration update fehlgeschlagen: $e\n$st');
        try {
          await SubscriptionSyncService.logOut();
        } catch (_) {}
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
        if (mounted) {
          final loc = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                verificationEmailSendFailed
                    ? loc.login_registration_profile_failed
                    : loc.login_registration_profile_failed_after_email_ok,
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
            ),
          );
        }
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      await SubscriptionSyncService.logIn(credential.user!.uid);
      SubscriptionSyncService.syncSubscriptionStatus(credential.user!.uid);

      if (mounted && !verificationEmailSendFailed) {
        final mail = credential.user!.email?.trim() ?? '';
        if (mail.isNotEmpty) {
          await _showPostRegistrationVerificationDialog(mail);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.login_registration_success,
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Nach Registrierung: [EmailVerificationDialog] (VibesBox-Logo, Hinweistext, manueller `oobCode` gem. l10n:
  /// [manual_code_hint], [verify_manual_check], Erfolg [EmailVerificationResultDialog] mit [verify_success_title]/[verify_success_instruction]. Deep-Link: [AppLinksService].
  Future<void> _showPostRegistrationVerificationDialog(String email) async {
    if (!mounted || _verificationDialogShown) return;
    try {
      _verificationDialogShown = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => EmailVerificationDialog(email: email),
      );
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<String?> _waitForAuthenticatedUid(
    String expectedUid, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == expectedUid) return currentUid;
      await Future.delayed(const Duration(milliseconds: 120));
    }
    return FirebaseAuth.instance.currentUser?.uid == expectedUid
        ? expectedUid
        : null;
  }

  Future<String?> _resolveRoleIdForRegistration(String role) async {
    if (role == 'DJ' &&
        AppConfig.djRoleId != null &&
        AppConfig.djRoleId!.isNotEmpty) {
      return AppConfig.djRoleId;
    }
    if (role != 'DJ' &&
        AppConfig.guestRoleId != null &&
        AppConfig.guestRoleId!.isNotEmpty) {
      return AppConfig.guestRoleId;
    }
    final roleName = role == 'DJ' ? 'DJ' : 'Gast';
    return getRoleIdByName(roleName);
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.login_reset_email_required,
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_isLikelyFirebaseEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.login_email_invalid,
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final l = AppLocalizations.of(context)!;
      await AuthEmailService.sendPasswordResetEmail(
        l: l,
        email: email,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.login_reset_email_sent,
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugLog('❌ Reset-Email (Callable): ${e.code} ${e.message}');
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        final msg = e.code == 'resource-exhausted'
            ? loc.error_too_many_requests
            : '${loc.error}: ${e.message ?? e.code}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugLog('❌ Fehler beim Senden der Reset-Email: $e');
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getErrorMessage(BuildContext context, String code) {
    final l = AppLocalizations.of(context)!;
    final neutral = l.login_error_invalid_credentials;
    switch (code) {
      case 'user-not-found':
        return neutral;
      case 'wrong-password':
        return neutral;
      case 'invalid-credential':
        return neutral;
      case 'email-already-in-use':
        return l.login_email_already_registered;
      case 'weak-password':
        return l.login_password_weak_firebase;
      case 'invalid-email':
        return l.login_invalid_email;
      case 'operation-not-allowed':
        return l.login_operation_not_allowed;
      default:
        return neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLogin && _selectedRole == null) {
      return _buildRoleSelectionScaffold(context);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                if (!_isLogin && _selectedRole != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      onPressed: () => setState(() => _selectedRole = null),
                    ),
                  ),
                const SizedBox(height: 40),
                // Logo groß auf schwarzem Hintergrund
                Image.asset(
                  'assets/icon/vibesbox-logo.png',
                  height: 180,
                  fit: BoxFit.contain,
                  color: null, // Logo behält seine Farben
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return AppAssets.placeholder(height: 180);
                  },
                ),
                const SizedBox(height: 40),
                Text(
                  _isLogin
                      ? AppLocalizations.of(context)!.login_title
                      : AppLocalizations.of(context)!.register_title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Party-Code: nicht auf Login/Registrierung (pending_party_code bleibt z. B. von Startseite/QR in SharedPreferences)
                // Email Feld
                TextFormField(
                  controller: _emailController,
                  maxLength: 200,
                  decoration: _orangeDecoration(
                    labelText:
                        AppLocalizations.of(context)!.login_email_label,
                    prefixIcon: Icons.email,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (value) {
                    final safe = SecurityHelper.sanitize(value, maxLength: 200);
                    if (safe != value) {
                      _emailController.value = _emailController.value.copyWith(
                        text: safe,
                        selection: TextSelection.collapsed(offset: safe.length),
                      );
                    }
                  },
                  validator: (value) {
                    final l = AppLocalizations.of(context)!;
                    if (value == null || value.trim().isEmpty) {
                      return l.login_email_required;
                    }
                    if (!_isLikelyFirebaseEmail(value)) {
                      return l.login_email_invalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Name Feld nur bei Registrierung (nach Rollenwahl)
                if (!_isLogin && _selectedRole != null) ...[
                  TextFormField(
                    controller: _nameController,
                    maxLength: 50,
                    decoration: _orangeDecoration(
                      labelText:
                          AppLocalizations.of(context)!.login_name_label,
                      prefixIcon: Icons.person,
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) {
                      final safe = SecurityHelper.sanitize(
                        value,
                        maxLength: 50,
                      );
                      if (safe != value) {
                        _nameController.value = _nameController.value.copyWith(
                          text: safe,
                          selection: TextSelection.collapsed(
                            offset: safe.length,
                          ),
                        );
                      }
                    },
                    validator: (value) {
                      if (!_isLogin &&
                          _selectedRole != null &&
                          (value == null || value.trim().isEmpty)) {
                        return AppLocalizations.of(context)!
                            .login_name_required;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                // Passwort Feld
                TextFormField(
                  controller: _passwordController,
                  onChanged: (_) {
                    if (!_isLogin) {
                      setState(() {});
                    }
                  },
                  decoration: _orangeDecoration(
                    labelText:
                        AppLocalizations.of(context)!.login_password_label,
                    prefixIcon: Icons.lock,
                    suffixIcon: _isLogin
                        ? IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: UIConstants.appOrange,
                            ),
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.help_outline,
                                  size: 20,
                                  color: UIConstants.appOrange,
                                ),
                                tooltip: AppLocalizations.of(context)!
                                    .login_password_requirements_tooltip,
                                onPressed: () {
                                  final l = AppLocalizations.of(context)!;
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => _buildLoginFlowDialog(
                                      title:
                                          l.login_password_requirements_tooltip,
                                      content: l.password_too_short,
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                UIConstants.appOrange,
                                          ),
                                          child: Text(l.ok),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: UIConstants.appOrange,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                              ),
                            ],
                          ),
                  ),
                  obscureText: _showPassword,
                  validator: _isLogin
                      ? (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!
                                .login_password_required;
                          }
                          return null;
                        }
                      : (value) => _validatePassword(context, value),
                ),
                if (!_isLogin && _selectedRole != null) ...[
                  const SizedBox(height: 8),
                  PasswordStrengthBar(password: _passwordController.text),
                ],
                // Passwort bestätigen (nur bei Registrierung)
                if (!_isLogin && _selectedRole != null) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: _orangeDecoration(
                      labelText:
                          AppLocalizations.of(context)!.confirm_password,
                      prefixIcon: Icons.lock,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: UIConstants.appOrange,
                        ),
                        onPressed: () {
                          setState(() {
                            _showConfirmPassword = !_showConfirmPassword;
                          });
                        },
                      ),
                    ),
                    obscureText: _showConfirmPassword,
                    validator: (value) {
                      final l = AppLocalizations.of(context)!;
                      if (value == null || value.isEmpty) {
                        return l.login_confirm_password_required;
                      }
                      if (value != _passwordController.text) {
                        return l.passwords_dont_match;
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 8),
                // Passwort vergessen und E-Mail merken (nur bei Login)
                if (_isLogin) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Checkbox(
                        value: _rememberEmail,
                        onChanged: (value) {
                          setState(() {
                            _rememberEmail = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.login_save_password,
                        ),
                      ),
                      TextButton(
                        onPressed: _resetPassword,
                        child: Text(
                          AppLocalizations.of(context)!.login_forgot_password,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: UIConstants.appOrange,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading
                        ? null
                        : (_isLogin ? _signInWithEmail : _registerWithEmail),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            _isLogin
                                ? AppLocalizations.of(context)!.login_title
                                : AppLocalizations.of(context)!.register_title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                // Wechsel zwischen Login und Registrierung
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: UIConstants.appOrange,
                  ),
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isLogin = !_isLogin;
                            if (!_isLogin) {
                              _selectedRole = null;
                            }
                          });
                        },
                  child: Text(
                    _isLogin
                        ? AppLocalizations.of(context)!.login_switch_to_register
                        : AppLocalizations.of(context)!.login_switch_to_login,
                  ),
                ),
                  ],
                ),
              ),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: RegistrationFlowGuard.isRegistering,
            builder: (context, registering, _) {
              if (!registering) return const SizedBox.shrink();
              final l = AppLocalizations.of(context)!;
              return Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.85),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              _registrationOverlayLogoAsset,
                              height: 120,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) {
                                return AppAssets.placeholder(height: 120);
                              },
                            ),
                            const SizedBox(height: 28),
                            const CircularProgressIndicator(
                              color: UIConstants.appOrange,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              l.registration_in_progress,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
