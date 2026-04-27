import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../l10n/app_localizations.dart';
import '../../services/subscription_sync_service.dart';
import '../../services/revenue_cat_bootstrap.dart';
import '../../services/user_service.dart';
import '../../utils/ui_constants.dart';
import '../../utils/debug_log.dart';

// --- Google Play Offers (subscriptionOptions/freePhase) statt introductoryPrice ---

/// Sucht in [storeProduct].subscriptionOptions die Option mit freePhase.
SubscriptionOption? getOptionWithFreePhase(StoreProduct storeProduct) {
  final options = storeProduct.subscriptionOptions;
  if (options == null || options.isEmpty) return null;
  for (final opt in options) {
    if (opt.freePhase != null) return opt;
  }
  return null;
}

/// Formatiert die Dauer einer freePhase für die Anzeige (z. B. P4D → lokalisierte Dauer).
String? formatFreePhaseDuration(AppLocalizations l, Period? period) {
  if (period == null) return null;
  final v = period.value;
  if (v <= 0) return null;
  switch (period.unit) {
    case PeriodUnit.day:
      return v == 1 ? l.period_day_singular : l.period_days(v);
    case PeriodUnit.week:
      return v == 1 ? l.period_week_singular : l.period_weeks(v);
    case PeriodUnit.month:
      return v == 1 ? l.period_month_singular : l.period_months(v);
    case PeriodUnit.year:
      return v == 1 ? l.period_year_singular : l.period_years(v);
    case PeriodUnit.unknown:
      return period.iso8601.isNotEmpty ? period.iso8601 : null;
  }
}

/// Liefert den Anzeige-Text für die Testphase aus subscriptionOptions/freePhase.
String? getTrialDisplayString(AppLocalizations l, StoreProduct storeProduct) {
  final option = getOptionWithFreePhase(storeProduct);
  final period = option?.freePhase?.billingPeriod;
  final text = formatFreePhaseDuration(l, period);
  if (text == null) return null;
  return l.paywall_free_phase_label.replaceAll('{duration}', text);
}

class PaywallView extends StatefulWidget {
  const PaywallView({super.key});

  @override
  State<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends State<PaywallView> {
  static const String _offeringId = 'default';
  static const String _proEntitlementId = 'vibesbox pro';

  bool _loading = true;
  String? _error;

  Offering? _offering;
  CustomerInfo? _customerInfo;

  Package? _selected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    _load();
  }

  @override
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdated);
    super.dispose();
  }

  void _onCustomerInfoUpdated(CustomerInfo info) {
    if (!mounted) return;
    setState(() => _customerInfo = info);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!kIsWeb) {
        await RevenueCatBootstrap.ensureConfigured();
      }
      final offerings = await Purchases.getOfferings();

      final offering = offerings.all[_offeringId] ?? offerings.current;
      if (offering == null) {
        throw StateError('no_offering');
      }

      final customerInfo = await Purchases.getCustomerInfo();

      if (!mounted) return;
      setState(() {
        _offering = offering;
        _customerInfo = customerInfo;
        _selected = _pickDefaultPackage(offering);
        _loading = false;
      });
    } catch (e, st) {
      debugLog('Paywall load error: $e\n$st');
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      setState(() {
        _error = l.paywall_offering_load_error;
        _loading = false;
      });
    }
  }

  Package? _pickDefaultPackage(Offering offering) {
    // Empfehlung: Jahres-Abo vorselektieren, falls vorhanden.
    final annual = _findPackage(offering, PackageType.annual);
    if (annual != null) return annual;
    if (offering.availablePackages.isNotEmpty) return offering.availablePackages.first;
    return null;
  }

  Package? _findPackage(Offering offering, PackageType type) {
    for (final p in offering.availablePackages) {
      if (p.packageType == type) return p;
    }

    // Fallback (z.B. Custom Package IDs): heuristisch über Identifier.
    final needles = switch (type) {
      PackageType.monthly => const ['month', 'monat'],
      PackageType.threeMonth => const ['3', 'quarter', 'quart', '3m'],
      PackageType.sixMonth => const ['6', 'half', 'halb', '6m'],
      PackageType.annual => const ['year', 'annual', 'jahr', '12'],
      _ => const <String>[],
    };
    for (final p in offering.availablePackages) {
      final id = (p.identifier).toLowerCase();
      if (needles.any((n) => id.contains(n))) return p;
    }
    return null;
  }

  bool _isProActive(CustomerInfo? info) {
    if (info == null) return false;
    final byAll = info.entitlements.all[_proEntitlementId]?.isActive == true;
    if (byAll) return true;
    // toleranter Fallback, falls du das Entitlement in RevenueCat ohne Leerzeichen benannt hast
    final byAlt = info.entitlements.all[_proEntitlementId.replaceAll(' ', '_')]?.isActive == true;
    return byAlt;
  }

  Future<void> _buySelected() async {
    final pkg = _selected;
    if (pkg == null) return;

    setState(() => _busy = true);
    try {
      // Android: Google Play Offers nutzen – Option mit freePhase an RevenueCat übergeben.
      CustomerInfo info;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final optionWithFree = getOptionWithFreePhase(pkg.storeProduct);
        if (optionWithFree != null) {
          info = await Purchases.purchaseSubscriptionOption(optionWithFree);
        } else {
          info = await Purchases.purchasePackage(pkg);
        }
      } else {
        info = await Purchases.purchasePackage(pkg);
      }
      // Security-Konzept #2: Nach Kauf nicht "lokal freischalten",
      // sondern CustomerInfo (RevenueCat) auswerten.

      final isPro = _isProActive(info);
      if (!mounted) return;
      setState(() => _customerInfo = info);

      if (isPro) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          try {
            await SubscriptionSyncService.syncSubscriptionStatus(uid);
            debugLog('🔥 Paywall: Sync abgeschlossen');
          } catch (e) {
            debugLog('⚠️ Sync failed after purchase: $e');
            if (mounted) {
              final l = AppLocalizations.of(context)!;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${l.paywall_purchase_sync_failed} $e')),
              );
            }
            return; // Don't close if sync fails
          }
        }

        // Erfolgs-Snackbar anzeigen – das Fenster schließt der Profil-Controller (ValueListenableBuilder)
        if (context.mounted) {
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.paywall_pro_active),
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
      } else {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.paywall_purchase_verifying)),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      // User cancelled is a specific error code usually, but we just show message
      final isCancelled = PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError;
      if (!isCancelled) {
        final l = AppLocalizations.of(context)!;
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l.paywall_purchase_failed} ${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.paywall_purchase_failed} $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startTwoDayTrial() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      await SubscriptionSyncService.activateTwoDayTrial(uid);
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.trial_activated_snackbar),
          backgroundColor: const Color(0xFFE6A817),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.paywall_trial_failed} $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      if (!kIsWeb) {
        await RevenueCatBootstrap.ensureConfigured();
      }
      // Security-Konzept #3: Restore + Sync (Webhook-/Server-Flow vorbereitet).
      // In Produktion: Entitlement-Änderungen über RevenueCat Webhooks (Backend/Cloud Functions)
      // weiterverarbeiten – keine rein lokalen Freischaltungen.
      await Purchases.syncPurchases();
      final info = await Purchases.restorePurchases();

      if (!mounted) return;
      setState(() => _customerInfo = info);

      final isPro = _isProActive(info);
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPro ? l.paywall_restore_success_pro : l.paywall_restore_success_no_pro,
          ),
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.paywall_restore_failed} ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l.paywall_restore_failed} $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final proActive = _isProActive(_customerInfo);
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: UIConstants.djShellPageBackground,
      appBar: AppBar(
        title: Text(l.vibesbox_pro),
        backgroundColor: UIConstants.appBarBackgroundColor,
        foregroundColor: UIConstants.appBarForegroundColor,
        iconTheme: UIConstants.appBarIconTheme,
        titleTextStyle: UIConstants.appBarTitleTextStyle,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: UIConstants.appBarIconColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                UIConstants.bgGradientStart,
                UIConstants.bgGradientEnd,
              ],
            ),
            border: Border.all(
              color: UIConstants.appOrange,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: UIConstants.appOrange))
                : _error != null
                    ? _ErrorState(
                        error: _error!,
                        onRetry: _load,
                      )
                    : _offering == null
                        ? _ErrorState(
                            error: l.paywall_offering_load_error,
                            onRetry: _load,
                          )
                        : _Content(
                            offering: _offering!,
                            selected: _selected,
                            proActive: proActive,
                            busy: _busy,
                            trialAvailable: UserScope.userOf(context)?.trialUsed != true,
                            onSelect: (p) => setState(() => _selected = p),
                            onBuy: _buySelected,
                            onStartTrial: _startTwoDayTrial,
                            onRestore: _restore,
                            findPackage: _findPackage,
                          ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.offering,
    required this.selected,
    required this.proActive,
    required this.busy,
    required this.trialAvailable,
    required this.onSelect,
    required this.onBuy,
    required this.onStartTrial,
    required this.onRestore,
    required this.findPackage,
  });

  final Offering offering;
  final Package? selected;
  final bool proActive;
  final bool busy;
  final bool trialAvailable;
  final ValueChanged<Package> onSelect;
  final VoidCallback onBuy;
  final VoidCallback onStartTrial;
  final VoidCallback onRestore;
  final Package? Function(Offering offering, PackageType type) findPackage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final monthly = findPackage(offering, PackageType.monthly);
    final quarter = findPackage(offering, PackageType.threeMonth);
    final half = findPackage(offering, PackageType.sixMonth);
    final annual = findPackage(offering, PackageType.annual);

    final packages = <_Plan>[
      _Plan(label: l.paywall_plan_month, package: monthly),
      _Plan(label: l.paywall_plan_quarter, package: quarter),
      _Plan(label: l.paywall_plan_halfyear, package: half),
      _Plan(label: l.paywall_plan_year, package: annual, recommended: true),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        Column(
          children: [
            Text(
              l.paywall_choose_plan_title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),

        // Grid Layout (2x2)
        Row(
          children: [
            Expanded(
              child: _PlanCard(
                label: packages[0].label,
                package: packages[0].package,
                trialText: packages[0].package != null
                    ? getTrialDisplayString(l, packages[0].package!.storeProduct)
                    : null,
                selected: selected?.identifier == packages[0].package?.identifier,
                recommended: packages[0].recommended,
                onTap: packages[0].package == null ? () {} : () => onSelect(packages[0].package!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlanCard(
                label: packages[1].label,
                package: packages[1].package,
                trialText: packages[1].package != null
                    ? getTrialDisplayString(l, packages[1].package!.storeProduct)
                    : null,
                selected: selected?.identifier == packages[1].package?.identifier,
                recommended: packages[1].recommended,
                onTap: packages[1].package == null ? () {} : () => onSelect(packages[1].package!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PlanCard(
                label: packages[2].label,
                package: packages[2].package,
                trialText: packages[2].package != null
                    ? getTrialDisplayString(l, packages[2].package!.storeProduct)
                    : null,
                selected: selected?.identifier == packages[2].package?.identifier,
                recommended: packages[2].recommended,
                onTap: packages[2].package == null ? () {} : () => onSelect(packages[2].package!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlanCard(
                label: packages[3].label,
                package: packages[3].package,
                trialText: packages[3].package != null
                    ? getTrialDisplayString(l, packages[3].package!.storeProduct)
                    : null,
                selected: selected?.identifier == packages[3].package?.identifier,
                recommended: packages[3].recommended,
                onTap: packages[3].package == null ? () {} : () => onSelect(packages[3].package!),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        if (proActive)
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _StatusPill(
              text: l.paywall_status_active,
              color: Colors.green,
            ),
          ),

        if (trialAvailable) ...[
          OutlinedButton(
            onPressed: busy ? null : onStartTrial,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: UIConstants.appOrange,
              side: const BorderSide(color: UIConstants.appOrange, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            child: Text(l.paywall_start_trial_button),
          ),
          const SizedBox(height: 12),
        ],

        ElevatedButton(
          onPressed: busy || selected == null ? null : onBuy,
          style: ElevatedButton.styleFrom(
            backgroundColor: UIConstants.appOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          child: Text(busy ? l.paywall_pay_one_moment : l.paywall_pay_button),
        ),
        
        const SizedBox(height: 12),
        
        Center(
          child: TextButton(
            onPressed: busy ? null : onRestore,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
            ),
            child: Text(l.paywall_restore_purchases),
          ),
        ),
      ],
    );
  }
}

class _Plan {
  _Plan({required this.label, required this.package, this.recommended = false});
  final String label;
  final Package? package;
  final bool recommended;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.package,
    this.trialText,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final String label;
  final Package? package;
  /// Testphase aus subscriptionOptions/freePhase (z. B. "4 Tage kostenlos").
  final String? trialText;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final price = package?.storeProduct.priceString;
    final borderColor = selected ? UIConstants.appOrange : Colors.white12;
    // Leichte Orange-Füllung bei Auswahl
    final bg = selected 
        ? UIConstants.appOrange.withValues(alpha: 0.15) 
        : Colors.white.withValues(alpha: 0.05);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 110),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor, 
            width: selected ? 2 : 1
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (recommended)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: UIConstants.appOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l.paywall_tip_badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              price ?? '–',
              style: TextStyle(
                color: selected ? UIConstants.appOrange : Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (trialText != null && trialText!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                trialText!,
                style: TextStyle(
                  color: selected ? Colors.white70 : Colors.white54,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              l.paywall_load_error_title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: UIConstants.appOrange,
                foregroundColor: Colors.white,
              ),
              child: Text(l.retry_button),
            ),
          ],
        ),
      ),
    );
  }
}
