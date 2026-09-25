import 'package:cloud_functions/cloud_functions.dart';

import 'app_diagnostic_log_service.dart';

class DjBrowserCodeResult {
  const DjBrowserCodeResult({
    required this.code,
    required this.expiresAtMillis,
    required this.url,
  });

  final String code;
  final int expiresAtMillis;
  final String url;
}

class DjBrowserCodeStatus {
  const DjBrowserCodeStatus({
    required this.exists,
    required this.used,
    required this.pending,
    required this.revoked,
    required this.expired,
  });

  final bool exists;
  final bool used;
  final bool pending;
  final bool revoked;
  final bool expired;

  bool get consumed => used;
}

/// Serverseitiger Browser-Zugang zur DJ-VibesBox (PRO, Einmal-Code).
class DjBrowserService {
  DjBrowserService._();

  static final DjBrowserService instance = DjBrowserService._();

  static const String _region = 'us-central1';
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  Future<DjBrowserCodeResult> createCode({required String partyId}) async {
    diagLog('DJ_BROWSER', 'createCode partyId=$partyId');
    try {
      final raw = await _functions.httpsCallable('createDjBrowserCode').call({
        'partyId': partyId,
      });
      final data = Map<String, dynamic>.from(raw.data as Map);
      return DjBrowserCodeResult(
        code: (data['code'] ?? '').toString(),
        expiresAtMillis: (data['expiresAtMillis'] as num?)?.toInt() ?? 0,
        url: (data['url'] ?? 'https://www.vibesbox.app/dj').toString(),
      );
    } on FirebaseFunctionsException catch (e) {
      diagLog(
        'DJ_BROWSER',
        'createCode FEHLER code=${e.code} message=${e.message}',
      );
      rethrow;
    }
  }

  Future<void> revokeCode({
    required String partyId,
    required String code,
  }) async {
    diagLog('DJ_BROWSER', 'revokeCode partyId=$partyId');
    try {
      await _functions.httpsCallable('revokeDjBrowserCode').call({
        'partyId': partyId,
        'code': code,
      });
    } on FirebaseFunctionsException catch (e) {
      diagLog(
        'DJ_BROWSER',
        'revokeCode FEHLER code=${e.code} message=${e.message}',
      );
    }
  }

  Future<DjBrowserCodeStatus> getCodeStatus({
    required String partyId,
    required String code,
  }) async {
    final raw = await _functions.httpsCallable('getDjBrowserCodeStatus').call({
      'partyId': partyId,
      'code': code,
    });
    final data = Map<String, dynamic>.from(raw.data as Map);
    return DjBrowserCodeStatus(
      exists: data['exists'] == true,
      used: data['used'] == true,
      pending: data['pending'] == true,
      revoked: data['revoked'] == true,
      expired: data['expired'] == true,
    );
  }
}
