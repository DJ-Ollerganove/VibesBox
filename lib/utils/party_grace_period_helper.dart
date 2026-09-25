import 'package:cloud_firestore/cloud_firestore.dart';

/// Nachlaufzeit-Logik für offene Wünsche nach regulärem Party-Ende.
class PartyGracePeriodHelper {
  PartyGracePeriodHelper._();

  static DateTime? partyEndDate(Map<String, dynamic> data) {
    final endTimestamp = data['end_date'];
    if (endTimestamp is Timestamp) return endTimestamp.toDate();
    if (endTimestamp is DateTime) return endTimestamp;
    final endPosix = data['end_time_posix'];
    if (endPosix is int) {
      return DateTime.fromMillisecondsSinceEpoch(endPosix * 1000);
    }
    if (endPosix is num) {
      return DateTime.fromMillisecondsSinceEpoch(endPosix.toInt() * 1000);
    }
    return null;
  }

  static bool wishesManuallyHidden(Map<String, dynamic> data) =>
      data['wishes_manually_hidden'] as bool? ?? false;

  static DateTime graceEndsAt(DateTime endDate, int graceMinutes) =>
      endDate.add(Duration(minutes: graceMinutes));

  static bool isWithinGracePeriod(
    DateTime now,
    DateTime endDate,
    int graceMinutes,
  ) {
    if (graceMinutes <= 0) return false;
    return now.isBefore(graceEndsAt(endDate, graceMinutes));
  }

  static bool isGracePeriodOnly(
    DateTime now,
    DateTime endDate,
    int graceMinutes,
  ) =>
      !now.isBefore(endDate) &&
      isWithinGracePeriod(now, endDate, graceMinutes);

  /// Offene Wünsche sichtbar: vor regulärem Ende ODER (Nachlaufzeit und nicht manuell ausgeblendet).
  static bool shouldShowOpenWishes({
    required DateTime now,
    required DateTime? endDate,
    required int graceMinutes,
    required bool wishesManuallyHidden,
  }) {
    if (endDate == null) return false;
    if (now.isBefore(endDate)) return true;
    if (wishesManuallyHidden) return false;
    return isWithinGracePeriod(now, endDate, graceMinutes);
  }
}
