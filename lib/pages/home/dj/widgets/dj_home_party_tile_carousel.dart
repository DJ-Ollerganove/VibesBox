import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../pages/neue_party_page.dart';
import '../../../../pages/party_statistik_page.dart';
import '../../../../utils/formatting_utils.dart';
import '../../../../utils/ui_constants.dart';
import '../../../../widgets/party_qr_code_dialog.dart' show Party, PartyQrCodeDialog;
import '../dj_home_party_utils.dart';

/// Horizontale Party-Kacheln für Startseiten-Widgets.
class DjHomePartyTileCarousel extends StatelessWidget {
  const DjHomePartyTileCarousel({
    super.key,
    required this.allParties,
    required this.timeStream,
    required this.mode,
  });

  final List<QueryDocumentSnapshot> allParties;
  final Stream<DateTime> timeStream;

  /// `management` = laufend + bevorstehend (mit QR) | `history` = vergangene Partys
  final String mode;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final title = mode == 'history'
        ? l.dj_home_party_history_title
        : l.dj_home_party_management_title;

    return StreamBuilder<DateTime>(
      stream: timeStream,
      initialData: DateTime.now(),
      builder: (context, _) {
        final docs = mode == 'history'
            ? DjHomePartyUtils.historyParties(allParties)
            : DjHomePartyUtils.runningAndUpcoming(allParties, context);

        final isManagement = mode == 'management';

        if (docs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isManagement)
                _ManagementHeader(title: title, l: l)
              else
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l.no_further_parties_planned,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isManagement)
              _ManagementHeader(title: title, l: l)
            else
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return _PartyMiniTile(
                    doc: docs[index],
                    showQr: mode == 'management',
                    openStatisticsOnTap: mode == 'history',
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ManagementHeader extends StatelessWidget {
  const _ManagementHeader({required this.title, required this.l});

  final String title;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: UIConstants.appOrange,
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          tooltip: l.new_party,
          onPressed: () => NeuePartyPage.show(context),
        ),
      ],
    );
  }
}

class _PartyMiniTile extends StatelessWidget {
  const _PartyMiniTile({
    required this.doc,
    required this.showQr,
    required this.openStatisticsOnTap,
  });

  final QueryDocumentSnapshot doc;
  final bool showQr;
  final bool openStatisticsOnTap;

  Future<void> _openStatistics(BuildContext context) async {
    final data = doc.data() as Map<String, dynamic>;
    final l = AppLocalizations.of(context)!;
    final name = (data['party_name'] as String?)?.trim() ?? l.unnamed_party;
    final startTs = data['start_date'] as Timestamp?;
    final endTs = data['end_date'] as Timestamp?;
    if (startTs == null || endTs == null) return;
    final partyCode = data['party_code'] as String? ?? '';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartyStatistikPage(
          partyId: doc.id,
          partyName: name,
          startDate: startTs.toDate(),
          endDate: endTs.toDate(),
          partyCode: partyCode,
          preloadedPartyData: data,
        ),
      ),
    );
  }

  void _openQr(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final l = AppLocalizations.of(context)!;
    final name = (data['party_name'] as String?)?.trim() ?? l.unnamed_party;
    final startTs = data['start_date'];
    final endTs = data['end_date'];
    final start = startTs is Timestamp ? startTs.toDate() : null;
    final end = endTs is Timestamp ? endTs.toDate() : start;
    final partyCode = data['party_code'] as String?;
    if (start == null || end == null || partyCode == null || partyCode.isEmpty) {
      return;
    }
    PartyQrCodeDialog.show(
      context: context,
      party: Party(
        partyName: name,
        startDate: start,
        endDate: end,
        partyCode: partyCode,
        partyId: doc.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final l = AppLocalizations.of(context)!;
    final name = (data['party_name'] as String?)?.trim() ?? l.unnamed_party;
    final startTs = data['start_date'];
    final start = startTs is Timestamp ? startTs.toDate() : null;
    final partyCode = data['party_code'] as String?;

    return InkWell(
      onTap: openStatisticsOnTap ? () => _openStatistics(context) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 108,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: UIConstants.partyYellow.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
            const Spacer(),
            if (start != null)
              Text(
                FormattingUtils.formatDateTime(start, context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 9),
              ),
            if (showQr) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: partyCode != null && partyCode.isNotEmpty
                      ? () => _openQr(context)
                      : null,
                  borderRadius: BorderRadius.circular(4),
                  child: Icon(
                    Icons.qr_code_2,
                    size: 18,
                    color: partyCode != null && partyCode.isNotEmpty
                        ? UIConstants.appOrange
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
