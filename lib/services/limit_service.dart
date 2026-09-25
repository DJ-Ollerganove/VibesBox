import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/apple_review_test_dj.dart';
import '../models/user_model.dart';
import '../utils/time_utils.dart';
import '../utils/wish_paths.dart';

/// Service für Free-DJ-Limits (Party-Erstellung pro Abrechnungszeitraum, 12h-Dauer, Wunsch-Limits).
/// Stichtag-Logik: Anker-Tag (anchorDay) aus [freePeriodStart] (Tag des Free-Starts, z. B. Downgrade)
/// oder ohne dieses Feld der **1.** des Monats von [createdAt] — nicht der Kalendertag der Registrierung
/// (sonst wirkt ein Test-DJ vom 12.5. fälschlich als 12.–11.-Zyklus statt Kalendermonat Mai).
/// Zeitraum = vom Stichtag (Start) bis genau eine Sekunde vor dem Stichtag des Folgemonats (Ende).
///
/// **Gäste & Free-DJ:** Die Wunschseite (`wishes_page`) und [LimitService.canRequestSong] zählen
/// bei `dj_plan_type == 'free'` **pro voller Kalenderstunde** ([TimeUtils.getCurrentFullHourRange])
/// gegen `guest_limit_per_hour` bzw. `user_limit_per_hour` (typisch 1 Wunsch/Stunde). Pro-Partys:
/// Zählung ebenfalls pro voller Stunde. Das Feld `dj_plan_type` wird bei neuen Partys gesetzt und
/// für Alt-Daten per Admin-Backfill (`backfillPartyDjPlanType`) auf den DJ-`planType` aus Firestore gespiegelt.
class LimitService {
  LimitService._();

  /// Max. Dauer einer Free-DJ-Party in Stunden.
  static const int freePartyMaxDurationHours = 12;

  /// Kalenderdatum, an dem der Free-Abrechnungszyklus „hängt“ (Stichtag = dieser Tag jeden Monat).
  /// [freePeriodStart] = tatsächlicher Free-Start (z. B. Downgrade). Ohne: **1.** des Monats von [createdAt].
  static DateTime? effectiveFreeBillingAnchorDate(UserModel user) {
    final fp = user.freePeriodStart;
    if (fp != null) {
      return DateTime(fp.year, fp.month, fp.day);
    }
    final ca = user.createdAt?.toDate();
    if (ca != null) {
      return DateTime(ca.year, ca.month, 1);
    }
    return null;
  }

  /// Liefert den Anker-Tag (1–31) aus dem User für die Stichtag-Logik.
  /// Quelle: [effectiveFreeBillingAnchorDate].
  static int getAnchorDay(UserModel user) {
    final anchor = effectiveFreeBillingAnchorDate(user);
    if (anchor == null) return 1;
    final day = anchor.day;
    if (day < 1) return 1;
    if (day > 31) return 31;
    return day;
  }

  /// Stichtag für einen gegebenen Monat: Hat der Monat [anchorDay], ist es dieser Tag.
  /// Sonst (z. B. 31.02.) ist es der 01. des Folgemonats.
  static DateTime _stichtagForMonth(int year, int month, int anchorDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    if (anchorDay <= lastDay) {
      return DateTime(year, month, anchorDay);
    }
    if (month == 12) {
      return DateTime(year + 1, 1, 1);
    }
    return DateTime(year, month + 1, 1);
  }

  /// Nächster Stichtag streng nach [zielDatum].
  static DateTime _nextStichtag(DateTime zielDatum, int anchorDay) {
    var stichtag = _stichtagForMonth(zielDatum.year, zielDatum.month, anchorDay);
    if (stichtag.isAfter(zielDatum)) return stichtag;
    if (zielDatum.month == 12) {
      return _stichtagForMonth(zielDatum.year + 1, 1, anchorDay);
    }
    return _stichtagForMonth(zielDatum.year, zielDatum.month + 1, anchorDay);
  }

  /// Stichtag des Monats vor dem Monat von [date].
  static DateTime _previousStichtag(DateTime date, int anchorDay) {
    final year = date.month == 1 ? date.year - 1 : date.year;
    final month = date.month == 1 ? 12 : date.month - 1;
    return _stichtagForMonth(year, month, anchorDay);
  }

  /// Berechnet den Abrechnungszeitraum, in dem [zielDatum] liegt (Stichtag-Logik).
  /// Start: Stichtag im aktuellen/vorherigen Monat, der zeitlich vor [zielDatum] liegt.
  /// Ende: Genau eine Sekunde vor dem Stichtag des nächsten Monats (z. B. bei Stichtag 2.: 02.03. bis 01.04. 23:59:59).
  /// [anchorDay]: Anker-Tag (1–31), z. B. aus [getAnchorDay].
  static ({DateTime start, DateTime end}) getAbrechnungsZeitraum(
    DateTime zielDatum,
    int anchorDay,
  ) {
    final next = _nextStichtag(zielDatum, anchorDay);
    final periodEnd = next.subtract(const Duration(seconds: 1));
    final periodStart = _previousStichtag(next, anchorDay);
    final start = DateTime(periodStart.year, periodStart.month, periodStart.day);
    return (start: start, end: periodEnd);
  }

  /// Dynamische Slot-Validierung (Downgrade-resistent): Pro Abrechnungszeitraum zählen die
  /// zeitlich ersten N Partys (nach start_date) als aktiv. Alle weiteren im selben Zeitraum
  /// gelten als isQuotaExceeded (Standby). Free: N=1; Apple-Review-Test-DJ: N=5.
  /// Gilt nur für [user.isFree].
  /// [parties]: Liste der Party-Docs (z. B. nicht beendete Partys des DJs).
  /// Returns: Set von Party-IDs, die das Kontingent überschritten haben (Standby im Zeitraum).
  static Set<String> getQuotaExceededPartyIds(
    UserModel user,
    List<QueryDocumentSnapshot> parties,
  ) {
    final result = <String>{};
    if (!user.isFree || parties.isEmpty) return result;

    final activeSlots = AppleReviewTestDj.matchesUser(user)
        ? AppleReviewTestDj.freePartiesPerPeriod
        : 1;

    final anchorDay = getAnchorDay(user);
    final withStartDate = <String, DateTime>{};
    for (final doc in parties) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      if (data['lifecycle_status'] == 'finished' || data['finished_at'] != null) continue;
      final startDate = data['start_date'] as Timestamp?;
      if (startDate == null) continue;
      withStartDate[doc.id] = startDate.toDate();
    }
    if (withStartDate.isEmpty) return result;

    // Gruppierung nach Stichtag-Intervall (nicht Kalendermonat): Party gehört in den Slot, in dessen [start, end] ihr start_date fällt
    final byPeriod = <String, List<String>>{};
    for (final e in withStartDate.entries) {
      final period = getAbrechnungsZeitraum(e.value, anchorDay);
      final key = '${period.start.year}-${period.start.month}-${period.start.day}';
      byPeriod.putIfAbsent(key, () => []).add(e.key);
    }
    for (final partyIds in byPeriod.values) {
      partyIds.sort((a, b) => withStartDate[a]!.compareTo(withStartDate[b]!));
      for (var i = activeSlots; i < partyIds.length; i++) {
        result.add(partyIds[i]);
      }
    }
    return result;
  }

  /// Ermittelt den Anker-Tag (1–31) aus rohen Firestore-User-Daten.
  /// Für Lösch-Dialog und Cloud Function, wenn kein UserModel vorhanden.
  static int getAnchorDayFromUserData(Map<String, dynamic>? data) {
    if (data == null) return 1;
    DateTime? anchorCal;
    final fp = data['free_period_start'] as Timestamp?;
    if (fp != null) {
      final d = fp.toDate();
      anchorCal = DateTime(d.year, d.month, d.day);
    } else {
      final ca = data['created_at'] as Timestamp?;
      if (ca != null) {
        final d = ca.toDate();
        anchorCal = DateTime(d.year, d.month, 1);
      }
    }
    if (anchorCal == null) return 1;
    final day = anchorCal.day;
    if (day < 1) return 1;
    if (day > 31) return 31;
    return day;
  }

  /// Berechnet den Stichtag-Slot-Key (Format "YYYY-MM-DD") für den Abrechnungszeitraum,
  /// in dem [dateInPeriod] liegt. Eindeutiger Key = period.start.
  static String computePeriodSlotKey(DateTime dateInPeriod, int anchorDay) {
    final period = getAbrechnungsZeitraum(dateInPeriod, anchorDay);
    return '${period.start.year}-${period.start.month.toString().padLeft(2, '0')}-${period.start.day.toString().padLeft(2, '0')}';
  }

  /// Fügt [periodSlotKey] (Format "YYYY-MM-DD", Stichtag period.start) zu usedPartySlots hinzu.
  /// Nur bei planType == 'free'. Nutzt arrayUnion (idempotent).
  static Future<void> addUsedPartySlotForFreeDj(String djUid, String periodSlotKey) async {
    if (djUid.isEmpty || periodSlotKey.isEmpty) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(djUid).get();
      if (!userDoc.exists) return;
      final planType =
          (userDoc.data()?['planType'] as String?)?.trim().toLowerCase() ?? 'free';
      if (planType != 'free') return;
      await FirebaseFirestore.instance.collection('users').doc(djUid).update({
        'usedPartySlots': FieldValue.arrayUnion([periodSlotKey]),
      });
    } catch (_) {
      // Fehler ignorieren, um Löschung nicht zu blockieren
    }
  }

  /// Prüft, ob der User im Abrechnungszeitraum für [plannedStartDate] noch eine Party anlegen darf.
  /// Ohne [plannedStartDate] wird der Zeitraum für heute berechnet.
  /// Es zählen: 1) Partys mit start_date im Zeitraum, 2) usedPartySlots (fälschungssicher).
  /// Gilt nur für Free-DJs (planType == 'free'). Free: max. 1; Apple-Review-Test-DJ: max. 5.
  /// Returns: true = darf erstellen, false = Limit erreicht.
  static Future<bool> checkPartyCreationLimit(
    UserModel user, {
    DateTime? plannedStartDate,
  }) async {
    if (!user.isFree) return true;

    final maxParties = AppleReviewTestDj.matchesUser(user)
        ? AppleReviewTestDj.freePartiesPerPeriod
        : 1;

    final anchorDay = getAnchorDay(user);
    final zielDatum = plannedStartDate ?? DateTime.now();
    final period = getAbrechnungsZeitraum(zielDatum, anchorDay);

    // Prüfung 1: usedPartySlots – exakter Stichtag-Key (period.start, Format "YYYY-MM-DD")
    // Aktuelles User-Dokument laden, um frische usedPartySlots zu haben (Cloud Function / Fall B)
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.id).get();
    final usedSlots = userDoc.exists
        ? UserModel.parseUsedPartySlots(userDoc.data()?['usedPartySlots'])
        : user.usedPartySlots;
    final periodSlotKey = '${period.start.year}-${period.start.month.toString().padLeft(2, '0')}-${period.start.day.toString().padLeft(2, '0')}';
    // Rückwärtskompatibel: auch alte "YYYY-MM" Keys prüfen (falls noch vorhanden)
    final legacyMonthKeys = <String>{};
    var d = period.start;
    while (!d.isAfter(period.end)) {
      legacyMonthKeys.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
      if (d.month == 12) {
        d = DateTime(d.year + 1, 1, d.day);
      } else {
        d = DateTime(d.year, d.month + 1, d.day);
      }
    }
    // Normal-Free: ein used-Slot blockiert den ganzen Zeitraum.
    // Review-Test-DJ: usedPartySlots ignorieren — Kontingent nur über Party-Anzahl.
    final usedSlotConsumed = usedSlots.contains(periodSlotKey) ||
        usedSlots.any((m) => legacyMonthKeys.contains(m));
    if (usedSlotConsumed && maxParties <= 1) {
      return false;
    }

    // Prüfung 2: Bestehende Partys im Zeitraum
    final snapshot = await FirebaseFirestore.instance
        .collection('parties')
        .where('created_by', isEqualTo: user.id)
        .get();

    int count = 0;
    for (final doc in snapshot.docs) {
      final startDate = doc.data()['start_date'] as Timestamp?;
      if (startDate == null) continue;
      final t = startDate.toDate();
      if (!t.isBefore(period.start) && !t.isAfter(period.end)) count++;
    }
    return count < maxParties;
  }

  /// Prüft, ob bei einem Free-DJ die erlaubte Partydauer (12h) abgelaufen ist.
  /// [partyStart]: Startzeit der Party (lokal oder UTC, konsistent mit Nutzung).
  /// [planType]: 'free' → 12h-Check; sonst → nicht abgelaufen (false).
  /// [createdBy]: Party-Owner-UID — Apple-Review-Test-DJ: kein 12h-Cutoff.
  static bool isPartyDurationExpired(
    DateTime partyStart,
    String planType, {
    String? createdBy,
  }) {
    if (AppleReviewTestDj.isUid(createdBy)) return false;
    if (planType != 'free') return false;
    final end = partyStart.add(const Duration(hours: freePartyMaxDurationHours));
    return DateTime.now().isAfter(end);
  }

  /// Prüft, ob ein Gast in dieser Party in der **aktuellen vollen Stunde** noch einen Wunsch
  /// abgeben darf (Free-DJ-Party).
  /// Gilt nur, wenn der DJ der Party ein Free-User ist (planType == 'free').
  /// DJ-Wünsche (is_dj_wish) zählen nicht.
  /// Returns: true = darf Wunsch senden, false = bereits 1 Wunsch in dieser Stunde.
  static Future<bool> canRequestSong(String clientId, String partyId) async {
    if (partyId.isEmpty || clientId.isEmpty) return true;
    try {
      final partyDoc = await FirebaseFirestore.instance.collection('parties').doc(partyId).get();
      if (!partyDoc.exists) return true;
      final createdBy = partyDoc.data()?['created_by'] as String?;
      if (createdBy == null || createdBy.isEmpty) return true;

      final partyData = partyDoc.data() ?? {};
      final djPlan =
          (partyData['dj_plan_type'] as String?)?.trim().toLowerCase();
      // Ohne `dj_plan_type`: Zusatz-Check entfällt (stündliches Limit über guest_limit_per_hour bleibt).
      if (djPlan == null || djPlan.isEmpty) return true;
      if (djPlan != 'free') return true;
      // Apple-Review-Test-DJ: kein Free-Zusatzlimit von 1/Stunde
      if (AppleReviewTestDj.matchesPartyData(partyData)) return true;

      final range = TimeUtils.getCurrentFullHourRange(DateTime.now());
      final snapshot = await WishPaths.partyWishes(partyId)
          .where('client_id', isEqualTo: clientId)
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
          )
          .get();

      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['is_dj_wish'] == true) continue;
        if (data['is_pre_wish'] == true) continue;
        if (data['is_duplicate'] == true) continue;
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt == null) continue;
        final t = createdAt.toDate();
        if (!t.isBefore(range.start) && t.isBefore(range.endExclusive)) count++;
      }
      return count < 1;
    } catch (e) {
      return true;
    }
  }
}
