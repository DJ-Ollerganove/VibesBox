import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'public_dj_profile_service.dart';

import '../utils/party_code_utils.dart';
import '../widgets/party_check_in_feedback_widget.dart';
import '../utils/debug_log.dart';

/// Zentrale Session für Gast-Party-Beitritt.
/// **Alles-drin-Prinzip:** Beim Login (validateAndJoin) werden Party, DJ und Social-Links
/// einmalig geladen und im Service gespeichert. Keine weiteren Firestore-Abfragen auf
/// den Gast-Seiten – alles kommt aus dem "Session-Koffer".
///
/// **Hydrierung:** Nach App-Neustart prüft hydrateIfNeeded ob Party noch aktiv ist.
/// Wenn beendet/abgelaufen → clearSession(). Wenn aktiv aber Daten fehlen → nachladen.
/// Bei Pause-Status bleibt die Session erhalten.
class PartySessionService {
  PartySessionService._();

  static final PartySessionService instance = PartySessionService._();

  static const String _keyShortCode = 'party_session_short_code';
  static const String _keyPartyId = 'party_session_party_id';
  static const String _keyPartyName = 'party_session_party_name';
  static const String _keyDjId = 'party_session_dj_id';
  static const String _keyDjPlan = 'party_session_dj_plan';
  static const String _keyDjName = 'party_session_dj_name';
  static const String _keyDjLogoUrl = 'party_session_dj_logo_url';
  static const String _keySocialLinks = 'party_session_social_links';
  static const String _keyLinkOrder = 'party_session_link_order';
  static const String _keyPartyCode = 'party_code'; // Sync mit WishesPage (Anzeige)
  /// 8 Ziffern, eingegeben aber ggf. noch nicht mit „Prüfen“ bestätigt (Registrierung/E-Mail-Flow).
  static const String _keyPendingPartyCode = 'pending_party_code';

  String? _shortCode;
  String? _partyId;
  String? _partyName;
  String? _djId;
  String? _djPlan;
  String? _djName;
  String? _djLogoUrl;
  Map<String, String> _socialMediaLinks = {};
  List<String> _linkOrder = [];
  bool _loaded = false;

  /// 8-stelliger Party-Code (nur Ziffern, nur Anzeige/Speicher lokal)
  String? get shortCode => _shortCode;

  /// Firestore-Dokument-ID der Party
  String? get partyId => _partyId;

  /// Name der Party (aus party_name)
  String? get partyName => _partyName;

  /// UID des DJs (created_by)
  String? get djId => _djId;

  /// Plan-Status: free, pro, pro_life, trial usw.
  String? get djPlan => _djPlan;

  /// Anzeige-Name des DJs
  String? get djName => _djName;

  /// Logo-URL des DJs (aus Party dj_logo)
  String? get djLogoUrl => _djLogoUrl;

  /// Social-Media-Links (Plattform-ID → URL), einmalig beim Login geladen
  Map<String, String> get socialMediaLinks => Map.unmodifiable(_socialMediaLinks);

  /// Reihenfolge der Social-Links für die Anzeige
  List<String> get linkOrder => List.unmodifiable(_linkOrder);

  /// Aktive Session vorhanden?
  bool get hasSession =>
      _partyId != null &&
      _partyId!.isNotEmpty &&
      _djId != null &&
      _djId!.isNotEmpty;

  /// DJ ist Pro (nicht free)
  bool get isPro =>
      _djPlan != null && _djPlan!.toString().toLowerCase() != 'free';

  /// Lädt persistierte Session aus SharedPreferences.
  /// Liest immer aus Prefs (kein Cache), damit Gast-Seiten nach Check-In aktuelle Daten erhalten.
  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _shortCode = prefs.getString(_keyShortCode);
      _partyId = prefs.getString(_keyPartyId);
      _partyName = prefs.getString(_keyPartyName);
      _djId = prefs.getString(_keyDjId);
      _djPlan = prefs.getString(_keyDjPlan);
      _djName = prefs.getString(_keyDjName);
      _djLogoUrl = prefs.getString(_keyDjLogoUrl);
      _socialMediaLinks = _parseSocialLinks(prefs.getString(_keySocialLinks));
      _linkOrder = _parseLinkOrder(prefs.getString(_keyLinkOrder));
      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }

  static Map<String, String> _parseSocialLinks(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final m = jsonDecode(json) as Map<String, dynamic>?;
      if (m == null) return {};
      return m.map((k, v) => MapEntry(k, (v as String?) ?? ''));
    } catch (_) {
      return {};
    }
  }

  static List<String> _parseLinkOrder(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final list = jsonDecode(json) as List<dynamic>?;
      return list?.map((e) => e.toString()).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Validiert den Party-Code (nur beim ersten Check-In), lädt Party + users-Daten,
  /// speichert in Session und Prefs. Gibt bei Fehler [PartyCheckInFeedback] zurück, bei Erfolg null.
  /// Nach erfolgreichem Join werden alle weiteren Operationen über partyId geführt.
  /// Alias für QR-/Deep-Link-Integration (gleiche Logik wie [validateAndJoin]).
  Future<PartyCheckInFeedback?> validateAndJoinParty(String code) =>
      validateAndJoin(code);

  Future<PartyCheckInFeedback?> validateAndJoin(String code) async {
    final digits = PartyCodeUtils.normalizeDigits(code.trim());
    if (digits.isEmpty || digits.length != PartyCodeUtils.codeLength) {
      return const PartyCheckInFeedback(type: PartyCheckInFeedbackType.wrongCode);
    }

    try {
      QuerySnapshot<Map<String, dynamic>> query = await FirebaseFirestore.instance
          .collection('parties')
          .where('party_code', isEqualTo: digits)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        final asInt = int.tryParse(digits);
        if (asInt != null) {
          query = await FirebaseFirestore.instance
              .collection('parties')
              .where('party_code', isEqualTo: asInt)
              .limit(1)
              .get();
        }
      }

      if (query.docs.isEmpty) {
        return const PartyCheckInFeedback(type: PartyCheckInFeedbackType.wrongCode);
      }

      final partyDoc = query.docs.first;
      return await _validateAndSaveFromPartyDoc(partyDoc, shortCodeFromInput: digits);
    } catch (e) {
      // Firestore Rules: parties und users haben allow read: if true (Gast-Lesezugriff).
      // Bei Permission Denied prüfe firestore.rules – Gäste müssen parties + users lesen dürfen.
      debugLog('PartySessionService validateAndJoin Fehler (evtl. Permission Denied): $e');
      return const PartyCheckInFeedback(type: PartyCheckInFeedbackType.wrongCode);
    }
  }

  /// Zentrale Bereinigung: Löscht die gesamte Gast-Session.
  /// Wird aufgerufen bei: (1) "Party verlassen", (2) Party vom DJ beendet/abgelaufen.
  /// Bei Pause-Status wird nichts gelöscht – Session bleibt bestehen.
  /// Speichert einen 8-stelligen Party-Code lokal, bis zur Bestätigung oder bis [clearSession].
  Future<void> persistPendingPartyCode(String? raw) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (raw == null || raw.trim().isEmpty) {
        await prefs.remove(_keyPendingPartyCode);
        return;
      }
      final digits = PartyCodeUtils.normalizeDigits(raw.trim());
      if (digits.length != PartyCodeUtils.codeLength) {
        await prefs.remove(_keyPendingPartyCode);
        return;
      }
      await prefs.setString(_keyPendingPartyCode, digits);
    } catch (_) {}
  }

  /// Nur Pending (ohne vollständige Session).
  Future<String?> getPendingPartyCodeDigits() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString(_keyPendingPartyCode);
      if (s == null || s.length != PartyCodeUtils.codeLength) return null;
      return s;
    } catch (_) {
      return null;
    }
  }

  /// Für Login/Anzeige: zuerst validierte Session, sonst Pending-Code.
  Future<String?> getStoredPartyCodeForDisplay() async {
    await loadFromPrefs();
    if (_shortCode != null && _shortCode!.isNotEmpty) {
      return _shortCode;
    }
    return getPendingPartyCodeDigits();
  }

  Future<void> clearSession() async {
    _shortCode = null;
    _partyId = null;
    _partyName = null;
    _djId = null;
    _djPlan = null;
    _djName = null;
    _djLogoUrl = null;
    _socialMediaLinks = {};
    _linkOrder = [];

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyShortCode);
      await prefs.remove(_keyPartyId);
      await prefs.remove(_keyPartyName);
      await prefs.remove(_keyDjId);
      await prefs.remove(_keyDjPlan);
      await prefs.remove(_keyDjName);
      await prefs.remove(_keyDjLogoUrl);
      await prefs.remove(_keySocialLinks);
      await prefs.remove(_keyLinkOrder);
      await prefs.remove(_keyPartyCode);
      await prefs.remove(_keyPendingPartyCode);
      await prefs.remove('guest_client_id');
    } catch (_) {}
  }

  /// Alias für clearSession() – Kompatibilität mit bestehendem Code.
  Future<void> clear() async => clearSession();

  /// Prüft, ob die Session vollständig ist (partyId + djId + djPlan).
  bool get _hasCompleteSession =>
      _partyId != null &&
      _partyId!.isNotEmpty &&
      _djId != null &&
      _djId!.isNotEmpty &&
      _djPlan != null;

  /// Validiert Party-Dokument und speichert Session. Wird von validateAndJoin und _hydrateFromPartyId genutzt.
  /// [shortCodeFromInput] nur bei Ersteinritt (validateAndJoin); bei Hydrierung aus partyData.
  Future<PartyCheckInFeedback?> _validateAndSaveFromPartyDoc(
    DocumentSnapshot<Map<String, dynamic>> partyDoc, {
    String? shortCodeFromInput,
  }) async {
    final partyId = partyDoc.id;
    final partyData = partyDoc.data();
    if (partyData == null) {
      return const PartyCheckInFeedback(type: PartyCheckInFeedbackType.wrongCode);
    }
    final now = DateTime.now();

    final lifecycleStatus = partyData['lifecycle_status'] as String?;
    final finishedAt = partyData['finished_at'];
    final status = partyData['status'] as String?;
    if (lifecycleStatus == 'finished' ||
        finishedAt != null ||
        status == 'beendet' ||
        status == 'ended') {
      return const PartyCheckInFeedback(type: PartyCheckInFeedbackType.partyEnded);
    }

    if (lifecycleStatus == 'standby') {
      return const PartyCheckInFeedback(
          type: PartyCheckInFeedbackType.invalidOrInactive);
    }

    DateTime? startDate;
    final startTs = partyData['start_date'] as Timestamp?;
    final startPosix = partyData['start_time_posix'];
    if (startTs != null) {
      startDate = startTs.toDate();
    } else if (startPosix is int) {
      startDate = DateTime.fromMillisecondsSinceEpoch(startPosix * 1000);
    }
    if (startDate != null && now.isBefore(startDate)) {
      return PartyCheckInFeedback(
          type: PartyCheckInFeedbackType.partyNotStarted,
          startDateTime: startDate);
    }

    DateTime? endDate;
    final endTs = partyData['end_date'] as Timestamp?;
    final endPosix = partyData['end_time_posix'];
    if (endTs != null) {
      endDate = endTs.toDate();
    } else if (endPosix is int) {
      endDate = DateTime.fromMillisecondsSinceEpoch(endPosix * 1000);
    }
    if (endDate != null && now.isAfter(endDate)) {
      return const PartyCheckInFeedback(type: PartyCheckInFeedbackType.partyEnded);
    }

    final djIdRaw = partyData['created_by'] ?? partyData['dj_code'];
    final djId = djIdRaw != null ? djIdRaw.toString().trim() : null;
    if (djId == null || djId.isEmpty || djId == 'manual') {
      return const PartyCheckInFeedback(
          type: PartyCheckInFeedbackType.invalidOrInactive);
    }

    String djPlan = 'free';
    String djName = 'DJ';
    try {
      final publicProfile = await PublicDjProfileService().fetchByUid(djId);
      if (publicProfile != null) {
        djPlan = publicProfile.planType;
        djName = (publicProfile.displayName != null &&
                publicProfile.displayName!.trim().isNotEmpty)
            ? publicProfile.displayName!
            : 'DJ';
      }
    } catch (_) {}

    final logoRaw = (partyData['dj_logo'] as String?)?.trim();
    final djLogoUrl = (logoRaw != null && logoRaw.isNotEmpty) ? logoRaw : null;

    final partyNameRaw = (partyData['party_name'] as String?)?.trim();
    final partyName = (partyNameRaw != null && partyNameRaw.isNotEmpty)
        ? partyNameRaw
        : null;

    // party_code kann in Firestore als String oder Number gespeichert sein
    final raw = partyData['party_code'];
    final fromDoc = raw != null ? raw.toString().trim() : '';
    final shortCode = shortCodeFromInput ?? fromDoc;

    // Alles-drin: Social-Links bei Pro-DJ einmalig mitladen
    Map<String, String> socialLinks = {};
    List<String> linkOrder = [];
    final isProDj = djPlan.toString().toLowerCase() != 'free';
    if (isProDj) {
      final loaded = await _loadSocialMediaLinksForDj(djId);
      socialLinks = loaded.links;
      linkOrder = loaded.order;
    }

    _shortCode = shortCode.isNotEmpty ? shortCode : _shortCode;
    _partyId = partyId;
    _partyName = partyName;
    _djId = djId;
    _djPlan = djPlan;
    _djName = djName;
    _djLogoUrl = djLogoUrl;
    _socialMediaLinks = socialLinks;
    _linkOrder = linkOrder;
    _loaded = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPartyId, partyId);
    if (partyName != null) await prefs.setString(_keyPartyName, partyName);
    if (shortCode.isNotEmpty) {
      await prefs.setString(_keyShortCode, shortCode);
      await prefs.setString(_keyPartyCode, shortCode);
    }
    await prefs.setString(_keyDjId, djId);
    await prefs.setString(_keyDjPlan, djPlan);
    await prefs.setString(_keyDjName, djName);
    if (djLogoUrl != null) {
      await prefs.setString(_keyDjLogoUrl, djLogoUrl);
    }
    await prefs.setString(_keySocialLinks, jsonEncode(socialLinks));
    await prefs.setString(_keyLinkOrder, jsonEncode(linkOrder));
    try {
      await prefs.remove(_keyPendingPartyCode);
    } catch (_) {}
    return null;
  }

  /// Lädt Social-Media-Links für einen DJ aus Firestore.
  Future<({Map<String, String> links, List<String> order})> _loadSocialMediaLinksForDj(
    String djId,
  ) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('social_media_links')
          .doc(djId)
          .get();
      if (!doc.exists || doc.data() == null) {
        return (links: <String, String>{}, order: <String>[]);
      }
      final data = doc.data()!;
      final links = <String, String>{};
      for (final e in data.entries) {
        if (e.key != 'updated_at' && e.key != 'order' &&
            e.value is String &&
            (e.value as String).trim().isNotEmpty) {
          links[e.key] = e.value as String;
        }
      }
      List<String> order = [];
      if (data['order'] is List) {
        order = (data['order'] as List)
            .map((e) => e.toString())
            .where(links.containsKey)
            .toList();
        for (final k in links.keys) {
          if (!order.contains(k)) order.add(k);
        }
      } else {
        order = links.keys.toList();
      }
      return (links: links, order: order);
    } catch (_) {
      return (links: <String, String>{}, order: <String>[]);
    }
  }

  /// Hydratiert die Session nach App-Neustart.
  /// Prüft ob Party noch aktiv ist. NUR bei expliziter Party-Ende → clearSession().
  /// Bei Fehlern/Netzwerk/Doc nicht gefunden: Session BEHALTEN (Daten aus Prefs).
  Future<bool> hydrateIfNeeded() async {
    await loadFromPrefs();

    final partyId = _partyId ?? (await SharedPreferences.getInstance()).getString(_keyPartyId);
    if (partyId == null || partyId.isEmpty) return false;

    try {
      final partyDoc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .get();

      // Doc nicht gefunden oder leer: Session BEHALTEN (Netzwerkfehler etc.)
      if (!partyDoc.exists || partyDoc.data() == null) {
        return hasSession;
      }

      final partyData = partyDoc.data()!;
      final lifecycleStatus = partyData['lifecycle_status'] as String?;
      final finishedAt = partyData['finished_at'];
      final status = partyData['status'] as String?;

      // NUR bei expliziter Party-Ende → clearSession
      if (lifecycleStatus == 'finished' ||
          finishedAt != null ||
          status == 'beendet' ||
          status == 'ended') {
        await clearSession();
        return false;
      }

      final now = DateTime.now();
      final endTs = partyData['end_date'] as Timestamp?;
      final endPosix = partyData['end_time_posix'];
      DateTime? endDate;
      if (endTs != null) {
        endDate = endTs.toDate();
      } else if (endPosix is int) {
        endDate = DateTime.fromMillisecondsSinceEpoch(endPosix * 1000);
      }
      if (endDate != null && now.isAfter(endDate)) {
        await clearSession();
        return false;
      }

      // Pause (standby): Session behalten
      if (lifecycleStatus == 'standby') {
        return hasSession;
      }

      // Party aktiv: Vollständige Session?
      if (_hasCompleteSession) {
        // Fehlende Social-Links nachladen (z.B. nach App-Kill)
        if (isPro &&
            _djId != null &&
            _socialMediaLinks.isEmpty) {
          final loaded = await _loadSocialMediaLinksForDj(_djId!);
          _socialMediaLinks = loaded.links;
          _linkOrder = loaded.order;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keySocialLinks, jsonEncode(_socialMediaLinks));
          await prefs.setString(_keyLinkOrder, jsonEncode(_linkOrder));
        }
        return true;
      }

      // Unvollständige Session: komplette Hydrierung aus Party-Dokument
      final feedback = await _validateAndSaveFromPartyDoc(partyDoc);
      if (feedback != null) {
        // Fehler (z.B. Party nicht gestartet): Session BEHALTEN, nicht clearen
        return hasSession;
      }
      return true;
    } catch (e) {
      // Bei Exception: Session BEHALTEN (Netzwerk etc.)
      return hasSession;
    }
  }
}
