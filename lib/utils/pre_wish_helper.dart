import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/song_request.dart';

/// Vorab-Wünsche: gleiche Logik wie PWA (`party_shared.js`) und Firestore Rules.
class PreWishHelper {
  PreWishHelper._();

  static const int preWishCloseHours = 6;

  static DateTime? partyStartFromData(Map<String, dynamic> data) {
    final ts = data['start_date'];
    if (ts is Timestamp) return ts.toDate();
    final posix = data['start_time_posix'];
    if (posix is int) {
      return DateTime.fromMillisecondsSinceEpoch(posix * 1000);
    }
    return null;
  }

  static DateTime? partyEndFromData(Map<String, dynamic> data) {
    final ts = data['end_date'];
    if (ts is Timestamp) return ts.toDate();
    final posix = data['end_time_posix'];
    if (posix is int) {
      return DateTime.fromMillisecondsSinceEpoch(posix * 1000);
    }
    return null;
  }

  /// Party noch nicht gestartet, Haken an, jetzt ≤ Start − 6 h.
  static bool isPreWishWindowOpen(
    Map<String, dynamic>? data, [
    DateTime? now,
  ]) {
    if (data == null || data['allow_pre_wishes'] != true) return false;
    final start = partyStartFromData(data);
    if (start == null) return false;
    final n = now ?? DateTime.now();
    if (!n.isBefore(start)) return false;
    final deadline = start.subtract(const Duration(hours: preWishCloseHours));
    return !n.isAfter(deadline);
  }

  /// Alle Vorab-Wünsche für die DJ-Übersicht (Queue + bereits in Offen freigegeben).
  static bool isPreWishInOverview(Map<String, dynamic>? data) {
    return data != null && data['is_pre_wish'] == true;
  }

  /// Noch in der Vorab-Queue (nicht in „Offen“ freigegeben).
  static bool isQueuedPreWish(Map<String, dynamic>? data) {
    if (data == null || data['is_pre_wish'] != true) return false;
    return data['pre_wish_published'] != true;
  }

  /// In Offen sichtbar, Marker [is_pre_wish] bleibt erhalten.
  static bool isPublishedPreWish(Map<String, dynamic>? data) {
    if (data == null || data['is_pre_wish'] != true) return false;
    return data['pre_wish_published'] == true;
  }

  static bool isQueuedPreWishRequest(SongRequest? r) {
    if (r == null || r.isPreWish != true) return false;
    return r.preWishPublished != true;
  }

  /// Party noch nicht gestartet, aber keine Vorab-Wunschbox (z. B. letzte 6 h).
  static bool isPrePartyWaitOnly(
    Map<String, dynamic>? data, [
    DateTime? now,
  ]) {
    if (data == null) return false;
    final start = partyStartFromData(data);
    if (start == null) return false;
    final n = now ?? DateTime.now();
    if (!n.isBefore(start)) return false;
    return !isPreWishWindowOpen(data, n);
  }
}
