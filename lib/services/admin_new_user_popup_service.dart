import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../utils/debug_log.dart';
import '../utils/ui_constants.dart';

/// Admin: einmaliges Popup je neuem DJ-/Gast-Konto (Registrierungs-Infos).
///
/// Läuft für echte Admins in Admin- und DJ-Ansicht.
/// - Bootstrap: bestehende User werden beim ersten Start als „gesehen“ markiert
///   (kein Popup-Sturm).
/// - Danach: Listener auf die jüngsten User; ungelesen → Dialog; nach OK nie wieder
///   (SharedPreferences je Admin-UID).
class AdminNewUserPopupService {
  AdminNewUserPopupService._();
  static final AdminNewUserPopupService instance = AdminNewUserPopupService._();

  static const String _seenKeyPrefix = 'admin_seen_new_user_ids_v1_';
  static const String _bootKeyPrefix = 'admin_new_user_bootstrapped_v1_';
  static const int _queryLimit = 30;
  static const int _maxSeenStored = 800;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  String? _activeAdminUid;
  bool _showing = false;
  final List<_NewUserInfo> _queue = [];
  final Set<String> _queuedOrShowingIds = {};
  BuildContext? _hostContext;

  static void resetSessionForLogout() {
    instance.stop();
  }

  void stop() {
    unawaited(_sub?.cancel());
    _sub = null;
    _activeAdminUid = null;
    _hostContext = null;
    _showing = false;
    _queue.clear();
    _queuedOrShowingIds.clear();
  }

  /// Startet (oder aktualisiert) den Listener, sobald Admin-Ansicht freigeschaltet ist.
  Future<void> ensureStarted(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      stop();
      return;
    }
    _hostContext = context;
    if (_activeAdminUid == user.uid && _sub != null) return;

    stop();
    _activeAdminUid = user.uid;
    _hostContext = context;

    try {
      await _bootstrapIfNeeded(user.uid);
      _sub = FirebaseFirestore.instance
          .collection('users')
          .orderBy('created_at', descending: true)
          .limit(_queryLimit)
          .snapshots()
          .listen(
            (snap) => unawaited(_onSnapshot(user.uid, snap)),
            onError: (Object e) {
              debugLog('AdminNewUserPopup: snapshot error: $e');
            },
          );
    } catch (e) {
      debugLog('AdminNewUserPopup: start failed: $e');
      stop();
    }
  }

  Future<void> _bootstrapIfNeeded(String adminUid) async {
    final prefs = await SharedPreferences.getInstance();
    final bootKey = '$_bootKeyPrefix$adminUid';
    if (prefs.getBool(bootKey) == true) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('created_at', descending: true)
        .limit(_queryLimit)
        .get();

    final seen = await _loadSeen(adminUid);
    for (final doc in snap.docs) {
      seen.add(doc.id);
    }
    await _saveSeen(adminUid, seen);
    await prefs.setBool(bootKey, true);
    debugLog(
      'AdminNewUserPopup: bootstrap – ${snap.docs.length} bestehende User als gesehen',
    );
  }

  Future<void> _onSnapshot(
    String adminUid,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    if (_activeAdminUid != adminUid) return;
    final seen = await _loadSeen(adminUid);
    final fresh = <_NewUserInfo>[];

    for (final doc in snap.docs) {
      if (seen.contains(doc.id) || _queuedOrShowingIds.contains(doc.id)) {
        continue;
      }
      final info = _NewUserInfo.tryParse(doc);
      if (info == null) continue;
      fresh.add(info);
    }

    // Älteste zuerst, damit Reihenfolge der Registrierung stimmt.
    fresh.sort((a, b) {
      final at = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bt = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return at.compareTo(bt);
    });

    for (final info in fresh) {
      _queuedOrShowingIds.add(info.uid);
      _queue.add(info);
    }
    if (!_showing) {
      unawaited(_drainQueue());
    }
  }

  Future<void> _drainQueue() async {
    if (_showing) return;
    while (_queue.isNotEmpty) {
      final ctx = _hostContext;
      if (ctx == null || !ctx.mounted) {
        _queue.clear();
        _queuedOrShowingIds.clear();
        return;
      }
      final next = _queue.removeAt(0);
      _showing = true;
      try {
        await _showDialog(ctx, next);
        final uid = _activeAdminUid;
        if (uid != null) {
          final seen = await _loadSeen(uid);
          seen.add(next.uid);
          await _saveSeen(uid, seen);
        }
      } catch (e) {
        debugLog('AdminNewUserPopup: dialog error: $e');
      } finally {
        _showing = false;
        _queuedOrShowingIds.remove(next.uid);
      }
    }
  }

  Future<void> _showDialog(BuildContext context, _NewUserInfo info) async {
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final created =
        info.createdAt != null ? df.format(info.createdAt!.toLocal()) : '–';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: UIConstants.djShellPageBackground,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: UIConstants.appOrange, width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                info.roleKind == AppRoleKind.dj
                    ? Icons.headphones
                    : Icons.person_add_alt_1,
                color: UIConstants.appOrange,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info.roleKind == AppRoleKind.dj
                      ? 'Neuer DJ'
                      : 'Neuer Gast',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Name', info.displayName),
                if (info.realName != null && info.realName!.isNotEmpty)
                  _row('Klarname', info.realName!),
                _row('E-Mail', info.email),
                if (info.phone != null && info.phone!.isNotEmpty)
                  _row('Telefon', info.phone!),
                if (info.country != null && info.country!.isNotEmpty)
                  _row('Land', info.country!),
                if (info.birthDate != null)
                  _row(
                    'Geburtstag',
                    DateFormat('dd.MM.yyyy').format(info.birthDate!),
                  ),
                if (info.language != null && info.language!.isNotEmpty)
                  _row('Sprache', info.language!),
                _row('Registriert', created),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Gelesen',
                style: TextStyle(color: UIConstants.appOrange),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '–' : value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<Set<String>> _loadSeen(String adminUid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('$_seenKeyPrefix$adminUid') ?? const [];
      return list.where((e) => e.isNotEmpty).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> _saveSeen(String adminUid, Set<String> seen) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var list = seen.toList();
      if (list.length > _maxSeenStored) {
        list = list.sublist(list.length - _maxSeenStored);
      }
      await prefs.setStringList('$_seenKeyPrefix$adminUid', list);
    } catch (_) {}
  }
}

class _NewUserInfo {
  final String uid;
  final AppRoleKind roleKind;
  final String displayName;
  final String email;
  final String? realName;
  final String? phone;
  final String? country;
  final DateTime? birthDate;
  final String? language;
  final DateTime? createdAt;

  _NewUserInfo({
    required this.uid,
    required this.roleKind,
    required this.displayName,
    required this.email,
    this.realName,
    this.phone,
    this.country,
    this.birthDate,
    this.language,
    this.createdAt,
  });

  static _NewUserInfo? tryParse(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final roleId = data['role_id']?.toString();
    final kind = AppConfig.classifyRoleId(roleId);
    if (kind != AppRoleKind.dj && kind != AppRoleKind.guest) return null;
    if (data['admin'] == true) return null;

    String pick(String a, [String? b]) {
      final v = data[a]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
      if (b != null) {
        final w = data[b]?.toString().trim();
        if (w != null && w.isNotEmpty) return w;
      }
      return '';
    }

    DateTime? birth;
    final birthRaw =
        data['birthDate'] ?? data['birthdate'] ?? data['birthday'];
    if (birthRaw is Timestamp) {
      birth = birthRaw.toDate();
    }

    DateTime? created;
    final createdRaw = data['created_at'] ?? data['createdAt'];
    if (createdRaw is Timestamp) {
      created = createdRaw.toDate();
    }

    final lang = data['language'] ??
        data['locale'] ??
        data['preferred_language'] ??
        data['selected_language'];

    return _NewUserInfo(
      uid: doc.id,
      roleKind: kind,
      displayName: () {
        final n = pick('displayName');
        return n.isEmpty ? '–' : n;
      }(),
      email: () {
        final e = pick('email');
        return e.isEmpty ? '–' : e;
      }(),
      realName: () {
        final r = pick('real_name', 'realName');
        return r.isEmpty ? null : r;
      }(),
      phone: () {
        final p = pick('phoneNumber', 'phone');
        return p.isEmpty ? null : p;
      }(),
      country: () {
        final c = pick('country');
        return c.isEmpty ? null : c;
      }(),
      birthDate: birth,
      language: lang?.toString().trim().isNotEmpty == true
          ? lang.toString().trim()
          : null,
      createdAt: created,
    );
  }
}
