import 'package:cloud_firestore/cloud_firestore.dart';

/// Legacy-tolerant: beendet via lifecycle, status, finished_at oder abgelaufenem Ende.
bool beendetePartyIsEnded(Map<String, dynamic> data) {
  if (data['lifecycle_status'] == 'finished' || data['finished_at'] != null) {
    return true;
  }
  final status = data['status'] as String?;
  if (status == 'beendet' || status == 'ended') return true;
  DateTime? end;
  final endTs = data['end_date'] as Timestamp?;
  if (endTs != null) {
    end = endTs.toDate();
  } else {
    final endPosix = data['end_time_posix'];
    if (endPosix is int) {
      end = DateTime.fromMillisecondsSinceEpoch(endPosix * 1000);
    }
  }
  return end != null && DateTime.now().isAfter(end);
}

DateTime? beendetePartySortDate(Map<String, dynamic> data) {
  final startTs = data['start_date'] as Timestamp?;
  if (startTs != null) return startTs.toDate();
  final startPosix = data['start_time_posix'];
  if (startPosix is int) {
    return DateTime.fromMillisecondsSinceEpoch(startPosix * 1000);
  }
  return null;
}

/// Kalenderjahr der Party (nach Startdatum).
int? beendetePartyYear(Map<String, dynamic> data) {
  final start = beendetePartySortDate(data);
  return start?.year;
}

int compareBeendetePartiesNewestFirst(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
) {
  final ad = beendetePartySortDate(a.data());
  final bd = beendetePartySortDate(b.data());
  if (ad == null && bd == null) return 0;
  if (ad == null) return 1;
  if (bd == null) return -1;
  return bd.compareTo(ad);
}

List<QueryDocumentSnapshot<Map<String, dynamic>>> filterEndedParties(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final ended = docs.where((d) => beendetePartyIsEnded(d.data())).toList();
  ended.sort(compareBeendetePartiesNewestFirst);
  return ended;
}

/// Jahre mit beendeten Partys, die vor [currentYear] liegen (absteigend).
List<int> priorYearsWithEndedParties(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> endedSorted,
  int currentYear,
) {
  final years = <int>{};
  for (final doc in endedSorted) {
    final year = beendetePartyYear(doc.data());
    if (year != null && year < currentYear) years.add(year);
  }
  final list = years.toList()..sort((a, b) => b.compareTo(a));
  return list;
}

List<QueryDocumentSnapshot<Map<String, dynamic>>> endedPartiesForYear(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> endedSorted,
  int year,
) {
  return endedSorted
      .where((d) => beendetePartyYear(d.data()) == year)
      .toList();
}
