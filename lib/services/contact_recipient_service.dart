import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../utils/debug_log.dart';

class ContactRecipientResult {
  final String toEmail;
  final String? partyId;
  final String? partyCode;
  final String? partyName;
  final String? djUserId;

  const ContactRecipientResult({
    required this.toEmail,
    this.partyId,
    this.partyCode,
    this.partyName,
    this.djUserId,
  });
}

class ContactRecipientService {
  static const String _region = 'us-central1';

  /// Globaler Pro-/Premium-Check für DJs.
  ///
  /// Erwartete Felder im `users/{djId}`-Dokument (Beispiele, robust geprüft):
  /// - `isPro == true`
  /// - `plan == 'pro' | 'premium'`
  ///
  /// Fehler-Handling (wichtig): Wenn das DJ-Dokument nicht geladen werden kann,
  /// wird **false** zurückgegeben (sicherer Fallback auf Admin-E-Mail).
  // TODO: Re-enable Pro-Check after Test Phase
  static Future<bool> checkDjSubscriptionStatus(String djId) async {
    // ✅ TEST-MODUS: Pro-Check deaktiviert - immer true zurückgeben
    return true;

    /* ✅ ORIGINAL-CODE (auskommentiert für später):
    if (djId.isEmpty || djId == 'manual') return false;

    try {
      final djDoc = await FirebaseFirestore.instance.collection('users').doc(djId).get();
      if (!djDoc.exists) return false;

      final data = djDoc.data();
      if (data == null) return false;

      final isPro = data['isPro'] == true;
      final planRaw = data['plan'];
      final plan = planRaw is String ? planRaw.trim().toLowerCase() : null;

      // Erlaubte Pläne: pro/premium
      final hasPlan = plan == 'pro' || plan == 'premium';

      return isPro || hasPlan;
    } catch (e) {
      debugLog('❌ Pro-Check: Fehler beim Laden des DJ-Dokuments (djId=$djId): $e');
      return false;
    }
    */
  }

  /// Alias für den Pro-Check (für Wiederverwendung in anderen Features, z.B. Musikerkennung-Limits).
  /// Diese Funktion ist die bevorzugte API nach außen.
  // TODO: Re-enable Pro-Check after Test Phase
  static Future<bool> isDjPro(String djId) async {
    return true;
  }

  /// Ermittelt den Empfänger für Kontaktanfragen (serverseitig — kein Client-Lesezugriff auf `users`).
  static Future<ContactRecipientResult> resolveRecipient({
    String? partyId,
    String? partyCode,
  }) async {
    String? effectivePartyCode = partyCode;
    if (effectivePartyCode == null || effectivePartyCode.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        effectivePartyCode = prefs.getString('party_code');
      } catch (_) {}
    }

    final pid =
        (partyId != null && partyId.isNotEmpty && partyId != 'manual')
        ? partyId
        : null;
    final pc =
        (effectivePartyCode != null &&
            effectivePartyCode.isNotEmpty &&
            effectivePartyCode != 'manual')
        ? effectivePartyCode
        : null;

    try {
      final callable = FirebaseFunctions.instanceFor(
        region: _region,
      ).httpsCallable('resolveContactRecipient');
      final payload = <String, dynamic>{
        'appSecurityKey': AppConfig.contactAppSecurityKey,
        if (pid != null) 'partyId': pid,
        if (pc != null) 'partyCode': pc,
      };
      final res = await callable.call<Map<String, dynamic>>(payload);
      final data = res.data;
      if (data['success'] != true) {
        return const ContactRecipientResult(toEmail: AppConfig.adminEmail);
      }
      final to = data['toEmail'] as String?;
      return ContactRecipientResult(
        toEmail: (to != null && to.trim().isNotEmpty) ? to.trim() : AppConfig.adminEmail,
        partyId: data['partyId'] as String?,
        partyCode: data['partyCode'] as String?,
        partyName: data['partyName'] as String?,
        djUserId: data['djUserId'] as String?,
      );
    } catch (e) {
      debugLog('❌ Kontakt-Empfänger (resolveContactRecipient): $e');
      return const ContactRecipientResult(toEmail: AppConfig.adminEmail);
    }
  }
}
