import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Für Clipboard
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../l10n/app_localizations.dart';
import '../services/user_service.dart'; // Session Caching Service
import 'profile/widgets/profile_payment_history.dart';
import 'profile/widgets/change_password_dialog.dart';
import 'profile/widgets/profile_edit_dialogs.dart';
import 'profile/widgets/profile_image_section.dart';
import 'profile/widgets/pro_status_card.dart';
import '../utils/role_helper.dart';
import '../services/referral_service.dart';
import '../widgets/custom_page_header.dart';
import '../utils/ui_constants.dart';
import '../utils/sanitize.dart' show sanitizeEmail;
import '../helpers/security_helper.dart';
import '../services/countries_service.dart';
import '../utils/debug_log.dart';

// Profil-Seite
class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSubscription;
  String? _profileImageUrl;
  String? _djLogoUrl;
  bool _justPurchased = false;
  bool _paywallOpen = false;
  final ReferralService _referralService = ReferralService();

  late TextEditingController _djNameController;
  late TextEditingController _realNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _nameController;
  bool _emailVerificationSyncRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _djNameController = TextEditingController();
    _realNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _nameController = TextEditingController();
    _loadProfileImage();
    _loadDjLogo();
    _ensureReferralCode();
    // Höre auf Auth-Änderungen, um Email-Änderungen zu erkennen
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && mounted) {
        _checkEmailVerificationStatus();
        _loadProfileImage();
        _loadDjLogo();
        _ensureReferralCode();
      } else if (mounted) {
        setState(() {
          _profileImageUrl = null;
          _djLogoUrl = null;
        });
      }
    });
    _checkEmailVerificationStatus();
  }

  Future<void> _ensureReferralCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _referralService.ensureReferralCodeExists(user.uid);
      if (mounted) setState(() {}); // UI Update nach Code-Erstellung
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _djNameController.dispose();
    _realNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkEmailVerificationStatus();
    }
  }

  Future<void> _loadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!mounted) return;
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          setState(() {
            _profileImageUrl = data?['photoURL'] as String?;
          });
        }
      } catch (e) {
        debugLog('Fehler beim Laden des Profilbilds: $e');
      }
    }
  }

  Future<void> _loadDjLogo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!mounted) return;
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          setState(() {
            _djLogoUrl = data?['dj_logo_url'] as String?;
          });
        }
      } catch (e) {
        debugLog('Fehler beim Laden des DJ-Logos: $e');
      }
    }
  }

  Future<void> _checkEmailVerificationStatus() async {
    if (_emailVerificationSyncRunning) return;
    _emailVerificationSyncRunning = true;
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) return;

      await current.reload();
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final userDoc = await userRef.get();
      if (!mounted || !userDoc.exists) return;

      final data =
          userDoc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
      final pendingEmail = (data['pendingEmail'] as String?)?.trim();
      final authEmail = (user.email ?? '').trim();
      if (pendingEmail == null || pendingEmail.isEmpty) return;
      if (authEmail.isEmpty) return;
      if (authEmail.toLowerCase() != pendingEmail.toLowerCase()) return;

      final emailHistory = data['email_history'] as List<dynamic>?;
      String? requestId;
      List<Map<String, dynamic>>? updatedHistory;
      if (emailHistory != null) {
        final list = <Map<String, dynamic>>[
          for (final entry in emailHistory)
            entry is Map
                ? Map<String, dynamic>.from(entry as Map)
                : <String, dynamic>{},
        ];
        for (var i = list.length - 1; i >= 0; i--) {
          final row = list[i];
          if ((row['new_email']?.toString().trim().toLowerCase() ?? '') ==
              authEmail.toLowerCase()) {
            if (row['confirmed_at'] == null) {
              row['confirmed_at'] = Timestamp.now();
              requestId = row['request_id']?.toString();
              updatedHistory = list;
            } else {
              requestId = row['request_id']?.toString();
            }
            break;
          }
        }
      }

      DocumentReference<Map<String, dynamic>>? requestRef;
      if (requestId != null && requestId.trim().isNotEmpty) {
        requestRef = userRef.collection('email_changes').doc(requestId.trim());
      } else {
        final query = await userRef
            .collection('email_changes')
            .where('new_email', isEqualTo: authEmail)
            .where('status_link', isEqualTo: 'unbestätigt')
            .limit(1)
            .get();
        if (!mounted) return;
        if (query.docs.isNotEmpty) {
          requestRef = query.docs.first.reference;
        }
      }

      final updatePayload = <String, dynamic>{
        'email': authEmail,
        'pendingEmail': FieldValue.delete(),
        'emailChangeRequestedAt': FieldValue.delete(),
      };
      if (updatedHistory != null) {
        updatePayload['email_history'] = updatedHistory;
      }

      final batch = FirebaseFirestore.instance.batch();
      batch.set(
        userRef,
        SecurityHelper.sanitizeMap(updatePayload),
        SetOptions(merge: true),
      );
      if (requestRef != null) {
        batch.set(
          requestRef,
          SecurityHelper.sanitizeMap({
            'status_link': 'bestätigt',
            'timestamp_link_confirmed': FieldValue.serverTimestamp(),
          }),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      if (!mounted) return;

      setState(() {
        _emailController.text = authEmail;
      });

      final l = AppLocalizations.of(context)!;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => ProfileEditDialogs.styledDialog(
          context: dialogContext,
          title: l.change_email,
          content: Text(
            l.email_change_success_confirmed,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext, rootNavigator: true).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: UIConstants.appOrange,
              ),
              child: Text(l.ok),
            ),
          ],
        ),
      );
      if (!mounted) return;
    } catch (e) {
      debugLog('Email-Verifikationssync fehlgeschlagen: $e');
    } finally {
      _emailVerificationSyncRunning = false;
    }
  }

  /// Erstellt eine einfache Zeile ohne Rahmen innerhalb eines gemeinsamen Containers
  /// Verwendet nur Abstände oder dezente Trenner
  Widget _buildProfileRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Widget value,
    EdgeInsets? padding,
    bool isFirst = false,
    bool isLast = false,
    /// Gast-Profil: dezente graue Beschriftung (VibesBox-Stil)
    bool guestMutedLabel = false,
  }) {
    return Column(
      children: [
        // Dezenter Trenner zwischen den Zeilen (nicht bei der ersten)
        if (!isFirst)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.white.withValues(alpha: 0.1), // Dezente graue Linie
          ),
        Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: guestMutedLabel ? Colors.white54 : Colors.white70,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight:
                            guestMutedLabel ? FontWeight.w600 : FontWeight.bold,
                        color: guestMutedLabel ? Colors.white70 : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    DefaultTextStyle(
                      style:
                          Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: guestMutedLabel
                                ? Colors.white60
                                : Colors.white70,
                          ) ??
                          TextStyle(
                            color: guestMutedLabel
                                ? Colors.white60
                                : Colors.white70,
                          ),
                      child: value,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Zeile „Alternative E-Mail“ mit Checkbox. Bei Aktivierung: Dialog öffnen. Bei Deaktivierung: Bestätigung.
  Widget _buildAlternativeEmailRow({
    required BuildContext context,
    required bool useAlternativeEmail,
    required String? alternativeEmail,
    required String uid,
  }) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.white.withValues(alpha: 0.1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.alternate_email, size: 20, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.profile_alternative_email,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (useAlternativeEmail &&
                        alternativeEmail != null &&
                        alternativeEmail.isNotEmpty)
                      Text(
                        alternativeEmail,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                      )
                    else
                      Text(
                        loc.profile_alternative_email_disabled,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
                      ),
                  ],
                ),
              ),
              Checkbox(
                value: useAlternativeEmail,
                onChanged: (v) async {
                  if (v == true) {
                    await _showAlternativeEmailDialog(
                      context,
                      uid,
                      initialEmail: alternativeEmail,
                    );
                  } else {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 400),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1F2937), Color(0xFF121417)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: UIConstants.appOrange,
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  loc.profile_alternative_email_disable_title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  loc.profile_alternative_email_disable_body,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                      ),
                                      child: Text(loc.cancel),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: UIConstants.appOrange,
                                        foregroundColor: Colors.black,
                                      ),
                                      child: Text(
                                        loc.profile_alternative_email_disable_confirm,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .update(
                            SecurityHelper.sanitizeMap({
                              'useAlternativeEmail': false,
                            }),
                          );
                    }
                  }
                },
                activeColor: UIConstants.appOrange,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showAlternativeEmailDialog(
    BuildContext context,
    String uid, {
    String? initialEmail,
  }) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _AlternativeEmailDialog(uid: uid, initialEmail: initialEmail),
    );
    if (result == null || result.isEmpty || !context.mounted) return;
    final loc = AppLocalizations.of(context)!;
    final trimmed = sanitizeEmail(result.trim());
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(
            SecurityHelper.sanitizeMap({
              'alternativeEmail': trimmed,
              'useAlternativeEmail': true,
            }),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.profile_alternative_email_saved,
            ),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    final l = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: UIConstants.djShellPageBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.green, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text(
                l.pro_activated_success,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: Text(l.ok),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRedeemCodeDialog(String uid) async {
    final controller = TextEditingController();
    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final dl = AppLocalizations.of(dialogContext)!;
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    FocusScope.of(dialogContext).unfocus();
                    FocusManager.instance.primaryFocus?.unfocus();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext, rootNavigator: true).pop();
                      }
                    });
                  },
                  child: Container(color: Colors.black54),
                ),
              ),
              Center(
                child: AlertDialog(
                  backgroundColor: const Color(0xFF1F2937),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(
                      color: UIConstants.appOrange,
                      width: 1,
                    ),
                  ),
                  title: Text(
                    dl.referral_redeem_title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dl.referral_redeem_body,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        maxLength: 8,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: dl.referral_code_hint,
                          hintStyle: const TextStyle(color: Colors.white30),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: UIConstants.appOrange),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        FocusScope.of(dialogContext).unfocus();
                        FocusManager.instance.primaryFocus?.unfocus();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (dialogContext.mounted) {
                            Navigator.of(
                              dialogContext,
                              rootNavigator: true,
                            ).pop();
                          }
                        });
                      },
                      child: Text(
                        dl.cancel,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final code = controller.text.trim();
                        if (code.length != 8) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(dl.referral_code_length),
                              ),
                            );
                          }
                          return;
                        }
                        FocusScope.of(dialogContext).unfocus();
                        FocusManager.instance.primaryFocus?.unfocus();
                        final parentCtx = context;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (dialogContext.mounted) {
                            Navigator.of(
                              dialogContext,
                              rootNavigator: true,
                            ).pop();
                          }
                          _referralService.redeemCode(uid, code).then((success) {
                            if (!parentCtx.mounted) return;
                            final loc = AppLocalizations.of(parentCtx)!;
                            if (success) {
                              ScaffoldMessenger.of(parentCtx).showSnackBar(
                                SnackBar(
                                  content: Text(loc.referral_code_saved),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              setState(() {});
                            } else {
                              ScaffoldMessenger.of(parentCtx).showSnackBar(
                                SnackBar(
                                  content: Text(loc.referral_code_invalid),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          });
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UIConstants.appOrange,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(dl.referral_redeem_action),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildRoleLoadingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

   Widget _buildGuestProfileView({
    required BuildContext context,
    required User user,
    required String displayName,
    required AppLocalizations localizations,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomPageHeader(
            icon: Icons.person,
            title: localizations.profile,
          ),
          const SizedBox(height: 24),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, userSnap) {
              final ud = (userSnap.hasData && userSnap.data!.exists)
                  ? userSnap.data!.data() as Map<String, dynamic>?
                  : null;
              final guestDisplayName =
                  (ud?['displayName'] as String?)?.trim().isNotEmpty == true
                  ? (ud?['displayName'] as String).trim()
                  : displayName;
              final guestEmail = (user.email ?? '').trim().isNotEmpty
                  ? user.email!.trim()
                  : ((ud?['email'] as String?)?.trim().isNotEmpty == true
                        ? (ud?['email'] as String).trim()
                        : localizations.no_email);
              final createdTs = ud?['created_at'] as Timestamp?;
              final memberDate = createdTs?.toDate() ??
                  user.metadata.creationTime ??
                  DateTime.now();
              final memberDateStr = DateFormat.yMMMMd(
                Localizations.localeOf(context).languageCode,
              ).format(memberDate);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProfileAvatarHeader(
                    uid: user.uid,
                    profileImageUrl: _profileImageUrl,
                    avatarInitialName: guestDisplayName,
                    onProfileImageUpdated: (url) =>
                        setState(() => _profileImageUrl = url),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1F2937), Color(0xFF121417)],
                      ),
                      border: Border.all(color: UIConstants.appOrange, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildProfileRow(
                          context: context,
                          icon: Icons.person_outline,
                          label: localizations.profile_field_name,
                          value: Text(guestDisplayName),
                          isFirst: true,
                        ),
                        _buildProfileRow(
                          context: context,
                          icon: Icons.email_outlined,
                          label: localizations.profile_email,
                          value: Text(guestEmail),
                          guestMutedLabel: true,
                        ),
                        _buildProfileRow(
                          context: context,
                          icon: Icons.calendar_today_outlined,
                          label: localizations.profile_member_since,
                          value: Text(memberDateStr),
                          isLast: true,
                          guestMutedLabel: true,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: UIConstants.appOrange,
                                ),
                                tooltip: localizations.profile_edit_data_title,
                                onPressed: () async {
                                  final result =
                                      await ProfileEditDialogs.showMainEditDialog(
                                        context,
                                        user,
                                        isGuest: true,
                                      );
                                  if (!mounted) return;
                                  if (result == 'personal') {
                                    await ProfileEditDialogs.showPersonalDataDialog(
                                      context,
                                      user,
                                      isGuest: true,
                                      djNameController: _djNameController,
                                      realNameController: _realNameController,
                                      phoneController: _phoneController,
                                      onSaved: () {
                                        if (mounted) setState(() {});
                                      },
                                    );
                                  } else if (result == 'password') {
                                    await ChangePasswordDialog.show(context);
                                  } else if (result == 'email') {
                                    await ProfileEditDialogs.showEditEmailDialog(
                                      context,
                                      user,
                                      emailController: _emailController,
                                      onSaved: () {
                                        if (mounted) setState(() {});
                                      },
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () => _showDeleteAccountFlow(context),
              child: Text(
                localizations.delete_account,
                style: TextStyle(color: Colors.red.shade400, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: UIConstants.kFooterPadding * 2),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      final guestLoc = AppLocalizations.of(context)!;
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.login,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    guestLoc.please_log_in,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    guestLoc.must_be_logged_in,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Registrierungsdatum aus User-Metadaten
    final localizations = AppLocalizations.of(context)!;
    final creationTime = user.metadata.creationTime ?? DateTime.now();
    final displayName = user.displayName ?? localizations.no_name;
    final email = user.email ?? localizations.no_email;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: FutureBuilder<String?>(
          future: getUserRoleName(user),
          builder: (context, roleSnap) {
            final roleName = roleSnap.data;
            if (roleSnap.connectionState != ConnectionState.done) {
              return _buildRoleLoadingView();
            }
            final isGuest = roleName == null || roleName == 'Gast';
            final isDj =
                roleName == 'DJ' ||
                roleName == 'Admin' ||
                roleName == 'Location';

            if (isGuest) {
              return _buildGuestProfileView(
                context: context,
                user: user,
                displayName: displayName,
                localizations: localizations,
              );
            }
            if (!isDj) {
              return _buildRoleLoadingView();
            }

            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomPageHeader(
                    icon: Icons.person,
                    title: localizations.profile,
                  ),
                  const SizedBox(height: 24),
                  ProfileAvatarHeader(
                    uid: user.uid,
                    profileImageUrl: _profileImageUrl,
                    onProfileImageUpdated: (url) =>
                        setState(() => _profileImageUrl = url),
                  ),
                  if (!isGuest) ...[
                    ProStatusCard(
                      uid: user.uid,
                      onPurchased: () {
                        setState(() => _justPurchased = true);
                        _showSuccessDialog();
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1F2937), Color(0xFF121417)],
                      ),
                      border: Border.all(
                        color: UIConstants.appOrange,
                        width: 2,
                      ),
                    ),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .snapshots(),
                      builder: (context, userSnap) {
                        final ud = (userSnap.hasData && userSnap.data!.exists)
                            ? userSnap.data!.data() as Map<String, dynamic>?
                            : null;
                        final realName = ud?['realName'] as String?;
                        final countryCode = ud?['country'] as String?;
                        final birthDateTs = ud?['birthDate'] as Timestamp?;
                        final birthDate = birthDateTs?.toDate();
                        final useAlternativeEmail =
                            ud?['useAlternativeEmail'] as bool? ?? false;
                        final alternativeEmail =
                            ud?['alternativeEmail'] as String?;
                        final phoneNumber = ud?['phoneNumber'] as String?;
                        final loc = AppLocalizations.of(context)!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildProfileRow(
                              context: context,
                              icon: Icons.person_outline,
                              label: isGuest
                                  ? loc.name
                                  : loc.profile_dj_name,
                              value: Text(displayName),
                              isFirst: true,
                            ),
                            if (!isGuest)
                              _buildProfileRow(
                                context: context,
                                icon: Icons.badge_outlined,
                                label: loc.profile_real_name,
                                value: Text(
                                  realName?.trim().isEmpty ?? true
                                      ? '–'
                                      : realName!,
                                ),
                              ),
                            _buildProfileRow(
                              context: context,
                              icon: Icons.email_outlined,
                              label: loc.profile_email,
                              value: Text(email),
                            ),
                            if (!isGuest)
                              _buildAlternativeEmailRow(
                                context: context,
                                useAlternativeEmail: useAlternativeEmail,
                                alternativeEmail: alternativeEmail?.trim() ?? '',
                                uid: user.uid,
                              ),
                            if (!isGuest)
                              _buildProfileRow(
                                context: context,
                                icon: Icons.phone_outlined,
                                label: loc.profile_phone,
                                value: Text(
                                  phoneNumber?.trim().isEmpty ?? true
                                      ? '–'
                                      : phoneNumber!,
                                ),
                              ),
                            if (!isGuest) ...[
                              _buildProfileRow(
                                context: context,
                                icon: Icons.cake_outlined,
                                label: loc.profile_birthday,
                                value: Text(
                                  birthDate != null
                                      ? DateFormat.yMMMMd(
                                          Localizations.localeOf(
                                            context,
                                          ).languageCode,
                                        ).format(birthDate)
                                      : '–',
                                ),
                              ),
                              _buildProfileRow(
                                context: context,
                                icon: Icons.public,
                                label: loc.profile_country,
                                value:
                                    countryCode == null || countryCode.isEmpty
                                    ? const Text('–')
                                    : StreamBuilder<DocumentSnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('countries')
                                            .doc(countryCode)
                                            .snapshots(),
                                        builder: (context, countrySnap) {
                                          if (!countrySnap.hasData ||
                                              !countrySnap.data!.exists) {
                                            return Text(countryCode);
                                          }
                                          final data =
                                              countrySnap.data!.data()
                                                  as Map<String, dynamic>?;
                                          final name = data?['name'] as String?;
                                          return Text(name ?? countryCode);
                                        },
                                      ),
                              ),
                            ],
                            _buildProfileRow(
                              context: context,
                              icon: Icons.calendar_today,
                              label: loc.profile_registered_since,
                              value: Text(
                                DateFormat.yMMMMd(
                                  Localizations.localeOf(context).languageCode,
                                ).format(creationTime),
                              ),
                              isLast: true,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: UIConstants.appOrange,
                                    ),
                                    tooltip:
                                        localizations.profile_edit_data_title,
                                    onPressed: () async {
                                      final result =
                                          await ProfileEditDialogs.showMainEditDialog(
                                            context,
                                            user,
                                            isGuest: isGuest,
                                          );
                                      if (!mounted) return;
                                      if (result == 'personal') {
                                        await ProfileEditDialogs.showPersonalDataDialog(
                                          context,
                                          user,
                                          isGuest: isGuest,
                                          djNameController: _djNameController,
                                          realNameController:
                                              _realNameController,
                                          phoneController: _phoneController,
                                          onSaved: () {
                                            if (mounted) setState(() {});
                                          },
                                        );
                                      } else if (result == 'password') {
                                        await ChangePasswordDialog.show(
                                          context,
                                        );
                                      } else if (result == 'email') {
                                        await ProfileEditDialogs.showEditEmailDialog(
                                          context,
                                          user,
                                          emailController: _emailController,
                                          onSaved: () {
                                            if (mounted) setState(() {});
                                          },
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.red.shade400,
                                    ),
                                    tooltip: localizations.delete_account_short,
                                    onPressed: () =>
                                        _showDeleteAccountFlow(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (!isGuest) ...[
                    const SizedBox(height: 24),
                    DjSocialBrandingSection(
                      uid: user.uid,
                      djLogoUrl: _djLogoUrl,
                      onDjLogoUpdated: (url) =>
                          setState(() => _djLogoUrl = url),
                    ),
                    const SizedBox(height: 24),
                    ProfilePaymentHistory(uid: user.uid),
                  ],
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () => _showDeleteAccountFlow(context),
                      child: Text(
                        localizations.delete_account,
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: UIConstants.kFooterPadding * 2),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Vollständiger Account-Lösch-Flow: Re-Auth → Bestätigungs-Dialog → Deaktivierung → Logout.
  Future<void> _showDeleteAccountFlow(BuildContext context) async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final localizations = AppLocalizations.of(context)!;

    // Nur E-Mail/Passwort-Accounts können re-authentifiziert werden
    final hasPasswordProvider = user.providerData.any(
      (p) => p.providerId == 'password',
    );
    if (!hasPasswordProvider || user.email == null || user.email!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.delete_account_requires_email,
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // 1. Re-Authentication: Passwort-Abfrage (vor Missbrauch schützen)
    // Controller außerhalb des Dialogs – wird nach showDialog in finally entsorgt
    final passwordController = TextEditingController();
    String? passwordResult;
    try {
      passwordResult = await showDialog<String?>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          // Lokaler Form-Key pro Dialog-Build, keine globalen Keys die beim Schließen hängen bleiben
          final formKey = GlobalKey<FormState>();
          return AlertDialog(
            backgroundColor: UIConstants.djShellPageBackground,
            title: Text(
              localizations.confirm_password,
            ),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: localizations.your_password,
                  labelStyle: TextStyle(color: Colors.grey[300]),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: UIConstants.appOrange),
                  ),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? localizations.password_cannot_be_empty
                    : null,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (ctx.mounted) {
                      Navigator.of(ctx, rootNavigator: true).pop(null);
                    }
                  });
                },
                child: Text(
                  localizations.cancel,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final pwd = passwordController.text;
                    Navigator.of(ctx).pop(pwd);
                  }
                },
                child: Text(
                  localizations.confirm,
                  style: const TextStyle(color: UIConstants.appOrange),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      passwordController.dispose();
    }
    if (passwordResult == null || passwordResult.isEmpty) return;
    final password = passwordResult;

    // Re-Auth mit Firebase (Credential prüfen)
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } catch (e) {
      if (mounted) {
        String msg = localizations.wrong_password;
        if (e.toString().contains('invalid-credential') ||
            e.toString().contains('wrong-password')) {
          msg = localizations.wrong_password;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // 2. Bestätigungs-Dialog (Party-Lösch-Design: roter Rahmen, Warn-Icon)
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: UIConstants.djShellPageBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red, width: 3),
        ),
        child: AlertDialog(
          backgroundColor: UIConstants.djShellPageBackground,
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.delete_account_question,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            localizations.delete_account_warning,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx, rootNavigator: true).pop(false);
              },
              child: Text(
                localizations.cancel,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx, rootNavigator: true).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(
                localizations.delete_account_permanently,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    // 3. Lade-Overlay während Deaktivierung
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );

    try {
      await UserService().deactivateAccount();
      if (!mounted) return;
      Navigator.of(context).pop(); // Lade-Overlay schließen
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Lade-Overlay schließen
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.error_deleting_account} $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Sektion für persönliche Daten (Real Name, Country, Birthdate). Nur realName und country werden gespeichert.
class _PersonalDataSection extends StatefulWidget {
  const _PersonalDataSection({required this.uid});

  final String uid;

  @override
  State<_PersonalDataSection> createState() => _PersonalDataSectionState();
}

class _PersonalDataSectionState extends State<_PersonalDataSection> {
  final TextEditingController _realNameController = TextEditingController();
  String? _selectedCountryCode;
  List<CountryEntry> _countries = [];
  bool _countriesLoaded = false;
  bool _saving = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    CountriesService.getCountriesOnce().then((list) {
      if (mounted)
        setState(() {
          _countries = list;
          _countriesLoaded = true;
        });
    });
  }

  @override
  void dispose() {
    _realNameController.dispose();
    super.dispose();
  }

  Future<void> _savePersonalData() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final trimName = _realNameController.text.trim();
      final updateData = <String, dynamic>{
        'realName': trimName.isEmpty
            ? FieldValue.delete()
            : SecurityHelper.sanitize(trimName, maxLength: 80),
        'country': _selectedCountryCode ?? FieldValue.delete(),
        // birthDate bewusst nicht im Update – keine versehentlichen Änderungen
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update(SecurityHelper.sanitizeMap(updateData));
      if (mounted) {
        UserService().forceRefresh();
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.name_changed),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final realName = data['realName'] as String?;
        final country = data['country'] as String?;
        final birthDateTs = data['birthDate'] as Timestamp?;
        final birthDate = birthDateTs?.toDate();

        if (!_initialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_initialized) {
              _realNameController.text = realName ?? '';
              setState(() {
                _selectedCountryCode = country;
                _initialized = true;
              });
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white.withValues(alpha: 0.1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.profile_personal_data,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _realNameController,
                    decoration: InputDecoration(
                      labelText: loc.profile_real_name,
                      hintText: loc.real_name_label,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: UIConstants.appOrange,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: UIConstants.appOrange.withValues(alpha: 0.7),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: UIConstants.appOrange,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.black,
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  if (!_countriesLoaded)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      key: ValueKey<String?>(_selectedCountryCode),
                      initialValue: _selectedCountryCode,
                      decoration: InputDecoration(
                        labelText: 'Country',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: UIConstants.appOrange,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: UIConstants.appOrange.withValues(alpha: 0.7),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: UIConstants.appOrange,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.black,
                      ),
                      dropdownColor: const Color(0xFF1F2937),
                      items: _countries
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c.code,
                              child: Text(
                                c.name,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCountryCode = v),
                    ),
                  const SizedBox(height: 12),
                  // Birthdate nur Anzeige, nicht editierbar
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.cake_outlined,
                        size: 20,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Birthdate',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              birthDate != null
                                  ? DateFormat.yMMMMd(
                                      Localizations.localeOf(
                                        context,
                                      ).languageCode,
                                    ).format(birthDate)
                                  : '–',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Birthdate cannot be changed.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.white54,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _savePersonalData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UIConstants.appOrange,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: UIConstants.appOrange),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text('Speichern'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Dialog zur Eingabe der alternativen E-Mail mit Live-Validierung (Format + Übereinstimmung).
class _AlternativeEmailDialog extends StatefulWidget {
  final String uid;
  final String? initialEmail;

  const _AlternativeEmailDialog({required this.uid, this.initialEmail});

  @override
  State<_AlternativeEmailDialog> createState() =>
      _AlternativeEmailDialogState();
}

class _AlternativeEmailDialogState extends State<_AlternativeEmailDialog> {
  late TextEditingController _emailController;
  late TextEditingController _confirmController;
  static final RegExp _emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
    _confirmController = TextEditingController(text: widget.initialEmail ?? '');
    _emailController.addListener(_onChange);
    _confirmController.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _emailController.removeListener(_onChange);
    _confirmController.removeListener(_onChange);
    _emailController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final e = _emailController.text.trim();
    final c = _confirmController.text.trim();
    return e.isNotEmpty && _emailRegex.hasMatch(e) && e == c;
  }

  String? _getEmailError() {
    final e = _emailController.text.trim();
    if (e.isEmpty) return null;
    if (!_emailRegex.hasMatch(e)) {
      return AppLocalizations.of(
            context,
          )?.profile_alternative_email_validation_invalid ??
          'Bitte gib eine gültige E-Mail-Adresse ein.';
    }
    return null;
  }

  String? _getConfirmError() {
    final e = _emailController.text.trim();
    final c = _confirmController.text.trim();
    if (c.isEmpty) return null;
    if (e != c) {
      return AppLocalizations.of(
            context,
          )?.profile_alternative_email_validation_mismatch ??
          'Die E-Mail-Adressen stimmen nicht überein.';
    }
    return null;
  }

  void _onSave() {
    final trimmed = _emailController.text.trim();
    Navigator.pop(context, trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: UIConstants.appOrange, width: 2),
      ),
      title: Text(
        loc.profile_alternative_email_dialog_title,
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              maxLength: 200,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: loc.profile_alternative_email_dialog_email,
                labelStyle: const TextStyle(color: Colors.white70),
                errorText: _getEmailError(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: UIConstants.appOrange.withValues(alpha: 0.7),
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(
                    color: UIConstants.appOrange,
                    width: 2,
                  ),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmController,
              maxLength: 200,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: loc.profile_alternative_email_dialog_confirm,
                labelStyle: const TextStyle(color: Colors.white70),
                errorText: _getConfirmError(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: UIConstants.appOrange.withValues(alpha: 0.7),
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(
                    color: UIConstants.appOrange,
                    width: 2,
                  ),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            loc.cancel,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          onPressed: _isValid ? _onSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: UIConstants.appOrange,
            foregroundColor: Colors.black,
          ),
          child: Text(
            loc.profile_alternative_email_dialog_save,
          ),
        ),
      ],
    );
  }
}
