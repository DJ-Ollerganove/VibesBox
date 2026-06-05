import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../utils/ui_constants.dart';

/// Gemeinsame Party-Status-Logik für DJ-Startseiten-Widgets (wie Party-Verwaltung).
abstract final class DjHomePartyUtils {
  static String statusFromDates(
    DateTime startDate,
    DateTime endDate,
    BuildContext context,
  ) {
    final l = AppLocalizations.of(context)!;
    final now = DateTime.now();
    if (now.isBefore(startDate)) return l.party_status_upcoming;
    if (now.isAfter(endDate)) return l.party_status_ended;
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

    for (final party in parties) {
      final data = party.data() as Map<String, dynamic>;
      if (isFinishedDoc(data)) continue;
      final startTs = data['start_date'] as Timestamp?;
      final endTs = data['end_date'] as Timestamp?;
      if (startTs == null || endTs == null) continue;

      final start = startTs.toDate();
      final end = endTs.toDate();
      final status = statusFromDates(start, end, context);
      if (status == AppLocalizations.of(context)!.party_status_running) {
        running.add(party);
      } else if (status == AppLocalizations.of(context)!.party_status_upcoming) {
        upcoming.add(party);
      }
    }

    int compareStart(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
      final sa = (a.data() as Map<String, dynamic>)['start_date'] as Timestamp;
      final sb = (b.data() as Map<String, dynamic>)['start_date'] as Timestamp;
      return sa.toDate().compareTo(sb.toDate());
    }

    running.sort(compareStart);
    upcoming.sort(compareStart);
    return [...running, ...upcoming];
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
