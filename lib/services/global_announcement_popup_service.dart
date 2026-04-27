import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/debug_log.dart';

/// Prüft Ankündigungen der letzten 30 Tage und zeigt sie sequenziell,
/// falls sie noch nicht in read_announcements im User-Dokument stehen.
/// Wird nur aus [MainPage] aufgerufen, wenn der Nutzer im **DJ-Bereich** ist (nicht Gast-Rolle/Ansicht).
/// Pro App-Start wird die Datenbankabfrage nur einmal ausgeführt (Session-Schutz).
class GlobalAnnouncementPopupService {
  static bool _hasCheckedThisSession = false;

  /// translations aus Firestore: immer als Map auslesen (Sprachcode -> {subject, message}). Kein List-Cast.
  static Map<String, dynamic> _safeTranslationsMap(Map<String, dynamic>? data) {
    final raw = data?['translations'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  /// Einzelne Sprach-Map aus translations für einen Sprachcode; Map mit subject/message.
  static Map<String, dynamic> _safeLangMap(Map<String, dynamic> translations, String langCode) {
    final raw = translations[langCode];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  /// Liest die Liste der gelesenen Ankündigungs-IDs aus users/{uid}. read_announcements kann List oder Map sein.
  static List<String> _readAnnouncementIds(Map<String, dynamic>? userData) {
    final raw = userData?['read_announcements'];
    if (raw is List) {
      return raw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }
    if (raw is Map) {
      return raw.keys.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  /// Einmal pro Session aufrufen (z. B. nach Login). Lädt Ankündigungen der letzten 30 Tage
  /// und zeigt ungelesene nacheinander an. Erst nach "Gelesen/OK" erscheint die nächste.
  /// Firestore-Feld [targets]: fehlt / all / djs → sichtbar (hier); feine Steuerung „nur DJ-Shell“ in [MainPage].
  static bool _isTargetForDj(Map<String, dynamic>? data) {
    final targets = data?['targets'];
    if (targets == null) return true;
    if (targets == 'all' || targets == 'djs') return true;
    if (targets is List) return targets.contains('all') || targets.contains('djs');
    if (targets is Map) return true;
    return true;
  }

  static Future<void> checkAndShowIfNeeded(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userId = user.uid;
    debugLog('DEBUG [Popup]: checkAndShowIfNeeded gestartet');

    if (_hasCheckedThisSession) {
      debugLog('DEBUG [Popup]: Bereits in dieser Session geprüft – überspringe.');
      return;
    }

    try {
      _hasCheckedThisSession = true;

      final now = DateTime.now();
      final limit = now.subtract(const Duration(days: 30));
      final limitTimestamp = Timestamp.fromDate(limit);

      final snapshot = await FirebaseFirestore.instance
          .collection('global_announcements')
          .where('createdAt', isGreaterThanOrEqualTo: limitTimestamp)
          .orderBy('createdAt', descending: false)
          .get();

      debugLog('DEBUG [Popup]: Anzahl gefundener Ankündigungen in DB: ${snapshot.docs.length}');

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      final readList = _readAnnouncementIds(userDoc.data());

      final allDocs = snapshot.docs;
      final unreadDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final doc in allDocs) {
        final data = doc.data();
        final isRead = readList.contains(doc.id);
        final isTarget = _isTargetForDj(data);
        debugLog('DEBUG [Popup]: Prüfe Ankündigung ID: ${doc.id}');
        debugLog('DEBUG [Popup]: Ist bereits gelesen? $isRead');
        debugLog('DEBUG [Popup]: Targets: ${data['targets']}');
        if (!isRead && isTarget) unreadDocs.add(doc);
      }
      if (unreadDocs.isEmpty) return;

      debugLog('DEBUG [Popup]: Ungelesen und für DJ sichtbar: ${unreadDocs.length}');
      if (!context.mounted) return;
      await _showNextInSequence(context, userId, unreadDocs, 0);
    } catch (e, st) {
      debugLog('DEBUG [Popup]: Fehler in checkAndShowIfNeeded: $e');
      debugLog('DEBUG [Popup]: $st');
      _hasCheckedThisSession = false;
    }
  }

  /// Zeigt die n-te ungelesene Ankündigung; nach "Gelesen/OK" wird die ID gespeichert und ggf. die nächste angezeigt.
  static Future<void> _showNextInSequence(
    BuildContext context,
    String userId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> unreadDocs,
    int index,
  ) async {
    if (index >= unreadDocs.length) return;
    final doc = unreadDocs[index];
    final id = doc.id;
    final data = doc.data();
    // translations in Firestore ist eine Map (kein List): { "de": { subject, message }, "en": { ... }, ... }
    final translations = _safeTranslationsMap(data);
    final currentLanguageCode = Localizations.localeOf(context).languageCode.toLowerCase().split('-').first;
    // Text für aktuelle Sprache des DJs direkt über Key; Fallback en, dann de
    Map<String, dynamic> langMap = _safeLangMap(translations, currentLanguageCode);
    if (langMap.isEmpty) langMap = _safeLangMap(translations, 'en');
    if (langMap.isEmpty) langMap = _safeLangMap(translations, 'de');
    if (langMap.isEmpty) {
      await _showNextInSequence(context, userId, unreadDocs, index + 1);
      return;
    }

    final subject = (langMap['subject'] as String?)?.trim() ?? '';
    final message = (langMap['message'] as String?)?.trim() ?? '';
    if (subject.isEmpty && message.isEmpty) {
      await _showNextInSequence(context, userId, unreadDocs, index + 1);
      return;
    }

    final userClickedOk = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          title: Text(
            subject.isEmpty ? l10n.global_announcement_default_title : subject,
            style: const TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Text(
              message.isEmpty ? subject : message,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                l10n.global_announcement_read_ok,
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        );
      },
    );

    if (userClickedOk == true) {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'read_announcements': FieldValue.arrayUnion([id]),
      }, SetOptions(merge: true));
    }

    if (!context.mounted) return;
    await _showNextInSequence(context, userId, unreadDocs, index + 1);
  }
}
