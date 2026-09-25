import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'pending_referral_service.dart';
import '../utils/debug_log.dart';

/// Serverseitiges DJ B2B — Codes, Trial, Ledger, Verbrauch.
class DjB2bService {
  DjB2bService._();
  static final DjB2bService instance = DjB2bService._();

  static const _region = 'us-central1';
  static final _functions = FirebaseFunctions.instanceFor(region: _region);

  Future<Map<String, dynamic>> ensureCode() async {
    final result = await _functions.httpsCallable('ensureDjB2bCode').call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> getOverview() async {
    final result = await _functions.httpsCallable('getDjB2bOverview').call();
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> redeemCode(
    String code, {
    bool activateTrial = false,
    String source = 'manual',
  }) async {
    await _functions.httpsCallable('redeemDjB2bCode').call({
      'code': code,
      'activateTrial': activateTrial,
      'source': source,
    });
  }

  /// Prüft, ob der Code in `referral_codes` existiert (ohne einzulösen).
  /// Liefert die Werber-UID oder `null`.
  Future<String?> lookupReferrerUid(String? rawCode) async {
    final code = normalizeCode(rawCode);
    if (code == null) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('referral_codes')
          .doc(code)
          .get();
      final uid = snap.data()?['uid'];
      if (!snap.exists || uid is! String || uid.trim().isEmpty) return null;
      final referrerUid = uid.trim();
      final self = FirebaseAuth.instance.currentUser?.uid;
      if (self != null && self == referrerUid) return null;
      return referrerUid;
    } catch (e) {
      debugLog('DJ B2B lookupReferrerUid: $e');
      return null;
    }
  }

  /// Pending-Code (Link/Registrierung) am eingeloggten User einlösen — ohne Trial.
  /// `linked` | `skipped` | `invalid` | `error`
  Future<String> tryRedeemPendingReferral({required String source}) async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null) return 'skipped';

    final pending = await PendingReferralService.instance.peekCode();
    if (pending == null) return 'skipped';

    try {
      await redeemCode(pending, activateTrial: false, source: source);
      await PendingReferralService.instance.clear();
      debugLog('DJ B2B: Pending eingelöst ($source, $pending)');
      return 'linked';
    } on FirebaseFunctionsException catch (e) {
      final msg = (e.message ?? '').toLowerCase();
      if (e.code == 'failed-precondition' && msg.contains('already redeemed')) {
        await PendingReferralService.instance.clear();
        return 'skipped';
      }
      if (e.code == 'invalid-argument' ||
          e.code == 'not-found' ||
          msg.contains('invalid') ||
          msg.contains('not found') ||
          msg.contains('self-referral')) {
        logFunctionsError(e, 'tryRedeemPending invalid');
        return 'invalid';
      }
      logFunctionsError(e, 'tryRedeemPending');
      return 'error';
    } catch (e) {
      debugLog('DJ B2B tryRedeemPending: $e');
      return 'error';
    }
  }

  Future<Map<String, dynamic>> activateTrial({String? b2bCode}) async {
    final payload = <String, dynamic>{};
    final c = normalizeCode(b2bCode);
    if (c != null) payload['b2bCode'] = c;
    final result =
        await _functions.httpsCallable('activateDjTrial').call(payload);
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<void> startConsumption() async {
    await _functions.httpsCallable('startDjB2bConsumption').call();
  }

  Future<void> stopConsumption() async {
    await _functions.httpsCallable('stopDjB2bConsumption').call();
  }

  /// Arabische / persische / fullwidth Ziffern → ASCII `0`–`9`.
  static String foldDigits(String input) {
    final buf = StringBuffer();
    for (final r in input.runes) {
      if (r >= 0x30 && r <= 0x39) {
        buf.writeCharCode(r);
      } else if (r >= 0x0660 && r <= 0x0669) {
        buf.writeCharCode(0x30 + (r - 0x0660));
      } else if (r >= 0x06F0 && r <= 0x06F9) {
        buf.writeCharCode(0x30 + (r - 0x06F0));
      } else if (r >= 0xFF10 && r <= 0xFF19) {
        buf.writeCharCode(0x30 + (r - 0xFF10));
      } else {
        buf.writeCharCode(r);
      }
    }
    return buf.toString();
  }

  /// Nur die 6 Ziffern des Codes (ohne `DJ`), für Eingabefelder.
  static String digitsOnly(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    var s = foldDigits(raw).trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (s.startsWith('DJ')) s = s.substring(2);
    s = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (s.length > 6) s = s.substring(0, 6);
    return s;
  }

  /// Akzeptiert `DJ######` oder nur `######` (6 Ziffern). Format bleibt intern `DJ######`.
  static String? normalizeCode(String? raw) {
    if (raw == null) return null;
    var c = foldDigits(raw).trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (RegExp(r'^\d{6}$').hasMatch(c)) c = 'DJ$c';
    if (RegExp(r'^DJ\d{6}$').hasMatch(c)) return c;
    return null;
  }

  static String inviteUrlForCode(String code) =>
      'https://vibesbox.app/invite/$code';

  static void logFunctionsError(Object e, String context) {
    if (e is FirebaseFunctionsException) {
      debugLog('DJ B2B $context: ${e.code} ${e.message}');
    } else {
      debugLog('DJ B2B $context: $e');
    }
  }
}
