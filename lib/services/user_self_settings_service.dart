import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/callable_payload_serializer.dart';
import '../utils/debug_log.dart';
import 'app_diagnostic_log_service.dart';

/// Schreibt erlaubte DJ-Selbst-Einstellungen in `users/{auth.uid}`.
/// Primär serverseitig via [patchUserSelfSettings] (umgeht Legacy-Regel-Konflikte).
class UserSelfSettingsService {
  UserSelfSettingsService._();

  static final UserSelfSettingsService instance = UserSelfSettingsService._();

  static const String _region = 'us-central1';
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  Future<void> write(Map<String, dynamic> fields, {String? userId}) async {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || fields.isEmpty) return;

    final normalized = _normalizeFields(fields);

    // Callable zuerst: zuverlässig auch bei kaputten Legacy-Feldern im User-Doc.
    try {
      await _writeViaCallable(normalized);
      diagLog(
        'SETTINGS',
        'patchUserSelfSettings OK uid=$uid keys=${normalized.keys.join(",")}',
      );
      return;
    } on FirebaseFunctionsException catch (e) {
      debugLog(
        'UserSelfSettingsService: Callable fehlgeschlagen (${e.code}), '
        'Firestore-Fallback für $uid',
      );
      diagLog(
        'SETTINGS',
        'patchUserSelfSettings FEHLER code=${e.code} msg=${e.message}',
      );
      // Media-URLs: kein stiller Fallback bei Auth-Problemen — sonst
      // cloud_firestore/permission-denied ohne klaren Callable-Hinweis.
      final isMediaOnly = normalized.keys.every(
        (k) => k == 'dj_logo_url' || k == 'djLogoUrl' || k == 'photoURL',
      );
      if (isMediaOnly &&
          (e.code == 'unauthenticated' || e.code == 'permission-denied')) {
        rethrow;
      }
    } catch (e) {
      debugLog('UserSelfSettingsService: Callable Fehler $e — Firestore-Fallback');
    }

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      final snap = await ref.get();
      // Fallback: FieldValue.delete für null (leere optionale Felder)
      final fallback = <String, dynamic>{};
      normalized.forEach((key, value) {
        fallback[key] = value ?? FieldValue.delete();
      });
      if (snap.exists) {
        await ref.update(fallback);
      } else {
        await ref.set(fallback, SetOptions(merge: true));
      }
      diagLog('SETTINGS', 'Firestore-Fallback OK uid=$uid');
    } on FirebaseException catch (e) {
      diagLog(
        'SETTINGS',
        'Firestore-Fallback FEHLER code=${e.code} msg=${e.message}',
      );
      rethrow;
    } catch (e) {
      diagLog('SETTINGS', 'Firestore-Fallback FEHLER $e');
      rethrow;
    }
  }

  /// [FieldValue.delete]/null → null (Callable löscht), ServerTimestamp → jetzt.
  Map<String, dynamic> _normalizeFields(Map<String, dynamic> fields) {
    final out = <String, dynamic>{};
    fields.forEach((key, value) {
      if (value is FieldValue) {
        final s = value.toString();
        if (s.contains('Delete') || s.contains('delete')) {
          out[key] = null;
          return;
        }
        if (s.contains('ServerTimestamp') || s.contains('serverTimestamp')) {
          out[key] = Timestamp.now();
          return;
        }
        // Andere FieldValues (arrayUnion etc.) nicht über Callable — weglassen
        debugLog(
          'UserSelfSettingsService: FieldValue für $key nicht serialisierbar, übersprungen',
        );
        return;
      }
      out[key] = value;
    });
    return out;
  }

  Future<void> _writeViaCallable(Map<String, dynamic> fields) async {
    final callable = _functions.httpsCallable('patchUserSelfSettings');
    await callable.call<Map<String, dynamic>>({
      'patch': serializeForCallable(fields),
    });
  }
}
