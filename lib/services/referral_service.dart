import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/debug_log.dart';

class ReferralService {
  // Singleton Pattern
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final _rnd = Random();

  /// Generiert einen zufälligen 8-stelligen Code
  String _generateRandomCode() {
    return String.fromCharCodes(Iterable.generate(
        8, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));
  }

  /// Erstellt einen Referral-Code für den aktuellen User, falls noch keiner existiert.
  /// Prüft auf Einzigartigkeit und speichert in beiden Collections.
  Future<String?> ensureReferralCodeExists(String uid) async {
    try {
      // 1. Prüfen, ob User schon einen Code hat
      final userDoc = await _db.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('myReferralCode')) {
        return userDoc.data()!['myReferralCode'] as String;
      }

      // 2. Generieren und Prüfen (Loop für Einzigartigkeit)
      String newCode = '';
      bool isUnique = false;
      int attempts = 0;

      while (!isUnique && attempts < 10) {
        newCode = _generateRandomCode();
        final codeDoc = await _db.collection('referral_codes').doc(newCode).get();
        if (!codeDoc.exists) {
          isUnique = true;
        }
        attempts++;
      }

      if (!isUnique) throw Exception('Konnte keinen eindeutigen Code generieren.');

      // 3. Atomares Schreiben in beide Collections
      final batch = _db.batch();

      // Eintrag in users/{uid}
      batch.set(
        _db.collection('users').doc(uid),
        {'myReferralCode': newCode},
        SetOptions(merge: true),
      );

      // Eintrag in referral_codes/{code}
      batch.set(
        _db.collection('referral_codes').doc(newCode),
        {
          'uid': uid,
          'created_at': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
      return newCode;
    } catch (e) {
      debugLog('❌ Fehler bei Referral-Code Generierung: $e');
      return null;
    }
  }

  /// Löst einen Code zu einer UID auf (für die Eingabe)
  Future<String?> resolveCodeToUid(String code) async {
    try {
      final cleanCode = code.trim().toLowerCase();
      final doc = await _db.collection('referral_codes').doc(cleanCode).get();
      if (doc.exists) {
        return doc.data()?['uid'] as String?;
      }
      return null;
    } catch (e) {
      debugLog('❌ Fehler beim Auflösen des Codes: $e');
      return null;
    }
  }

  /// Speichert, wer den User geworben hat
  Future<bool> redeemCode(String currentUserUid, String code) async {
    try {
      final referrerUid = await resolveCodeToUid(code);
      
      if (referrerUid == null) return false; // Code existiert nicht
      if (referrerUid == currentUserUid) return false; // Man kann sich nicht selbst werben

      // Speichere referredBy im User-Dokument
      await _db.collection('users').doc(currentUserUid).set({
        'referredBy': referrerUid,
        'redeemedCode': code.trim().toLowerCase(),
        'referralDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      debugLog('❌ Fehler beim Einlösen des Codes: $e');
      return false;
    }
  }
}
