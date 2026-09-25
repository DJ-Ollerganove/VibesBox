import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../utils/callable_payload_serializer.dart';
import '../utils/party_code_utils.dart';
import 'app_diagnostic_log_service.dart';

/// Party-Code-Reservierung:
/// - **global**: privat + öffentliche Einmal-Codes (weltweit eindeutig, Transaktion)
/// - **venue_shared**: öffentlicher Venue-Festcode (nur gleiche Location/Venue)
class PartyCodeIndexService {
  PartyCodeIndexService._({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: _functionsRegion);

  static final PartyCodeIndexService instance = PartyCodeIndexService._();

  static const String collection = 'party_code_index';
  static const String _functionsRegion = 'us-central1';

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(collection);

  String _normalize(String code) => PartyCodeUtils.normalizeDigits(code);

  Future<void> _createPartySecure({
    required String mode,
    required String partyCode,
    required String partyId,
    required Map<String, dynamic> partyData,
    String? venueId,
    String? locationId,
  }) async {
    final normalized = _normalize(partyCode);
    diagLog(
      'PARTY',
      'createPartySecure mode=$mode code=$normalized partyId=$partyId '
      'venueId=${venueId ?? '—'} locationId=${locationId ?? '—'}',
    );

    try {
      final callable = _functions.httpsCallable('createPartySecure');
      await callable.call<Map<String, dynamic>>({
        'mode': mode,
        'partyId': partyId,
        'partyCode': normalized,
        'partyData': serializeForCallable(partyData),
        if (venueId != null && venueId.trim().isNotEmpty) 'venueId': venueId.trim(),
        if (locationId != null && locationId.trim().isNotEmpty)
          'locationId': locationId.trim(),
      });
      diagLog('PARTY', 'createPartySecure OK ($mode, $normalized)');
    } on FirebaseFunctionsException catch (e) {
      diagLog(
        'PARTY',
        'createPartySecure FEHLER code=${e.code} message=${e.message} details=${e.details}',
      );
      if (e.code == 'already-exists') {
        throw PartyCodeIndexConflictException(normalized);
      }
      if (e.code == 'failed-precondition') {
        throw PartyCodeCrossVenueConflictException(normalized);
      }
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'createPartySecure: ${e.message ?? e.code}',
        );
      }
      rethrow;
    }
  }

  /// Ob der Code global reserviert ist (`party_code_index`).
  Future<bool> isCodeReserved(String code) async {
    final normalized = _normalize(code);
    if (normalized.length != PartyCodeUtils.codeLength) return false;
    try {
      final snap = await _col.doc(normalized).get();
      return snap.exists;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  /// Global eindeutig: privat oder öffentlicher Einmal-Code (race-sicher).
  Future<void> createPartyWithGloballyUniqueCode({
    required String partyCode,
    required String partyId,
    required String createdBy,
    required String partyType,
    required Map<String, dynamic> partyData,
  }) async {
    final normalized = _normalize(partyCode);
    if (normalized.length != PartyCodeUtils.codeLength) {
      throw StateError('Ungültiger Party-Code für Index');
    }

    await _createPartySecure(
      mode: 'global_index',
      partyCode: normalized,
      partyId: partyId,
      partyData: partyData,
    );
  }

  /// Öffentlicher Venue-Festcode: gleicher Code nur an derselben Venue/Location.
  Future<void> createPublicVenueSharedCodeParty({
    required String partyCode,
    required String partyId,
    required Map<String, dynamic> partyData,
    String? venueId,
    String? locationId,
  }) async {
    final normalized = _normalize(partyCode);
    if (normalized.length != PartyCodeUtils.codeLength) {
      throw StateError('Ungültiger Party-Code');
    }

    await _createPartySecure(
      mode: 'venue_shared',
      partyCode: normalized,
      partyId: partyId,
      partyData: partyData,
      venueId: venueId,
      locationId: locationId,
    );
  }

  /// Globalen Index-Eintrag freigeben (privat + öffentliche Einmal-Codes).
  Future<void> releaseCodeForParty(
    Map<String, dynamic> partyData, {
    required String partyId,
  }) async {
    final raw = partyData['party_code']?.toString();
    if (raw == null || raw.trim().isEmpty) return;

    final normalized = _normalize(raw);
    if (normalized.length != PartyCodeUtils.codeLength) return;

    try {
      final snap = await _col.doc(normalized).get();
      if (!snap.exists) return;
      final indexPartyId = snap.data()?['party_id'] as String?;
      if (indexPartyId == partyId) {
        await _col.doc(normalized).delete();
      }
    } catch (_) {}
  }
}

class PartyCodeIndexConflictException implements Exception {
  PartyCodeIndexConflictException(this.code);
  final String code;

  @override
  String toString() => 'Party-Code bereits vergeben: $code';
}

class PartyCodeCrossVenueConflictException implements Exception {
  PartyCodeCrossVenueConflictException(this.code);
  final String code;

  @override
  String toString() =>
      'Party-Code $code ist an einem anderen Ort bereits vergeben';
}
