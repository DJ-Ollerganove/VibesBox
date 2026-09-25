import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/pro_history_model.dart';

enum PaymentStoreKind {
  apple,
  googlePlay,
  macAppStore,
  adminGift,
  adminRevoke,
  genericStore,
  unknown,
}

class PaymentStoreDisplay {
  const PaymentStoreDisplay({
    required this.kind,
    required this.label,
    this.icon,
    this.iconColor,
  });

  final PaymentStoreKind kind;
  final String label;
  final IconData? icon;
  final Color? iconColor;
}

/// Store aus History-Dokument (RevenueCat: `store` oder `eventData.store`).
String? resolvePaymentStoreCode(Map<String, dynamic> data) {
  final direct = (data['store'] as String?)?.trim();
  if (direct != null && direct.isNotEmpty) return direct.toUpperCase();

  final eventData = data['eventData'];
  if (eventData is Map) {
    final nested = (eventData['store'] as String?)?.trim();
    if (nested != null && nested.isNotEmpty) return nested.toUpperCase();
  }

  final source = (data['source'] as String?)?.trim().toUpperCase();
  if (source == ProHistorySource.applePurchase) return 'APP_STORE';
  if (source == ProHistorySource.googlePurchase) return 'PLAY_STORE';
  return null;
}

PaymentStoreDisplay resolvePaymentStoreDisplay(
  Map<String, dynamic> data,
  AppLocalizations l,
) {
  final source = (data['source'] as String?)?.trim().toUpperCase();
  if (source == 'ADMIN_GIFT') {
    return PaymentStoreDisplay(
      kind: PaymentStoreKind.adminGift,
      label: l.vibesbox_pro_life,
      icon: Icons.card_giftcard_outlined,
      iconColor: Colors.greenAccent,
    );
  }
  if (source == 'ADMIN_REVOKE') {
    return PaymentStoreDisplay(
      kind: PaymentStoreKind.adminRevoke,
      label: l.pro_life_revoked,
      icon: Icons.block_outlined,
      iconColor: Colors.white54,
    );
  }

  final store = resolvePaymentStoreCode(data);
  switch (store) {
    case 'APP_STORE':
      return PaymentStoreDisplay(
        kind: PaymentStoreKind.apple,
        label: l.payment_source_apple_store,
        icon: FontAwesomeIcons.apple,
        iconColor: Colors.white,
      );
    case 'MAC_APP_STORE':
      return PaymentStoreDisplay(
        kind: PaymentStoreKind.macAppStore,
        label: l.payment_source_mac_app_store,
        icon: FontAwesomeIcons.apple,
        iconColor: Colors.white,
      );
    case 'PLAY_STORE':
      return PaymentStoreDisplay(
        kind: PaymentStoreKind.googlePlay,
        label: l.payment_source_google_play,
        icon: FontAwesomeIcons.googlePlay,
        iconColor: const Color(0xFF3DDC84),
      );
    case null:
      break;
    default:
      break;
  }

  if (source == 'REVENUECAT' ||
      source == ProHistorySource.applePurchase ||
      source == ProHistorySource.googlePurchase) {
    return PaymentStoreDisplay(
      kind: PaymentStoreKind.genericStore,
      label: l.payment_source_store,
    );
  }

  return PaymentStoreDisplay(
    kind: PaymentStoreKind.unknown,
    label: source ?? l.unknown,
  );
}
