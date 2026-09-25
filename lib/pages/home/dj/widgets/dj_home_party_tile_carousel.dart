import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../pages/neue_party_page.dart';
import '../../../../pages/party_statistik_page.dart';
import '../../../../services/limit_service.dart';
import '../../../../services/user_service.dart';
import '../../../../settings_party_edit_dialog.dart';
import '../../../../utils/formatting_utils.dart';
import '../../../../utils/party_qr_launch_helper.dart';
import '../../../../utils/ui_constants.dart';
import '../../../../utils/guest_floor_display.dart';
import '../../../../widgets/party_pre_wishes_row.dart';
import '../../../../widgets/party/party_dj_setlist_badge.dart';
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
        final user = UserService().currentUser.value;
        final isFree = user?.isFree ?? true;
        final quotaExceededIds = isManagement && isFree && user != null
            ? LimitService.getQuotaExceededPartyIds(user, docs)
            : <String>{};
        final isFreeHistory = mode == 'history' && isFree;
        final newestHistoryPartyId = docs.isNotEmpty ? docs.first.id : null;

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
              height: 124,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final lifecycle = data['lifecycle_status'] as String?;
                  final isStandbyOrQuota = isManagement &&
                      isFree &&
                      (lifecycle == 'standby' ||
                          quotaExceededIds.contains(doc.id));
                  final historyTapEnabled = mode != 'history' ||
                      !isFreeHistory ||
                      doc.id == newestHistoryPartyId;
                  return _PartyMiniTile(
                    doc: doc,
                    showActions: mode == 'management' && !isStandbyOrQuota,
                    openStatisticsOnTap:
                        mode == 'history' && historyTapEnabled,
                    dimmed: isStandbyOrQuota ||
                        (mode == 'history' &&
                            isFreeHistory &&
                            doc.id != newestHistoryPartyId),
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
    required this.showActions,
    required this.openStatisticsOnTap,
    this.dimmed = false,
  });

  final QueryDocumentSnapshot doc;
  final bool showActions;
  final bool openStatisticsOnTap;
  final bool dimmed;

  Future<void> _openStatistics(BuildContext context) async {
    final data = doc.data() as Map<String, dynamic>;
    final l = AppLocalizations.of(context)!;
    final name = (data['party_name'] as String?)?.trim() ?? l.unnamed_party;
    final startTs = data['start_date'] as Timestamp?;
    final endTs = data['end_date'] as Timestamp?;
    if (startTs == null || endTs == null) return;
    final partyCode = data['party_code'] as String? ?? '';
    await PartyStatistikPage.show(
      context,
      partyId: doc.id,
      partyName: name,
      startDate: startTs.toDate(),
      endDate: endTs.toDate(),
      partyCode: partyCode,
      preloadedPartyData: data,
    );
  }

  void _openQr(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    PartyQrLaunchHelper.showForPartyData(
      context: context,
      partyId: doc.id,
      data: data,
    );
  }

  void _openEdit(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final l = AppLocalizations.of(context)!;
    final name = (data['party_name'] as String?)?.trim() ?? l.unnamed_party;
    final startTs = data['start_date'] as Timestamp?;
    final endTs = data['end_date'] as Timestamp?;
    if (startTs == null || endTs == null) return;
    SettingsPartyEditDialog.show(
      context,
      doc.id,
      name,
      startTs.toDate(),
      endTs.toDate(),
      data['party_type'] as String?,
      (date, ctx) => FormattingUtils.formatDateTime(date, ctx ?? context),
      currentGuestLimit: data['guest_limit_per_hour'] as int?,
      currentUserLimit: data['user_limit_per_hour'] as int?,
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
    final allowPreWishes = data['allow_pre_wishes'] == true;
    final upcoming = start != null && DateTime.now().isBefore(start);
    final floorSubtitle =
        GuestFloorDisplay.publicPartyFloorLineIfAny(l, data);
    final qrEnabled = !dimmed &&
        partyCode != null &&
        partyCode.isNotEmpty &&
        showActions;

    final borderColor = dimmed
        ? Colors.grey.shade700
        : UIConstants.partyYellow.withValues(alpha: 0.7);
    final titleColor = dimmed ? Colors.grey.shade500 : Colors.white;
    final dateColor = dimmed ? Colors.grey.shade600 : Colors.grey.shade400;

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: InkWell(
        onTap: openStatisticsOnTap ? () => _openStatistics(context) : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 118,
          height: 118,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        name,
                        maxLines: floorSubtitle != null ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.12,
                        ),
                      ),
                      if (floorSubtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          floorSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: dimmed
                                ? UIConstants.appOrange.withValues(alpha: 0.45)
                                : UIConstants.appOrange,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.12,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (start != null)
                        Text(
                          FormattingUtils.formatDateTime(start, context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: dateColor, fontSize: 8.5),
                        ),
                    ],
                  ),
                ),
                if (showActions)
                  SizedBox(
                    height: 22,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: upcoming ? 70 : 42,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (allowPreWishes)
                                  PartyPreWishesCompactBadge(
                                    partyId: doc.id,
                                    partyName: name,
                                    partyStartDate: start,
                                    enabled: !dimmed,
                                    fontSize: 9,
                                  ),
                                if (upcoming)
                                  PartyDjSetlistBadge(
                                    partyId: doc.id,
                                    partyName: name,
                                    fontSize: 8,
                                    compact: true,
                                    dimColor: dimmed ? Colors.grey.shade600 : null,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              onTap:
                                  qrEnabled ? () => _openQr(context) : null,
                              behavior: HitTestBehavior.opaque,
                              child: Icon(
                                Icons.qr_code_2,
                                size: 17,
                                color: qrEnabled
                                    ? UIConstants.appOrange
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 22,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap:
                                  !dimmed ? () => _openEdit(context) : null,
                              behavior: HitTestBehavior.opaque,
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: !dimmed
                                    ? Colors.white70
                                    : Colors.grey.shade700,
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
      ),
    );
  }
}
