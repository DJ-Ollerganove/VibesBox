import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../utils/party_grace_period_helper.dart';

/// Auswertung aller Partys eines DJs für die Startseite.
class DjHomePartySnapshot {
  const DjHomePartySnapshot({
    this.activeParty,
    this.graceParty,
    this.upcomingParty,
    this.lastFinishedParty,
    required this.allDocs,
  });

  final QueryDocumentSnapshot? activeParty;
  final QueryDocumentSnapshot? graceParty;
  final QueryDocumentSnapshot? upcomingParty;
  final QueryDocumentSnapshot? lastFinishedParty;
  final List<QueryDocumentSnapshot> allDocs;

  QueryDocumentSnapshot? get displayParty =>
      activeParty ?? graceParty ?? upcomingParty;

  String? get activePartyId => activeParty?.id;

  static DjHomePartySnapshot resolve(
    List<QueryDocumentSnapshot> parties, {
    required int gracePeriodMinutes,
    DateTime? now,
  }) {
    final nowUnix =
        (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
    final nowDate = now ?? DateTime.now();

    QueryDocumentSnapshot? activeParty;
    for (final party in parties) {
      final data = party.data() as Map<String, dynamic>;
      if (data['lifecycle_status'] == 'finished' ||
          data['lifecycle_status'] == 'standby' ||
          data['finished_at'] != null) {
        continue;
      }
      final startPosix = data['start_time_posix'] as int?;
      final endPosix = data['end_time_posix'] as int?;
      if (startPosix != null &&
          endPosix != null &&
          nowUnix >= startPosix &&
          nowUnix < endPosix) {
        activeParty = party;
        break;
      }
    }

    QueryDocumentSnapshot? lastFinishedParty;
    final pastParties = parties.where((party) {
      final data = party.data() as Map<String, dynamic>;
      final endPosix = data['end_time_posix'] as int?;
      return (endPosix ?? 0) < nowUnix;
    }).toList();
    if (pastParties.isNotEmpty) {
      pastParties.sort((a, b) {
        final endA =
            (a.data() as Map<String, dynamic>)['end_time_posix'] as int? ?? 0;
        final endB =
            (b.data() as Map<String, dynamic>)['end_time_posix'] as int? ?? 0;
        return endB.compareTo(endA);
      });
      lastFinishedParty = pastParties.first;
    }

    QueryDocumentSnapshot? upcomingParty;
    final futureParties = parties.where((party) {
      final data = party.data() as Map<String, dynamic>;
      if (data['lifecycle_status'] == 'standby') return false;
      final startPosix = data['start_time_posix'] as int?;
      return (startPosix ?? 0) > nowUnix;
    }).toList();
    if (futureParties.isNotEmpty) {
      futureParties.sort((a, b) {
        final startA =
            (a.data() as Map<String, dynamic>)['start_time_posix'] as int? ?? 0;
        final startB =
            (b.data() as Map<String, dynamic>)['start_time_posix'] as int? ?? 0;
        return startA.compareTo(startB);
      });
      upcomingParty = futureParties.first;
    }

    QueryDocumentSnapshot? graceParty;
    DateTime? bestGraceEnd;
    for (final party in parties) {
      final data = party.data() as Map<String, dynamic>;
      final end = PartyGracePeriodHelper.partyEndDate(data);
      if (end == null || nowDate.isBefore(end)) continue;
      if (PartyGracePeriodHelper.wishesManuallyHidden(data)) continue;
      if (!PartyGracePeriodHelper.isWithinGracePeriod(
        nowDate,
        end,
        gracePeriodMinutes,
      )) {
        continue;
      }
      if (bestGraceEnd == null || end.isAfter(bestGraceEnd)) {
        bestGraceEnd = end;
        graceParty = party;
      }
    }

    return DjHomePartySnapshot(
      activeParty: activeParty,
      graceParty: graceParty,
      upcomingParty: upcomingParty,
      lastFinishedParty: lastFinishedParty,
      allDocs: parties,
    );
  }
}
