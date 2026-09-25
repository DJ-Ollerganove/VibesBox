import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dj_b2b_service.dart';
import '../utils/debug_log.dart';

/// Pending DJ-B2B-Code vom Invite-Link (Web / Deep Link / Store-Attribution) bis Trial-Einlösung.
class PendingReferralService {
  PendingReferralService._();
  static final PendingReferralService instance = PendingReferralService._();

  static const _prefsCode = 'vb_dj_b2b_code';
  static const _prefsCapturedAt = 'vb_dj_b2b_captured_at';
  static const _prefsAttrChecked = 'vb_dj_b2b_attr_checked_v1';

  /// Marker in der Zwischenablage (Invite-Landing → App nach Store-Install).
  static const clipboardPrefix = 'VibesBoxB2B:';

  Future<void> saveCode(String code, {String? capturedAtIso}) async {
    final normalized = DjB2bService.normalizeCode(code);
    if (normalized == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsCode, normalized);
    await prefs.setString(
      _prefsCapturedAt,
      capturedAtIso ?? DateTime.now().toUtc().toIso8601String(),
    );
    debugLog('PendingReferral: Code gespeichert ($normalized)');
  }

  Future<String?> peekCode() async {
    final prefs = await SharedPreferences.getInstance();
    return DjB2bService.normalizeCode(prefs.getString(_prefsCode));
  }

  Future<String?> capturedAtIso() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsCapturedAt);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsCode);
    await prefs.remove(_prefsCapturedAt);
  }

  /// Aus Deep-Link `/invite/DJ######` oder `?code=`.
  Future<bool> ingestInviteUri(Uri uri) async {
    final code = _extractFromUri(uri);
    if (code == null) return false;
    await saveCode(code);
    return true;
  }

  /// Einmalig nach Fresh-Install: Play Install Referrer (Android) + Clipboard-Bridge.
  Future<void> captureDeferredAttribution() async {
    if (kIsWeb) return;
    final existing = await peekCode();
    if (existing != null) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefsAttrChecked) == true) return;
    await prefs.setBool(_prefsAttrChecked, true);

    if (!kIsWeb && Platform.isAndroid) {
      final fromPlay = await _captureFromPlayInstallReferrer();
      if (fromPlay) return;
    }

    await _captureFromClipboard();
  }

  Future<bool> _captureFromPlayInstallReferrer() async {
    try {
      final details = await PlayInstallReferrer.installReferrer;
      final raw = details.installReferrer;
      final code = extractCodeFromInstallReferrer(raw);
      if (code == null) {
        debugLog('PendingReferral: Play Referrer ohne Code ($raw)');
        return false;
      }
      await saveCode(code);
      debugLog('PendingReferral: Code aus Play Install Referrer ($code)');
      return true;
    } catch (e) {
      debugLog('PendingReferral: Play Install Referrer fehlgeschlagen: $e');
      return false;
    }
  }

  Future<bool> _captureFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      final code = extractCodeFromClipboardText(text);
      if (code == null) return false;
      await saveCode(code);
      debugLog('PendingReferral: Code aus Zwischenablage ($code)');
      return true;
    } catch (e) {
      debugLog('PendingReferral: Clipboard-Read fehlgeschlagen: $e');
      return false;
    }
  }

  /// `utm_content=DJ######` / `dj_b2b=DJ######` / freistehendes `DJ######`.
  static String? extractCodeFromInstallReferrer(String? referrer) {
    if (referrer == null || referrer.trim().isEmpty) return null;
    var s = referrer.trim();
    try {
      s = Uri.decodeQueryComponent(s);
    } catch (_) {}
    try {
      s = Uri.decodeQueryComponent(s);
    } catch (_) {}

    Map<String, String> q = {};
    try {
      q = Uri.splitQueryString(s);
    } catch (_) {}
    final fromQuery = DjB2bService.normalizeCode(
      q['utm_content'] ?? q['dj_b2b'] ?? q['code'],
    );
    if (fromQuery != null) return fromQuery;

    final m = RegExp(r'DJ\d{6}', caseSensitive: false).firstMatch(s);
    return DjB2bService.normalizeCode(m?.group(0));
  }

  static String? extractCodeFromClipboardText(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final marked = RegExp(
      r'VibesBoxB2B:\s*(DJ\d{6})',
      caseSensitive: false,
    ).firstMatch(t);
    if (marked != null) {
      return DjB2bService.normalizeCode(marked.group(1));
    }
    // Nur exakter Code, kein Freitext-Scan (weniger Fehlalarme).
    return DjB2bService.normalizeCode(t);
  }

  static String clipboardPayloadForCode(String code) {
    final n = DjB2bService.normalizeCode(code) ?? code.trim().toUpperCase();
    return '$clipboardPrefix$n';
  }

  static String? _extractFromUri(Uri uri) {
    final segments = uri.pathSegments;
    final inviteIdx = segments.indexOf('invite');
    if (inviteIdx >= 0 && inviteIdx + 1 < segments.length) {
      final fromPath = DjB2bService.normalizeCode(segments[inviteIdx + 1]);
      if (fromPath != null) return fromPath;
    }
    return DjB2bService.normalizeCode(uri.queryParameters['code']);
  }
}
