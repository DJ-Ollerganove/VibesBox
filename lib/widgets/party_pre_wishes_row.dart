import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/song_request.dart';
import '../services/wish_management_service.dart';
import '../utils/pre_wish_helper.dart';
import '../utils/ui_constants.dart';
import '../utils/wish_grouping_helper.dart';
import 'pre_wishes_overview_dialog.dart';

/// Klickbare Zeile „Vorab-Wünsche: N Wünsche“ unter dem Party-Countdown (Party-Verwaltung).
class PartyPreWishesRow extends StatelessWidget {
  const PartyPreWishesRow({
    super.key,
    required this.partyId,
    required this.partyName,
    this.dimColor,
  });

  final String partyId;
  final String partyName;
  final Color? dimColor;

  static int _countPrimaryPreWishes(List<QueryDocumentSnapshot> docs) {
    final wishes = <SongRequest>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (!PreWishHelper.isPreWishInOverview(data)) continue;
      try {
        wishes.add(SongRequest.fromDocument(doc));
      } catch (_) {}
    }
    return WishGroupingHelper.withoutDuplicateShadowDocuments(wishes).length;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labelColor = dimColor ?? UIConstants.colorPreWish;

    return StreamBuilder<QuerySnapshot>(
      stream: WishManagementService.getPreWishOverviewStream(partyId),
      builder: (context, snapshot) {
        final count = snapshot.hasData
            ? _countPrimaryPreWishes(snapshot.data!.docs)
            : 0;
        final countText = count == 1
            ? l.pre_wish_count_singular
            : l.pre_wish_count_plural.replaceAll('{count}', '$count');

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => PreWishesOverviewDialog.show(
                context,
                partyId: partyId,
                partyName: partyName,
              ),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l.pre_wishes_label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                    Text(
                      countText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right, size: 18, color: labelColor),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
