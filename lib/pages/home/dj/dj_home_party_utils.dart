import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/party_grace_period_helper.dart';
import '../../../utils/ui_constants.dart';

/// Gemeinsame Party-Status-Logik für DJ-Startseiten-Widgets (wie Party-Verwaltung).
abstract final class DjHomePartyUtils {
  static DateTime? partyStartDate(Map<String, dynamic> data) {
    final startTs = data['start_date'] as Timestamp?;
    if (startTs != null) return startTs.toDate();
    final startPosix = data['start_time_posix'];
    if (startPosix is int) {
      return DateTime.fromMillisecondsSinceEpoch(startPosix * 1000);
    }
    if (startPosix is num) {
      return DateTime.fromMillisecondsSinceEpoch(startPosix.toInt() * 1000);
    }
    return null;
  }

  static DateTime? partyEndDate(Map<String, dynamic> data) =>
      PartyGracePeriodHelper.partyEndDate(data);

  static String statusFromDates(
    DateTime startDate,
    DateTime endDate,
    BuildContext context,
  ) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();
    // Endzeit exklusiv: läuft solange now < endDate (wie Party-Verwaltung).
    if (now.isBefore(startDate)) return l.party_status_upcoming;
    if (!now.isBefore(endDate)) return l.party_status_ended;
    return l.party_status_running;
  }

  static Color statusColor(String status, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (status == l.party_status_running) return Colors.green;
    if (status == l.party_status_upcoming) return UIConstants.appOrange;
    if (status == l.party_status_ended) return Colors.grey;
    return Colors.white;
  }

  static bool isFinishedDoc(Map<String, dynamic> data) =>
      data['lifecycle_status'] == 'finished' || data['finished_at'] != null;

  static List<QueryDocumentSnapshot> runningAndUpcoming(
    List<QueryDocumentSnapshot> parties,
    BuildContext context,
  ) {
    final running = <QueryDocumentSnapshot>[];
    final upcoming = <QueryDocumentSnapshot>[];
    final l = AppLocalizations.of(context)!;

    for (final party in parties) {
      final data = party.data() as Map<String, dynamic>;
      if (isFinishedDoc(data)) continue;
      final start = partyStartDate(data);
      final end = partyEndDate(data);
      if (start == null || end == null) continue;

      final status = statusFromDates(start, end, context);
      if (status == l.party_status_running) {
        running.add(party);
      } else if (status == l.party_status_upcoming) {
        upcoming.add(party);
      }
    }

    int compareStart(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
      final sa = partyStartDate(a.data() as Map<String, dynamic>);
      final sb = partyStartDate(b.data() as Map<String, dynamic>);
      return (sa ?? DateTime(0)).compareTo(sb ?? DateTime(0));
    }

    running.sort(compareStart);
    upcoming.sort(compareStart);
    return [...running, ...upcoming];
  }

  /// Partys in der Nachlaufzeit (reguläres Ende überschritten, Grace noch aktiv).
  static List<QueryDocumentSnapshot> graceParties(
    List<QueryDocumentSnapshot> parties, {
    required int gracePeriodMinutes,
    DateTime? now,
  }) {
    final nowDate = now ?? DateTime.now();
    final result = <QueryDocumentSnapshot>[];

    for (final party in parties) {
      final data = party.data() as Map<String, dynamic>;
      if (isFinishedDoc(data)) continue;
      final end = partyEndDate(data);
      if (end == null || nowDate.isBefore(end)) continue;
      if (PartyGracePeriodHelper.wishesManuallyHidden(data)) continue;
      if (!PartyGracePeriodHelper.isWithinGracePeriod(
        nowDate,
        end,
        gracePeriodMinutes,
      )) {
        continue;
      }
      result.add(party);
    }

    result.sort((a, b) {
      final endA = partyEndDate(a.data() as Map<String, dynamic>);
      final endB = partyEndDate(b.data() as Map<String, dynamic>);
      return (endB ?? DateTime(0)).compareTo(endA ?? DateTime(0));
    });
    return result;
  }

  static List<QueryDocumentSnapshot> historyParties(
    List<QueryDocumentSnapshot> parties,
  ) {
    final now = DateTime.now();
    final past = parties.where((party) {
      final data = party.data() as Map<String, dynamic>;
      if (isFinishedDoc(data)) return true;
      final endTs = data['end_date'] as Timestamp?;
      if (endTs == null) return false;
      return now.isAfter(endTs.toDate());
    }).toList();

    past.sort((a, b) {
      final endA = (a.data() as Map<String, dynamic>)['end_date'] as Timestamp?;
      final endB = (b.data() as Map<String, dynamic>)['end_date'] as Timestamp?;
      final ea = endA?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      final eb = endB?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
      return eb.compareTo(ea);
    });
    return past;
  }
}
