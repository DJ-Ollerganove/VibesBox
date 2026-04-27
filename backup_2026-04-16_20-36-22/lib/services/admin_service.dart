import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../utils/debug_log.dart';

/// Service für Admin-Aktionen, die über Cloud Functions laufen (z. B. Passwort setzen).
/// Voraussetzung: Der aufrufende Nutzer hat in Firestore unter users/{uid} das Feld admin: true.
class AdminService {
  AdminService._();
  static final AdminService _instance = AdminService._();
  static AdminService get instance => _instance;

  static const String _functionName = 'changeUserPassword';
  static const String _massVerifyFunctionName = 'massVerifyExistingUsers';

  /// Firebase Functions Instanz – Region fest auf us-central1 (entspricht dem Deployment der Cloud Function).
  static const String _region = 'us-central1';
  static FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: _region);

  /// Setzt das Passwort eines Ziel-Nutzers (nur für Admins).
  /// [targetUid] Firebase Auth UID des Nutzers.
  /// [newPassword] Neues Passwort (mind. 6 Zeichen).
  /// Wirft bei Fehlern (kein Admin, ungültige Parameter, Auth-Fehler) eine Exception.
  Future<void> changeUserPassword({
    required String targetUid,
    required String newPassword,
  }) async {
    final trimmedUid = targetUid.trim();
    final trimmedPassword = newPassword.trim();
    if (trimmedUid.isEmpty) {
      throw ArgumentError('targetUid darf nicht leer sein.');
    }
    if (trimmedPassword.length < 6) {
      throw ArgumentError('Passwort muss mindestens 6 Zeichen haben.');
    }

    final callable = _functions.httpsCallable(_functionName);
    try {
      final result = await callable.call<Map<String, dynamic>>({
        'targetUid': trimmedUid,
        'newPassword': trimmedPassword,
      });
      final data = result.data;
      if (data['success'] == true) {
        if (kDebugMode) {
          debugLog('✅ AdminService: Passwort für Nutzer $trimmedUid erfolgreich geändert.');
        }
        return;
      }
      throw FirebaseFunctionsException(
        code: 'unknown',
        message: 'Unerwartete Antwort der Cloud Function.',
      );
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugLog('❌ AdminService changeUserPassword: ${e.code} - ${e.message}');
      }
      rethrow;
    }
  }

  /// Einmal-Migration: setzt bei allen Auth-Usern mit E-Mail `emailVerified: true`
  /// (nur wenn Cloud Function [massVerifyExistingUsers] den Aufrufer per Config-UID erlaubt).
  Future<MassVerifyExistingUsersResult> massVerifyExistingUsers() async {
    final callable = _functions.httpsCallable(_massVerifyFunctionName);
    try {
      final result = await callable.call<Map<String, dynamic>>({});
      final data = result.data;
      if (data['success'] != true) {
        throw FirebaseFunctionsException(
          code: 'unknown',
          message: 'Unerwartete Antwort der Cloud Function massVerifyExistingUsers.',
        );
      }
      int n(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        return 0;
      }

      return MassVerifyExistingUsersResult(
        verifiedCount: n(data['verifiedCount']),
        scannedCount: n(data['scannedCount']),
        skippedCount: n(data['skippedCount']),
        errorCount: n(data['errorCount']),
      );
    } on FirebaseFunctionsException catch (e) {
      if (kDebugMode) {
        debugLog(
          '❌ AdminService massVerifyExistingUsers: ${e.code} - ${e.message}',
        );
      }
      rethrow;
    }
  }
}

/// Antwort von [AdminService.massVerifyExistingUsers].
class MassVerifyExistingUsersResult {
  const MassVerifyExistingUsersResult({
    required this.verifiedCount,
    required this.scannedCount,
    required this.skippedCount,
    required this.errorCount,
  });

  final int verifiedCount;
  final int scannedCount;
  final int skippedCount;
  final int errorCount;
}
