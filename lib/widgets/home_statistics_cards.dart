import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/app_localizations.dart';
import '../widgets/party_qr_code_dialog.dart' show Party, PartyQrCodeDialog;
import '../utils/role_dropdown_helper.dart';

class HomeUserStatisticsCard extends StatelessWidget {
  final int loginCount;
  final int totalWishes;
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  const HomeUserStatisticsCard({
    super.key,
    required this.loginCount,
    required this.totalWishes,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return cardBuilder(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.your_statistics,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            l.guest_home_stats_logins_line(loginCount),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            l.guest_home_stats_wishes_line(totalWishes),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class HomePartyInfoCard extends StatelessWidget {
  final Map<String, dynamic>? party;
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  const HomePartyInfoCard({
    super.key,
    required this.party,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final partyName = party?['party_name'] as String?;
    final partyCode = party?['party_code'] as String?;
    final startDate = party?['start_date'] as DateTime?;
    final endDate = party?['end_date'] as DateTime?;

    return cardBuilder(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.admin_stats_current_party,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.cyan,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(partyName ?? '', style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                      l.admin_stats_party_code_line(partyCode ?? ''),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              // QR-Code Button (nur wenn Party vorhanden ist)
              if (party != null && partyCode != null && partyName != null && startDate != null && endDate != null)
                IconButton(
                  icon: const Icon(Icons.qr_code, color: Colors.black),
                  onPressed: () async {
                    String? djLogoUrl;
                    String? profileImageUrl;
                    String? djEmail;
                    String? djPhone;
                    String? djAlternativeEmail;
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                        final userData = userDoc.data();
                        djLogoUrl = userData?['djLogoUrl'];
                        profileImageUrl = userData?['profileImageUrl'] ?? user.photoURL;
                        djEmail = user.email ?? userData?['email'] as String?;
                        djPhone = userData?['phoneNumber'] as String?;
                        if (userData?['useAlternativeEmail'] == true) {
                          djAlternativeEmail = userData?['alternativeEmail'] as String?;
                        }
                      }
                    } catch (_) {}

                    if (context.mounted) {
                      PartyQrCodeDialog.show(
                        context: context,
                        party: Party(
                          partyName: partyName!,
                          startDate: startDate!,
                          endDate: endDate!,
                          partyCode: partyCode,
                        ),
                        djName: FirebaseAuth.instance.currentUser?.displayName,
                        djLogoUrl: djLogoUrl,
                        profileImageUrl: profileImageUrl,
                        djEmail: djEmail,
                        djPhone: djPhone,
                        djAlternativeEmail: djAlternativeEmail,
                      );
                    }
                  },
                  tooltip: l.admin_stats_qr_tooltip,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class HomeVibesboxToggleCard extends StatelessWidget {
  final bool value;
  /// Null, wenn keine Party aktiv – dann ist der Switch deaktiviert (kein Absturz).
  final ValueChanged<bool>? onChanged;
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  const HomeVibesboxToggleCard({
    super.key,
    required this.value,
    this.onChanged,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return cardBuilder(
      context,
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l.admin_stats_vibesbox_status_title),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class HomeThresholdCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  const HomeThresholdCard({
    super.key,
    required this.controller,
    required this.onSubmitted,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return cardBuilder(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.admin_stats_duplicate_limit_percent)),
              SizedBox(
                width: 70,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => onSubmitted(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l.admin_duplicate_threshold_hint,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class HomeAdminRoleSwitcherCard extends StatelessWidget {
  final String? currentViewRole;
  final ValueChanged<String?>? onChanged;
  final bool isAdminUser;
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  const HomeAdminRoleSwitcherCard({
    super.key,
    required this.currentViewRole,
    required this.onChanged,
    required this.isAdminUser,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // Validiere den Wert und stelle sicher, dass er nie null ist (Fallback zu null für "Admin (Echt)")
    final validatedValue = RoleDropdownHelper.validateRoleValue(
      currentViewRole,
      includeAdmin: isAdminUser,
    );
    
    return cardBuilder(
      context,
      DropdownButtonFormField<String?>(
        key: ValueKey<String?>(validatedValue),
        initialValue: validatedValue,
        decoration: InputDecoration(labelText: l.admin_role_switcher_label),
        items: RoleDropdownHelper.getRoleDropdownItems(
          l: l,
          includeAdmin: isAdminUser,
        ),
        onChanged: onChanged,
      ),
    );
  }
}


