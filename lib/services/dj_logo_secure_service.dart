import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';

import 'app_diagnostic_log_service.dart';

/// Serverseitiges DJ-Logo (Admin Storage + users/{uid}).
/// Umgeht Client-[firebase_storage/unauthorized].
class DjLogoSecureService {
  DjLogoSecureService._();

  static final DjLogoSecureService instance = DjLogoSecureService._();

  static const String _region = 'us-central1';
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  Future<String> upload({
    required Uint8List bytes,
    required String contentType,
    required String extension,
  }) async {
    diagLog(
      'LOGO',
      'uploadDjLogoSecure bytes=${bytes.length} type=$contentType ext=$extension',
    );
    try {
      final callable = _functions.httpsCallable(
        'uploadDjLogoSecure',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      final raw = await callable.call<Map<String, dynamic>>({
        'imageBase64': base64Encode(bytes),
        'contentType': contentType,
        'extension': extension,
      });
      final data = Map<String, dynamic>.from(raw.data as Map);
      final url = (data['downloadUrl'] ?? '').toString().trim();
      if (url.isEmpty) {
        throw FirebaseFunctionsException(
          code: 'internal',
          message: 'Keine downloadUrl vom Server',
        );
      }
      diagLog('LOGO', 'uploadDjLogoSecure OK');
      return url;
    } on FirebaseFunctionsException catch (e) {
      diagLog(
        'LOGO',
        'uploadDjLogoSecure FEHLER code=${e.code} msg=${e.message}',
      );
      rethrow;
    }
  }

  Future<void> delete() async {
    diagLog('LOGO', 'deleteDjLogoSecure');
    try {
      final callable = _functions.httpsCallable('deleteDjLogoSecure');
      await callable.call<Map<String, dynamic>>(<String, dynamic>{});
      diagLog('LOGO', 'deleteDjLogoSecure OK');
    } on FirebaseFunctionsException catch (e) {
      diagLog(
        'LOGO',
        'deleteDjLogoSecure FEHLER code=${e.code} msg=${e.message}',
      );
      rethrow;
    }
  }
}
