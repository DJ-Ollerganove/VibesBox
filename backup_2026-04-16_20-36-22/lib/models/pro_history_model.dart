import 'package:cloud_firestore/cloud_firestore.dart';

/// Quellen für Pro-Einträge im Logbuch
abstract class ProHistorySource {
  static const String applePurchase = 'APPLE_PURCHASE';
  static const String googlePurchase = 'GOOGLE_PURCHASE';
  static const String adminGift = 'ADMIN_GIFT';
}

/// Typen für Pro-History-Einträge
abstract class ProHistoryType {
  static const String purchase = 'purchase';
  static const String gift = 'gift';
  static const String referral = 'referral';
}

/// Eintrag im Pro-Logbuch unter users/{uid}/history/{id}
class ProHistoryEntry {
  final String id;
  final Timestamp timestamp;
  final String type; // 'purchase', 'gift', 'referral'
  final String source; // 'APPLE_PURCHASE', 'GOOGLE_PURCHASE', 'ADMIN_GIFT'
  final String transactionId;
  final double amountGross;
  final String currency;
  final double vatRate;
  final double netPayout;

  ProHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.source,
    required this.transactionId,
    required this.amountGross,
    required this.currency,
    this.vatRate = 0.19,
    required this.netPayout,
  });

  /// Berechnet netPayout für Apple/Google-Käufe:
  /// (Gross - (Gross - (Gross / (1 + vatRate)))) * 0.85
  /// = (Gross / (1 + vatRate)) * 0.85
  static double computeNetPayoutForStorePurchase({
    required double amountGross,
    double vatRate = 0.19,
    double storePayoutRate = 0.85,
  }) {
    final netAfterVat = amountGross / (1 + vatRate);
    return netAfterVat * storePayoutRate;
  }

  /// Erstellt einen Kauf-Eintrag für Apple/Google mit berechnetem netPayout
  factory ProHistoryEntry.purchase({
    required String id,
    required Timestamp timestamp,
    required String source,
    required String transactionId,
    required double amountGross,
    required String currency,
    double vatRate = 0.19,
  }) {
    final netPayout = (source == ProHistorySource.applePurchase ||
            source == ProHistorySource.googlePurchase)
        ? computeNetPayoutForStorePurchase(
            amountGross: amountGross,
            vatRate: vatRate,
          )
        : 0.0;
    return ProHistoryEntry(
      id: id,
      timestamp: timestamp,
      type: ProHistoryType.purchase,
      source: source,
      transactionId: transactionId,
      amountGross: amountGross,
      currency: currency,
      vatRate: vatRate,
      netPayout: netPayout,
    );
  }

  /// Erstellt ProHistoryEntry aus Firestore-Dokument
  factory ProHistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ProHistoryEntry(
      id: doc.id,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      type: data['type'] as String? ?? ProHistoryType.purchase,
      source: data['source'] as String? ?? ProHistorySource.googlePurchase,
      transactionId: data['transactionId'] as String? ?? '',
      amountGross: (data['amountGross'] as num?)?.toDouble() ?? 0.0,
      currency: data['currency'] as String? ?? 'EUR',
      vatRate: (data['vatRate'] as num?)?.toDouble() ?? 0.19,
      netPayout: (data['netPayout'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Konvertiert ProHistoryEntry zu Firestore-Daten
  Map<String, dynamic> toFirestore() {
    return {
      'timestamp': timestamp,
      'type': type,
      'source': source,
      'transactionId': transactionId,
      'amountGross': amountGross,
      'currency': currency,
      'vatRate': vatRate,
      'netPayout': netPayout,
    };
  }
}
