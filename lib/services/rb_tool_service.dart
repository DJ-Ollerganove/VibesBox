import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RbToolCodeResult {
  const RbToolCodeResult({
    required this.code,
    required this.expiresAtMillis,
  });

  final String code;
  final int expiresAtMillis;
}

class RbToolCodeStatus {
  const RbToolCodeStatus({
    required this.exists,
    required this.used,
    required this.revoked,
    required this.expired,
  });

  final bool exists;
  final bool used;
  final bool revoked;
  final bool expired;
}

/// Admin-Pairing für das Rekordbox-Desktop-Tool.
class RbToolService {
  RbToolService._();
  static final RbToolService instance = RbToolService._();

  static const String _region = 'us-central1';
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  Future<RbToolCodeResult> createCode() async {
    final raw = await _functions.httpsCallable('createRbToolCode').call();
    final data = Map<String, dynamic>.from(raw.data as Map);
    return RbToolCodeResult(
      code: (data['code'] ?? '').toString(),
      expiresAtMillis: (data['expiresAtMillis'] as num?)?.toInt() ?? 0,
    );
  }

  /// Trennt die Desktop-Verbindung. Nur auf Knopfdruck, nicht beim Schließen des Tools.
  Future<void> disconnectOwnTool() async {
    await _functions.httpsCallable('revokeRbToolSession').call();
  }

  Future<RbToolCodeStatus> getCodeStatus({required String code}) async {
    final raw = await _functions.httpsCallable('getRbToolCodeStatus').call({
      'code': code,
    });
    final data = Map<String, dynamic>.from(raw.data as Map);
    return RbToolCodeStatus(
      exists: data['exists'] == true,
      used: data['used'] == true,
      revoked: data['revoked'] == true,
      expired: data['expired'] == true,
    );
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> liveStream(String ownerUid) {
    return FirebaseFirestore.instance
        .collection('rb_tool_live')
        .doc(ownerUid)
        .snapshots();
  }

  User? get currentUser => FirebaseAuth.instance.currentUser;
}
