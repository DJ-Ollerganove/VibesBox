import 'package:cloud_functions/cloud_functions.dart';

import '../utils/callable_payload_serializer.dart';
import 'app_diagnostic_log_service.dart';

/// Ergebnis von [PartySecureService.acquireRecognitionLock].
enum RecognitionLockAcquireStatus { acquired, blocked, error }

class RecognitionLockAcquireResult {
  const RecognitionLockAcquireResult(this.status, {this.otherDevice});

  final RecognitionLockAcquireStatus status;
  final String? otherDevice;
}

/// Serverseitiges Party-Schreiben (Admin SDK) — Create, Update, Recognition-Lock.
class PartySecureService {
  PartySecureService._();

  static final PartySecureService instance = PartySecureService._();

  static const String _region = 'us-central1';
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  Future<void> updateParty({
    required String partyId,
    required Map<String, dynamic> patch,
    Map<String, dynamic>? publicVenue,
  }) async {
    diagLog(
      'PARTY',
      'updatePartySecure partyId=$partyId keys=${patch.keys.join(", ")} '
      'publicVenue=${publicVenue != null}',
    );
    try {
      final callable = _functions.httpsCallable('updatePartySecure');
      await callable.call<Map<String, dynamic>>({
        'partyId': partyId,
        'patch': serializeForCallable(patch),
        if (publicVenue != null)
          'publicVenue': serializeForCallable(publicVenue),
      });
      diagLog('PARTY', 'updatePartySecure OK ($partyId)');
    } on FirebaseFunctionsException catch (e) {
      diagLog(
        'PARTY',
        'updatePartySecure FEHLER code=${e.code} message=${e.message} details=${e.details}',
      );
      throw Exception(
        '[firebase_functions/${e.code}] ${e.message ?? 'updatePartySecure fehlgeschlagen'}',
      );
    }
  }

  Future<RecognitionLockAcquireResult> acquireRecognitionLock({
    required String partyId,
    required String deviceId,
  }) async {
    try {
      final callable = _functions.httpsCallable('acquireRecognitionLockSecure');
      final raw = await callable.call<Map<String, dynamic>>({
        'partyId': partyId,
        'deviceId': deviceId,
      });
      final data = Map<String, dynamic>.from(raw.data);
      final status = (data['status'] ?? '').toString();
      if (status == 'acquired') {
        diagLog('SHAZAM', 'Recognition-Lock acquired ($partyId)');
        return const RecognitionLockAcquireResult(
          RecognitionLockAcquireStatus.acquired,
        );
      }
      if (status == 'blocked') {
        final other = (data['otherDevice'] ?? '').toString().trim();
        return RecognitionLockAcquireResult(
          RecognitionLockAcquireStatus.blocked,
          otherDevice: other.isEmpty ? null : other,
        );
      }
      return const RecognitionLockAcquireResult(
        RecognitionLockAcquireStatus.error,
      );
    } on FirebaseFunctionsException catch (e) {
      diagLog(
        'SHAZAM',
        'acquireRecognitionLockSecure FEHLER code=${e.code} message=${e.message}',
      );
      return const RecognitionLockAcquireResult(
        RecognitionLockAcquireStatus.error,
      );
    } catch (e) {
      diagLog('SHAZAM', 'acquireRecognitionLockSecure FEHLER $e');
      return const RecognitionLockAcquireResult(
        RecognitionLockAcquireStatus.error,
      );
    }
  }

  Future<bool> releaseRecognitionLock({
    required String partyId,
    required String deviceId,
    bool force = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('releaseRecognitionLockSecure');
      final raw = await callable.call<Map<String, dynamic>>({
        'partyId': partyId,
        'deviceId': deviceId,
        'force': force,
      });
      final status = (Map<String, dynamic>.from(raw.data)['status'] ?? '')
          .toString();
      final ok = status == 'released';
      if (ok) {
        diagLog('SHAZAM', 'Recognition-Lock released ($partyId, force=$force)');
      }
      return ok;
    } on FirebaseFunctionsException catch (e) {
      diagLog(
        'SHAZAM',
        'releaseRecognitionLockSecure FEHLER code=${e.code} message=${e.message}',
      );
      return false;
    } catch (e) {
      diagLog('SHAZAM', 'releaseRecognitionLockSecure FEHLER $e');
      return false;
    }
  }

  Future<void> pingRecognitionLock({
    required String partyId,
    required String deviceId,
  }) async {
    try {
      final callable = _functions.httpsCallable('pingRecognitionLockSecure');
      await callable.call<Map<String, dynamic>>({
        'partyId': partyId,
        'deviceId': deviceId,
      });
    } on FirebaseFunctionsException catch (e) {
      diagLog(
        'SHAZAM',
        'pingRecognitionLockSecure FEHLER code=${e.code} message=${e.message}',
      );
    } catch (e) {
      diagLog('SHAZAM', 'pingRecognitionLockSecure FEHLER $e');
    }
  }
}
