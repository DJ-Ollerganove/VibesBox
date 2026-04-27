import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/ui_constants.dart';

/// Baut die Historie der Zahlungen/Abos. Block inkl. Überschrift nur sichtbar, wenn Einträge vorhanden.
class ProfilePaymentHistory extends StatelessWidget {
  const ProfilePaymentHistory({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        final localizations = AppLocalizations.of(context)!;
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              localizations.payment_history_error_loading(snapshot.error ?? ''),
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Text(
                localizations.payment_history_title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final localizations = AppLocalizations.of(context)!;
                final locale = Localizations.localeOf(context);

                final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
                final amount = (data['amountGross'] as num?)?.toDouble() ?? 0.0;
                final type = data['type'] as String?;
                final source = data['source'] as String?; // z.B. REVENUECAT, ADMIN_GIFT

                String amountText;
                if (type == 'gift') {
                  amountText = localizations.payment_amount_credit;
                } else if (type == 'lifetime_grant' || type == 'LIFETIME_GIFT') {
                  amountText = localizations.payment_amount_gifted;
                } else {
                  amountText = NumberFormat.currency(locale: locale.toString(), symbol: '€').format(amount);
                }

                String sourceDisplay = source ?? (localizations.unknown);
                if (source == 'REVENUECAT') sourceDisplay = localizations.payment_source_store;
                if (source == 'ADMIN_GIFT') sourceDisplay = localizations.vibesbox_pro_life;
                if (source == 'ADMIN_REVOKE') sourceDisplay = localizations.pro_life_revoked;

                final dateTimeFormat = DateFormat.yMd(locale.toString()).add_Hm();
                final timeSuffix = (localizations.time_suffix).trim();
                final dateTimeText = dateTimeFormat.format(timestamp) + (timeSuffix.isEmpty ? '' : ' $timeSuffix');

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(8),
                    border: const Border(
                      left: BorderSide(color: UIConstants.appOrange, width: 4),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateTimeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sourceDisplay,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                      Text(
                        amountText,
                        style: TextStyle(
                          color: (type == 'gift' || type == 'lifetime_grant' || type == 'LIFETIME_GIFT')
                              ? Colors.greenAccent
                              : (type == 'lifetime_revoked' ? Colors.white54 : UIConstants.appOrange),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
