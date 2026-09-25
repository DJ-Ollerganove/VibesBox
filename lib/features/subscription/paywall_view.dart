import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../../services/subscription_sync_service.dart';
import '../../services/revenue_cat_bootstrap.dart';
import '../../services/user_service.dart';
import '../../services/dj_b2b_service.dart';
import '../../services/pending_referral_service.dart';
import '../../utils/ui_constants.dart';
import '../../utils/debug_log.dart';
import '../../pages/profile/widgets/profile_edit_dialogs.dart';
import '../../app_scaffold_messenger.dart';

Future<void> _openPaywallLegalUrl(BuildContext context, String url) async {
  try {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(content: Text(l.paywall_legal_url_open_failed)),
      );
    }
  } catch (e, st) {
    debugLog('Paywall legal URL open failed: $e\n$st');
    if (context.mounted) {
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(content: Text(l.paywall_legal_url_open_failed)),
      );
    }
  }
}

/// Hinweiszeile mit anklickbaren {terms}/{privacy}-Platzhaltern.
Widget _paywallLegalAcceptLine(BuildContext context, AppLocalizations l) {
  final terms = l.paywall_terms_link;
  final privacy = l.paywall_privacy_link;
  final template = l.paywall_legal_accept;
  final linkStyle = const TextStyle(
    color: Colors.white60,
    fontSize: 12,
    height: 1.4,
    decoration: TextDecoration.underline,
  );
  final baseStyle = const TextStyle(
    color: Colors.white54,
    fontSize: 12,
    height: 1.4,
  );

  InlineSpan linkSpan(String label, String url) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        onTap: () => _openPaywallLegalUrl(context, url),
        child: Text(label, style: linkStyle),
      ),
    );
  }

  final spans = <InlineSpan>[];
  var rest = template;
  while (rest.isNotEmpty) {
    final ti = rest.indexOf('{terms}');
    final pi = rest.indexOf('{privacy}');
    int next = -1;
    String? token;
    if (ti >= 0 && (pi < 0 || ti < pi)) {
      next = ti;
      token = '{terms}';
    } else if (pi >= 0) {
      next = pi;
      token = '{privacy}';
    }
    if (next < 0 || token == null) {
      spans.add(TextSpan(text: rest, style: baseStyle));
      break;
    }
    if (next > 0) {
      spans.add(TextSpan(text: rest.substring(0, next), style: baseStyle));
    }
    if (token == '{terms}') {
      spans.add(linkSpan(terms, AppConfig.termsOfUseUrl));
    } else {
      spans.add(linkSpan(privacy, AppConfig.privacyPolicyUrl));
    }
    rest = rest.substring(next + token.length);
  }

  return Text.rich(
    TextSpan(children: spans),
    textAlign: TextAlign.center,
  );
}

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

/// Ersparnis in Prozent gegenüber dem Monatsabo (nur Anzeige, Store-Preise).
int? paywallSavingsPercentVsMonthly({
  required Package? planPackage,
  required int planMonths,
  required Package? monthlyPackage,
}) {
  if (planPackage == null || monthlyPackage == null || planMonths <= 1) {
    return null;
  }
  final monthlyPrice = monthlyPackage.storeProduct.price;
  final planPrice = planPackage.storeProduct.price;
  if (monthlyPrice <= 0 || planPrice <= 0) return null;
  final planPerMonth = planPrice / planMonths;
  final savings = (1 - planPerMonth / monthlyPrice) * 100;
  final rounded = savings.round();
  return rounded > 0 ? rounded : null;
}

/// Formatierter Monatsäquivalent-Preis (Planpreis ÷ Monate) in Produktwährung.
String? paywallMonthlyEquivalentPrice({
  required Package? planPackage,
  required int planMonths,
  required Locale materialLocale,
  required Locale platformLocale,
}) {
  if (planPackage == null || planMonths <= 1) return null;
  final sp = planPackage.storeProduct;
  if (sp.price <= 0) return null;
  final perMonth = sp.price / planMonths;
  return _paywallFormatAmount(
    amount: perMonth,
    currencyCode: sp.currencyCode,
    materialLocale: materialLocale,
    platformLocale: platformLocale,
  );
}

String _paywallFormatAmount({
  required double amount,
  required String currencyCode,
  required Locale materialLocale,
  required Locale platformLocale,
}) {
  final displayLocale = _paywallDisplayLocale(materialLocale, platformLocale);
  final code = currencyCode.toUpperCase();
  final country = displayLocale.countryCode;
  final localeTag = country != null && country.isNotEmpty
      ? '${displayLocale.languageCode}_$country'
      : displayLocale.languageCode;
  try {
    return NumberFormat.currency(locale: localeTag, name: code).format(amount);
  } catch (_) {
    try {
      return NumberFormat.currency(name: code).format(amount);
    } catch (_) {
      return amount.toStringAsFixed(2);
    }
  }
}

bool _paywallPriceStringShowsEuro(String priceString) {
  return priceString.contains('€') || priceString.contains('\u20AC');
}

bool _paywallPriceStringLooksUsd(String priceString) {
  final t = priceString.trimLeft();
  return t.startsWith(r'$') || t.startsWith(r'US$');
}

bool _paywallPriceStringMatchesCurrency(String priceString, String currencyCode) {
  final code = currencyCode.toUpperCase();
  switch (code) {
    case 'EUR':
      return _paywallPriceStringShowsEuro(priceString);
    case 'USD':
      return _paywallPriceStringLooksUsd(priceString);
    case 'GBP':
      return priceString.contains('£');
    case 'CHF':
      return priceString.contains('CHF') || priceString.contains('Fr.');
    default:
      return true;
  }
}

/// Geräte-Region bevorzugen (iOS: oft `de_DE`), sonst App-Sprache.
Locale _paywallDisplayLocale(Locale materialLocale, Locale platformLocale) {
  final pc = platformLocale.countryCode;
  if (pc != null && pc.isNotEmpty) return platformLocale;
  return materialLocale;
}

String _paywallFormatNumericPrice(StoreProduct sp, Locale displayLocale) {
  return _paywallFormatAmount(
    amount: sp.price,
    currencyCode: sp.currencyCode,
    materialLocale: displayLocale,
    platformLocale: displayLocale,
  );
}

/// Store-Preis für die Paywall: immer in der **Produktwährung** ([StoreProduct.currencyCode]),
/// nie USD-Betrag mit €-Symbol (früherer iOS-Workaround).
///
/// iOS Sandbox/TestFlight kann USD liefern, der Kaufdialog zeigt trotzdem die korrekte
/// Storefront-Währung — keine manuelle „Umrechnung“ nach EUR.
String? paywallStorePriceForDisplay(
  Package? package,
  Locale materialLocale,
  Locale platformLocale,
) {
  if (package == null) return null;
  final sp = package.storeProduct;
  final ps = sp.priceString.trim();
  if (ps.isEmpty) {
    return _paywallFormatNumericPrice(sp, _paywallDisplayLocale(materialLocale, platformLocale));
  }
  if (_paywallPriceStringMatchesCurrency(ps, sp.currencyCode)) {
    return ps;
  }
  return _paywallFormatNumericPrice(sp, _paywallDisplayLocale(materialLocale, platformLocale));
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

      // Primär wie Android: getOfferings(). iOS hatte früher nur
      // syncAttributesAndOfferingsIfNeeded — bei RC 10 oft leere Packages.
      Offerings offerings = await Purchases.getOfferings();
      var offering = _pickOfferingWithPackages(offerings);

      if ((offering == null || offering.availablePackages.isEmpty) &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS) {
        debugLog(
          'Paywall iOS: getOfferings leer '
          '(current=${offerings.current?.identifier} '
          'all=${offerings.all.keys.toList()} packages='
          '${offerings.current?.availablePackages.length ?? 0}) — Retry',
        );
        try {
          await Purchases.invalidateCustomerInfoCache();
        } catch (e) {
          debugLog('Paywall: invalidateCustomerInfoCache: $e');
        }
        try {
          await Purchases.syncPurchases();
        } catch (e, st) {
          debugLog('⚠️ Paywall: syncPurchases (iOS Retry): $e\n$st');
        }
        try {
          offerings = await Purchases.syncAttributesAndOfferingsIfNeeded();
          offering = _pickOfferingWithPackages(offerings);
        } catch (e, st) {
          debugLog('⚠️ Paywall: syncAttributesAndOfferingsIfNeeded: $e\n$st');
        }
        if (offering == null || offering.availablePackages.isEmpty) {
          offerings = await Purchases.getOfferings();
          offering = _pickOfferingWithPackages(offerings);
        }
      }

      if (offering == null) {
        throw StateError('no_offering');
      }
      final resolvedOffering = offering;

      // Leere Produktliste: klarer Fehler statt leerer Plan-Karten.
      if (resolvedOffering.availablePackages.isEmpty) {
        debugLog(
          'Paywall: Offering "${resolvedOffering.identifier}" hat keine Packages '
          '(allKeys=${offerings.all.keys.toList()})',
        );
        // Diagnose: RC kennt die IDs, StoreKit liefert sie oft nicht → ASC/Sandbox.
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          try {
            const iosProductIds = <String>[
              'premium_monat',
              'premium_quartal',
              'premium_halbjahr',
              'premium_jahr',
            ];
            final products = await Purchases.getProducts(
              iosProductIds,
              productCategory: ProductCategory.subscription,
            );
            debugLog(
              'Paywall iOS getProducts: erwartet=${iosProductIds.length} '
              'gefunden=${products.length} '
              'ids=${products.map((p) => p.identifier).toList()}',
            );
          } catch (e, st) {
            debugLog('Paywall iOS getProducts Diagnose: $e\n$st');
          }
        }
        if (!mounted) return;
        final l = AppLocalizations.of(context)!;
        setState(() {
          _offering = null;
          _error = l.paywall_products_unavailable;
          _loading = false;
        });
        return;
      }

      if (kDebugMode) {
        for (final pkg in resolvedOffering.availablePackages) {
          final sp = pkg.storeProduct;
          debugLog(
            '💳 Paywall package=${pkg.identifier} '
            'currencyCode=${sp.currencyCode} priceString=${sp.priceString} price=${sp.price}',
          );
        }
      }

      CustomerInfo? customerInfo;
      try {
        customerInfo = await Purchases.getCustomerInfo();
      } catch (e, st) {
        debugLog('⚠️ Paywall: getCustomerInfo fehlgeschlagen: $e\n$st');
      }

      if (!mounted) return;
      setState(() {
        _offering = resolvedOffering;
        _customerInfo = customerInfo;
        _selected = _pickDefaultPackage(resolvedOffering);
        _loading = false;
      });
    } on PlatformException catch (e, st) {
      debugLog('Paywall load PlatformException: $e\n$st');
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      final code = PurchasesErrorHelper.getErrorCode(e);
      // configurationError oft StoreKit/ASC — gleiche Nutzer-Meldung wie leere Liste
      final msg = switch (code) {
        PurchasesErrorCode.productNotAvailableForPurchaseError ||
        PurchasesErrorCode.storeProblemError ||
        PurchasesErrorCode.configurationError ||
        PurchasesErrorCode.unexpectedBackendResponseError =>
          l.paywall_products_unavailable,
        _ => l.paywall_offering_load_error,
      };
      setState(() {
        _offering = null;
        _error = msg;
        _loading = false;
      });
    } catch (e, st) {
      debugLog('Paywall load error: $e\n$st');
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      final emptyProducts = e is StateError && e.message == 'no_offering';
      setState(() {
        _offering = null;
        _error = emptyProducts
            ? l.paywall_products_unavailable
            : l.paywall_offering_load_error;
        _loading = false;
      });
    }
  }

  /// Wählt ein Offering mit Store-Packages. Bevorzugt [_offeringId], sonst current,
  /// sonst irgendein Offering mit Packages — nie ein leeres „default“ vor einem vollen current.
  Offering? _pickOfferingWithPackages(Offerings offerings) {
    final named = offerings.all[_offeringId];
    if (named != null && named.availablePackages.isNotEmpty) return named;

    final current = offerings.current;
    if (current != null && current.availablePackages.isNotEmpty) return current;

    for (final o in offerings.all.values) {
      if (o.availablePackages.isNotEmpty) return o;
    }
    return current ?? named;
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

  /// Werbercode vor Direktkauf serverseitig speichern (ohne Trial),
  /// damit Webhook den Werber-Bonus finden kann.
  Future<bool> _linkPendingB2bReferralForPurchase() async {
    final pending = await PendingReferralService.instance.peekCode();
    if (pending == null) return true;

    final already = DjB2bService.normalizeCode(
      UserScope.userOf(context)?.referredByCode,
    );
    if (already != null) {
      await PendingReferralService.instance.clear();
      return true;
    }

    try {
      await DjB2bService.instance.redeemCode(
        pending,
        activateTrial: false,
        source: 'paywall_purchase',
      );
      await PendingReferralService.instance.clear();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await UserService().refreshSessionProStatus(uid);
      }
      return true;
    } on FirebaseFunctionsException catch (e) {
      final msg = (e.message ?? '').toLowerCase();
      // Bereits verknüpft → Kauf fortsetzen.
      if (e.code == 'failed-precondition' && msg.contains('already redeemed')) {
        await PendingReferralService.instance.clear();
        return true;
      }
      if (!mounted) return false;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(content: Text(l.paywall_b2b_code_invalid)),
      );
      DjB2bService.logFunctionsError(e, 'redeem before purchase');
      return false;
    } catch (e) {
      if (!mounted) return false;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(content: Text('${l.paywall_b2b_code_invalid} $e')),
      );
      return false;
    }
  }

  Future<void> _buySelected() async {
    final pkg = _selected;
    if (pkg == null) return;

    setState(() => _busy = true);
    try {
      // Gültiger Pending-Code: vor Store-Kauf am User + Werber-Liste speichern.
      final linked = await _linkPendingB2bReferralForPurchase();
      if (!linked) return;

      // Android: Google Play Offers nutzen – Option mit freePhase an RevenueCat übergeben.
      final CustomerInfo info;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final optionWithFree = getOptionWithFreePhase(pkg.storeProduct);
        if (optionWithFree != null) {
          info = (await Purchases.purchase(
            PurchaseParams.subscriptionOption(optionWithFree),
          ))
              .customerInfo;
        } else {
          info = (await Purchases.purchase(PurchaseParams.package(pkg)))
              .customerInfo;
        }
      } else {
        info = (await Purchases.purchase(PurchaseParams.package(pkg)))
            .customerInfo;
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
              showVibesSnackBar(context, 
                SnackBar(content: Text('${l.paywall_purchase_sync_failed} $e')),
              );
            }
            return; // Don't close if sync fails
          }
        }

        // Erfolgs-Snackbar anzeigen – das Fenster schließt der Profil-Controller (ValueListenableBuilder)
        if (context.mounted) {
          final l = AppLocalizations.of(context)!;
          showVibesSnackBar(context, 
            SnackBar(
              content: Text(l.paywall_pro_active),
              duration: const Duration(milliseconds: 1500),
            ),
          );
        }
      } else {
        final l = AppLocalizations.of(context)!;
        showVibesSnackBar(context, 
          SnackBar(content: Text(l.paywall_purchase_verifying)),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      // User cancelled is a specific error code usually, but we just show message
      final code = PurchasesErrorHelper.getErrorCode(e);
      final isCancelled = code == PurchasesErrorCode.purchaseCancelledError;
      if (!isCancelled) {
        final l = AppLocalizations.of(context)!;
        final msg = switch (code) {
          PurchasesErrorCode.productNotAvailableForPurchaseError ||
          PurchasesErrorCode.storeProblemError ||
          PurchasesErrorCode.configurationError =>
            l.paywall_products_unavailable,
          _ => '${l.paywall_purchase_failed} ${e.message ?? ''}'.trim(),
        };
        showVibesSnackBar(
          context,
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(context, 
        SnackBar(content: Text('${l.paywall_purchase_failed} $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startTwoDayTrial() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _busy) return;

    final l = AppLocalizations.of(context)!;
    final pendingCode = await PendingReferralService.instance.peekCode();
    final alreadyReferred = DjB2bService.normalizeCode(
      UserScope.userOf(context)?.referredByCode,
    );
    final hasB2b = pendingCode != null || alreadyReferred != null;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ProfileEditDialogs.styledDialog(
        context: dialogContext,
        title: hasB2b ? l.paywall_trial_confirm_title_b2b : l.paywall_trial_confirm_title,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasB2b
                  ? l.paywall_trial_confirm_message_b2b
                  : l.paywall_trial_confirm_message_no_b2b,
              style: const TextStyle(color: Colors.white70, height: 1.45),
            ),
            const SizedBox(height: 12),
            Text(
              l.paywall_trial_no_subscription_hint,
              style: const TextStyle(
                color: UIConstants.appOrange,
                height: 1.4,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!hasB2b) ...[
              const SizedBox(height: 12),
              Text(
                l.paywall_trial_b2b_hint,
                style: const TextStyle(color: Colors.white54, height: 1.4, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext, rootNavigator: true).pop(false);
            },
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext, rootNavigator: true).pop(true);
            },
            style: TextButton.styleFrom(
              foregroundColor: UIConstants.appOrange,
            ),
            child: Text(
              hasB2b ? l.paywall_start_trial_button_b2b : l.paywall_start_trial_button,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await DjB2bService.instance.activateTrial(
        b2bCode: pendingCode ?? alreadyReferred,
      );
      await PendingReferralService.instance.clear();
      await UserService().refreshSessionProStatus(uid);
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(context, 
        SnackBar(
          content: Text(
            hasB2b ? l.trial_activated_snackbar_b2b : l.trial_activated_snackbar,
          ),
          backgroundColor: const Color(0xFFE6A817),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      final msg = _paywallTrialErrorMessage(l, e);
      showVibesSnackBar(context, 
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _paywallTrialErrorMessage(AppLocalizations l, Object e) {
    if (e is FirebaseFunctionsException) {
      final m = (e.message ?? '').toLowerCase();
      final code = e.code.toLowerCase();
      if (code == 'invalid-argument' ||
          code == 'not-found' ||
          m.contains('invalid') ||
          m.contains('not found') ||
          m.contains('self-referral') ||
          m.contains('already redeemed')) {
        return l.paywall_b2b_code_invalid;
      }
      return '${l.paywall_trial_failed} ${e.message ?? e.code}'.trim();
    }
    return '${l.paywall_trial_failed} $e';
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
      showVibesSnackBar(context, 
        SnackBar(
          content: Text(
            isPro ? l.paywall_restore_success_pro : l.paywall_restore_success_no_pro,
          ),
        ),
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(context, 
        SnackBar(content: Text('${l.paywall_restore_failed} ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(context, 
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
      _Plan(label: l.paywall_plan_month, package: monthly, planMonths: 1),
      _Plan(label: l.paywall_plan_quarter, package: quarter, planMonths: 3),
      _Plan(label: l.paywall_plan_halfyear, package: half, planMonths: 6),
      _Plan(
        label: l.paywall_plan_year,
        package: annual,
        planMonths: 12,
        recommended: true,
      ),
    ];

    Widget planCard(_Plan plan) {
      final materialLocale = Localizations.localeOf(context);
      final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final savingsPercent = paywallSavingsPercentVsMonthly(
        planPackage: plan.package,
        planMonths: plan.planMonths,
        monthlyPackage: monthly,
      );
      final monthlyEquiv = paywallMonthlyEquivalentPrice(
        planPackage: plan.package,
        planMonths: plan.planMonths,
        materialLocale: materialLocale,
        platformLocale: platformLocale,
      );
      return _PlanCard(
        label: plan.label,
        package: plan.package,
        trialText: plan.package != null
            ? getTrialDisplayString(l, plan.package!.storeProduct)
            : null,
        monthlyPriceText: monthlyEquiv != null
            ? l.paywall_per_month_price(monthlyEquiv)
            : null,
        savingsText: savingsPercent != null
            ? l.paywall_save_up_to_percent(savingsPercent)
            : null,
        selected: selected?.identifier == plan.package?.identifier,
        recommended: plan.recommended,
        onTap: plan.package == null ? () {} : () => onSelect(plan.package!),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Gratis-Test nur, wenn noch nie genutzt (inkl. Trennlinie).
        if (trialAvailable) ...[
          _PaywallTrialSection(
            busy: busy,
            onStartTrial: onStartTrial,
          ),
          const SizedBox(height: 24),
        ],

        Text(
          l.subscribeToVibesBoxPro,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Grid Layout (2x2)
        Row(
          children: [
            Expanded(child: planCard(packages[0])),
            const SizedBox(width: 12),
            Expanded(child: planCard(packages[1])),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: planCard(packages[2])),
            const SizedBox(width: 12),
            Expanded(child: planCard(packages[3])),
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

        const SizedBox(height: 10),
        Text(
          l.paywall_subscription_auto_renew_hint,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
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

        const SizedBox(height: 12),
        _paywallLegalAcceptLine(context, l),
      ],
    );
  }
}

/// Gratis-Test-Block inkl. optionalem DJ-B2B-Werbercode (Format + Lookup + eigener Code).
class _PaywallTrialSection extends StatefulWidget {
  const _PaywallTrialSection({
    required this.busy,
    required this.onStartTrial,
  });

  final bool busy;
  final VoidCallback onStartTrial;

  @override
  State<_PaywallTrialSection> createState() => _PaywallTrialSectionState();
}

class _PaywallTrialSectionState extends State<_PaywallTrialSection> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _validB2b = false;
  bool _showInvalid = false;
  bool _locked = false;
  bool _checking = false;
  int _validateGen = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = UserScope.userOf(context);
    final already = DjB2bService.normalizeCode(user?.referredByCode);
    if (already != null) {
      if (!mounted) return;
      setState(() {
        // Feld zeigt nur die 6 Ziffern; „DJ“ steht als Prefix.
        _controller.text = DjB2bService.digitsOnly(already);
        _validB2b = true;
        _locked = true;
        _showInvalid = false;
      });
      await PendingReferralService.instance.saveCode(already);
      return;
    }
    final pending = await PendingReferralService.instance.peekCode();
    if (!mounted) return;
    if (pending != null) {
      _controller.text = DjB2bService.digitsOnly(pending);
      await _validate(_controller.text, force: true);
    }
  }

  Future<void> _onCodeChanged(String raw) async {
    final digits = DjB2bService.digitsOnly(raw);
    if (digits != raw) {
      _controller.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }
    // Sofort Fehler zurücksetzen — erneuter Versuch bleibt möglich.
    if (_showInvalid) {
      setState(() => _showInvalid = false);
    }
    await _validate(digits);
  }

  Future<void> _validate(String raw, {bool force = false}) async {
    if (_locked) return;
    final gen = ++_validateGen;
    final digits = DjB2bService.digitsOnly(raw);

    if (digits.isEmpty) {
      await PendingReferralService.instance.clear();
      if (!mounted || gen != _validateGen) return;
      setState(() {
        _validB2b = false;
        _showInvalid = false;
        _checking = false;
      });
      return;
    }

    final normalized = DjB2bService.normalizeCode(digits);
    if (normalized == null) {
      // Während Tippens (noch nicht 6 Ziffern) keinen Fehler / Button bleibt nutzbar (2 Tage).
      final showErr = digits.length >= 6 || force;
      if (!mounted || gen != _validateGen) return;
      setState(() {
        _validB2b = false;
        _showInvalid = showErr;
        _checking = false;
      });
      if (showErr) await PendingReferralService.instance.clear();
      return;
    }

    final own = DjB2bService.normalizeCode(
      UserScope.userOf(context)?.djB2bCode,
    );
    if (own != null && own == normalized) {
      await PendingReferralService.instance.clear();
      if (!mounted || gen != _validateGen) return;
      setState(() {
        _validB2b = false;
        _showInvalid = true;
        _checking = false;
      });
      return;
    }

    setState(() => _checking = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('referral_codes')
          .doc(normalized)
          .get();
      if (!mounted || gen != _validateGen) return;
      final uid = snap.data()?['uid'];
      final ok = snap.exists &&
          uid is String &&
          uid.trim().isNotEmpty &&
          uid != FirebaseAuth.instance.currentUser?.uid;
      if (ok) {
        await PendingReferralService.instance.saveCode(normalized);
      } else {
        await PendingReferralService.instance.clear();
      }
      if (!mounted || gen != _validateGen) return;
      setState(() {
        _validB2b = ok;
        _showInvalid = !ok;
        _checking = false;
      });
    } catch (e, st) {
      debugLog('Paywall B2B code lookup failed: $e\n$st');
      await PendingReferralService.instance.clear();
      if (!mounted || gen != _validateGen) return;
      setState(() {
        _validB2b = false;
        _showInvalid = true;
        _checking = false;
      });
    }
  }

  InputDecoration _decoration(AppLocalizations l) {
    const orange = UIConstants.appOrange;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: orange, width: 1.5),
    );
    final errBorder = border.copyWith(
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    );
    return InputDecoration(
      labelText: l.paywall_b2b_code_label,
      hintText: '123456',
      labelStyle: const TextStyle(color: orange),
      floatingLabelStyle: const TextStyle(color: orange),
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: const Icon(Icons.card_giftcard_outlined, color: orange),
      // Intern immer DJ###### — Nutzer tippt nur die 6 Ziffern (auch AR/ZH-Tastatur).
      prefixText: 'DJ',
      prefixStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
      suffixIcon: _checking
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: UIConstants.appOrange,
                ),
              ),
            )
          : null,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: orange, width: 2),
      ),
      errorBorder: errBorder,
      focusedErrorBorder: errBorder.copyWith(
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      errorText: _showInvalid ? l.paywall_b2b_code_invalid : null,
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
      counterText: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final trialLabel =
        _validB2b ? l.paywall_start_trial_button_b2b : l.paywall_start_trial_button;
    // Nur bei nachgewiesen ungültigem Code aus — Feld bleibt editierbar für neuen Versuch.
    final trialEnabled =
        !widget.busy && !_checking && !_showInvalid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            enabled: !widget.busy && !_locked,
            maxLength: 6,
            keyboardType: TextInputType.number,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
            decoration: _decoration(l),
            onChanged: _onCodeChanged,
            onEditingComplete: () {
              _validate(_controller.text, force: true);
              _focus.unfocus();
            },
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: trialEnabled ? widget.onStartTrial : null,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: UIConstants.appOrange,
            disabledForegroundColor: UIConstants.appOrange.withValues(alpha: 0.45),
            side: const BorderSide(color: UIConstants.appOrange, width: 2),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          child: Text(trialLabel),
        ),
        const SizedBox(height: 8),
        Text(
          _validB2b
              ? l.paywall_promo_access_hint_b2b
              : l.paywall_promo_access_hint,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (!_validB2b) ...[
          const SizedBox(height: 8),
          Text(
            l.paywall_trial_b2b_hint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(
          color: UIConstants.appOrange,
          thickness: 1,
          height: 1,
        ),
      ],
    );
  }
}

class _Plan {
  _Plan({
    required this.label,
    required this.package,
    this.recommended = false,
    this.planMonths = 1,
  });
  final String label;
  final Package? package;
  final bool recommended;
  final int planMonths;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.package,
    this.trialText,
    this.monthlyPriceText,
    this.savingsText,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  final String label;
  final Package? package;
  /// Testphase aus subscriptionOptions/freePhase (z. B. "4 Tage kostenlos").
  final String? trialText;
  /// Umgerechneter Monatspreis bei Quartal/Halbjahr/Jahr.
  final String? monthlyPriceText;
  final String? savingsText;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final materialLocale = Localizations.localeOf(context);
    final platformLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final price = paywallStorePriceForDisplay(
      package,
      materialLocale,
      platformLocale,
    );
    // Schwarzer Hintergrund, orangefarbener Rahmen (stärker bei Auswahl).
    final borderColor = UIConstants.appOrange;
    final bg = Colors.black;

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
            width: selected ? 2.5 : 1.5,
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
            if (monthlyPriceText != null && monthlyPriceText!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                monthlyPriceText!,
                style: TextStyle(
                  color: selected ? Colors.white70 : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (savingsText != null && savingsText!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                savingsText!,
                style: TextStyle(
                  color: selected ? UIConstants.appGreen : UIConstants.appGreen.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
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
