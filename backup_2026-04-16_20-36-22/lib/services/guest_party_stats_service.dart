import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Gast-Logging Wunschbox: wie PWA — `parties/{partyId}/guests/{clientId}` + `total_guest_count`,
/// plus optionales `party_stats`-Event. Deduplizierung über SharedPreferences (Gerät/Party),
/// mit Firestore-Existenzprüfung als Fallback.
class GuestPartyStatsService {
  GuestPartyStatsService._();
  static final GuestPartyStatsService instance = GuestPartyStatsService._();

  static final Set<String> _sessionPartyStatsKeys = <String>{};

  static String normalizeLanguageCode(String raw) {
    var s = raw.trim().toLowerCase();
    if (s.isEmpty) return 'en';
    s = s.split(RegExp(r'[-_]')).first.replaceAll(RegExp(r'[^a-z]'), '');
    if (s.length >= 2) return s.substring(0, 2);
    return 'en';
  }

  static String _prefsKeyCounted(String partyId) =>
      'wishbox_guest_counted_${partyId.trim()}';

  static String _prefsKeyLang(String partyId) =>
      'wishbox_guest_lang_${partyId.trim()}';

  /// Wie PWA `language_stats_date`: höchstens ein globaler Hit pro Kalendertag (ohne Sprachwechsel).
  static const String _prefsGlobalLanguageStatsDay = 'language_stats_date';

  static String _todayYyyyMmDd() {
    final n = DateTime.now().toLocal();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year}-$m-$d';
  }

  /// Cloud Function `recordLanguageHit` → `language_stats/{code}` (Fire & Forget).
  static Future<void> _postRecordLanguageHit(String normalizedLang) async {
    final code = normalizeLanguageCode(normalizedLang);
    try {
      final url = Uri.parse(AppConfig.recordLanguageHitFunctionUrl);
      await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'languageCode': code,
              'source': 'flutter_app',
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  /// Global: 1× pro Tag wie PWA; zusätzlich bei echtem Sprachwechsel (Wunschbox) erneut.
  static Future<void> _syncGlobalLanguageStats({
    required SharedPreferences prefs,
    required String lang,
    required String? lastSyncedLangForParty,
  }) async {
    final today = _todayYyyyMmDd();
    final storedDay = prefs.getString(_prefsGlobalLanguageStatsDay);
    final dailySlotFree = storedDay != today;

    final hadPartyLangBefore = lastSyncedLangForParty != null;
    final partyLangChanged =
        hadPartyLangBefore && lastSyncedLangForParty != lang;

    if (!partyLangChanged && !dailySlotFree) return;

    await _postRecordLanguageHit(lang);
    if (dailySlotFree) {
      await prefs.setString(_prefsGlobalLanguageStatsDay, today);
    }
  }

  /// `true`, wenn der Nutzer mit E-Mail/Passwort angemeldet ist (kein Anonymous, kein reines Social-Login).
  static bool isEmailPasswordAccount(User? user) {
    if (user == null || user.isAnonymous) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  static String platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  /// Erster Wunschbox-Öffnen-Kontakt pro Party: ggf. Batch Gast-Dokument + `total_guest_count`;
  /// bei späterem Sprachwechsel nur `language` / `last_seen` am Gast-Dokument (kein zweites +1).
  Future<void> onWishboxOpenedForParty({
    required String partyId,
    required String clientId,
    required String languageCode,
    required bool isLoggedInEmailPassword,
  }) async {
    final trimmedParty = partyId.trim();
    final trimmedClient = clientId.trim();
    if (trimmedParty.isEmpty ||
        trimmedParty == 'manual' ||
        trimmedClient.isEmpty) {
      return;
    }

    final lang = normalizeLanguageCode(languageCode);
    final prefs = await SharedPreferences.getInstance();
    final countKey = _prefsKeyCounted(trimmedParty);
    final langKey = _prefsKeyLang(trimmedParty);
    final alreadyCounted = prefs.getBool(countKey) ?? false;
    final lastSyncedLang = prefs.getString(langKey);

    final db = FirebaseFirestore.instance;
    final guestRef = db
        .collection('parties')
        .doc(trimmedParty)
        .collection('guests')
        .doc(trimmedClient);
    final partyRef = db.collection('parties').doc(trimmedParty);

    try {
      if (!alreadyCounted) {
        final snap = await guestRef.get();
        if (snap.exists) {
          await prefs.setBool(countKey, true);
          if (lastSyncedLang != lang) {
            await guestRef.update({
              'language': lang,
              'last_seen': FieldValue.serverTimestamp(),
            });
          }
          await prefs.setString(langKey, lang);
        } else {
          final batch = db.batch();
          batch.set(
            guestRef,
            {
              'client_id': trimmedClient,
              'last_seen': FieldValue.serverTimestamp(),
              'language': lang,
            },
            SetOptions(merge: true),
          );
          batch.update(partyRef, {
            'total_guest_count': FieldValue.increment(1),
          });
          await batch.commit();
          await prefs.setBool(countKey, true);
          await prefs.setString(langKey, lang);
        }
      } else {
        final snap = await guestRef.get();
        if (!snap.exists) {
          await guestRef.set(
            {
              'client_id': trimmedClient,
              'last_seen': FieldValue.serverTimestamp(),
              'language': lang,
            },
            SetOptions(merge: true),
          );
        } else if (lastSyncedLang != lang) {
          await guestRef.update({
            'language': lang,
            'last_seen': FieldValue.serverTimestamp(),
          });
        }
        await prefs.setString(langKey, lang);
      }
    } catch (_) {
      // Gast-Firestore optional; globale Sprach-Statistik trotzdem unten
    }

    await _syncGlobalLanguageStats(
      prefs: prefs,
      lang: lang,
      lastSyncedLangForParty: lastSyncedLang,
    );

    final dedupeKey = '${trimmedClient}_$trimmedParty';
    await logWishboxViewIfFirstInSession(
      dedupeKey: dedupeKey,
      partyId: trimmedParty,
      languageCode: lang,
      isLoggedInEmailPassword: isLoggedInEmailPassword,
    );
  }

  /// Zusätzliches `party_stats`-Event: einmal pro App-Sitzung und Party (wie zuvor in-memory).
  Future<void> logWishboxViewIfFirstInSession({
    required String dedupeKey,
    required String partyId,
    required String languageCode,
    required bool isLoggedInEmailPassword,
  }) async {
    final trimmedParty = partyId.trim();
    if (trimmedParty.isEmpty || trimmedParty == 'manual') return;

    if (!_sessionPartyStatsKeys.add(dedupeKey)) return;

    try {
      await FirebaseFirestore.instance.collection('party_stats').add({
        'party_id': trimmedParty,
        'language': languageCode.trim().isNotEmpty ? languageCode.trim() : 'und',
        'is_logged_in_user': isLoggedInEmailPassword,
        'platform': platformLabel(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      _sessionPartyStatsKeys.remove(dedupeKey);
    }
  }
}
