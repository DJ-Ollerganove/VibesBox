import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/party_code_utils.dart';
import 'limit_service.dart';
import '../utils/debug_log.dart';

/// Service für Party-Code-Generierung und Location-Verwaltung
class PartyService {
  /// 8-stellig: normale Partys 10000000–98999999, feste Locations 99000000–99999999
  static const int dynamicCodeMin = PartyCodeUtils.normalMin;
  static const int dynamicCodeMax = PartyCodeUtils.normalMax;
  static const int fixedCodeMin = PartyCodeUtils.fixedMin;
  static const int fixedCodeMax = PartyCodeUtils.fixedMax;
  static const int maxAttempts = 100;

  /// [parties]: [party_code] (String oder Zahl) oder optionale Felder [short_code]/[partyCode]/[shortCode].
  static Future<bool> isPartyCodeTakenInParties(String code) async {
    final col = FirebaseFirestore.instance.collection('parties');
    final asStr = await col.where('party_code', isEqualTo: code).limit(1).get();
    if (asStr.docs.isNotEmpty) return true;
    final n = int.tryParse(code);
    if (n != null) {
      final asNum = await col.where('party_code', isEqualTo: n).limit(1).get();
      if (asNum.docs.isNotEmpty) return true;
    }
    for (final field in ['short_code', 'partyCode', 'shortCode']) {
      try {
        final q = await col.where(field, isEqualTo: code).limit(1).get();
        if (q.docs.isNotEmpty) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Eindeutiger 8-stelliger Code (nur Ziffern, ohne Formatierung für die DB).
  static Future<String> generatePartyCode({
    required bool isFixedCode,
    required String createdBy,
  }) async {
    final random = Random();
    final min = isFixedCode ? fixedCodeMin : dynamicCodeMin;
    final max = isFixedCode ? fixedCodeMax : dynamicCodeMax;

    String code = '';
    bool isUnique = false;
    int attempts = 0;

    while (!isUnique && attempts < maxAttempts) {
      code = (min + random.nextInt(max - min + 1)).toString();

      if (isFixedCode) {
        final existingLocations = await FirebaseFirestore.instance
            .collection('locations')
            .where('fixed_party_code', isEqualTo: code)
            .limit(1)
            .get();
        if (existingLocations.docs.isNotEmpty) {
          attempts++;
          continue;
        }
        if (await isPartyCodeTakenInParties(code)) {
          attempts++;
          continue;
        }
        isUnique = true;
      } else {
        if (await isPartyCodeTakenInParties(code)) {
          attempts++;
          continue;
        }
        isUnique = true;
      }
    }

    if (!isUnique || code.isEmpty) {
      throw Exception('Konnte keinen eindeutigen Party-Code generieren (${isFixedCode ? 'fest' : 'dynamisch'})');
    }

    debugLog('✅ Party-Code generiert: $code (${isFixedCode ? 'fest' : 'dynamisch'})');
    return code;
  }

  /// Prüft ob für eine Location bereits ein fixed_party_code existiert
  /// 
  /// [locationId]: ID der Location in der locations-Collection
  /// 
  /// Returns: fixed_party_code wenn vorhanden, sonst null
  static Future<String?> getFixedPartyCodeForLocation(String locationId) async {
    try {
      final locationDoc = await FirebaseFirestore.instance
          .collection('locations')
          .doc(locationId)
          .get();

      if (!locationDoc.exists) {
        return null;
      }

      final data = locationDoc.data();
      final fixedCode = data?['fixed_party_code'] as String?;
      
      if (fixedCode != null && fixedCode.isNotEmpty) {
        debugLog('✅ Fixed Party-Code für Location gefunden: $fixedCode');
        return fixedCode;
      }

      return null;
    } catch (e) {
      debugLog('❌ Fehler beim Abrufen des fixed_party_code: $e');
      return null;
    }
  }

  /// Erstellt oder aktualisiert eine Location mit den neuen Feldern
  /// 
  /// [locationName]: Name der Location
  /// [address]: Adresse (optional)
  /// [latitude]: Breitengrad (optional)
  /// [longitude]: Längengrad (optional)
  /// [timezoneId]: Zeitzone (Pflichtfeld!)
  /// [createdBy]: DJ-ID
  /// [fixedPartyCode]: Optional: Fester Party-Code (900k-Bereich)
  /// [updateExisting]: Wenn true, werden bestehende Locations aktualisiert, sonst nur neue erstellt
  /// 
  /// Returns: Location-ID
  static Future<String> createOrUpdateLocation({
    required String locationName,
    String? address,
    double? latitude,
    double? longitude,
    required String timezoneId, // Pflichtfeld!
    required String createdBy,
    String? fixedPartyCode,
    bool updateExisting = true,
  }) async {
    // Validierung: timezoneId ist Pflichtfeld
    if (timezoneId.isEmpty) {
      throw Exception('timezone_id ist ein Pflichtfeld und darf nicht leer sein');
    }

    // Prüfe ob Location bereits existiert (case-insensitive)
    final normalizedName = locationName.trim().toLowerCase();
    final existingLocations = await FirebaseFirestore.instance
        .collection('locations')
        .get();

    String? existingLocationId;
    for (var doc in existingLocations.docs) {
      final data = doc.data();
      final existingName = (data['location_name'] ?? '').toString().trim().toLowerCase();
      if (existingName == normalizedName) {
        existingLocationId = doc.id;
        break;
      }
    }

    final locationData = {
      'location_name': locationName.trim(),
      if (address != null && address.isNotEmpty) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'timezone_id': timezoneId, // Pflichtfeld
      if (fixedPartyCode != null && fixedPartyCode.isNotEmpty) 'fixed_party_code': fixedPartyCode,
      'created_by': createdBy,
      'created_at': Timestamp.now(),
    };

    if (existingLocationId != null && updateExisting) {
      // Aktualisiere bestehende Location
      await FirebaseFirestore.instance
          .collection('locations')
          .doc(existingLocationId)
          .update(locationData);
      
      debugLog('✅ Location aktualisiert: $existingLocationId');
      return existingLocationId;
    } else if (existingLocationId != null && !updateExisting) {
      // Location existiert bereits, aber updateExisting ist false -> gib ID zurück
      debugLog('✅ Location existiert bereits: $existingLocationId');
      return existingLocationId;
    } else {
      // Erstelle neue Location
      // Wenn kein fixedPartyCode übergeben wurde, generiere einen
      if (fixedPartyCode == null || fixedPartyCode.isEmpty) {
        fixedPartyCode = await generatePartyCode(
          isFixedCode: true,
          createdBy: createdBy,
        );
        locationData['fixed_party_code'] = fixedPartyCode;
      }

      final locationRef = await FirebaseFirestore.instance
          .collection('locations')
          .add(locationData);
      
      debugLog('✅ Neue Location erstellt: ${locationRef.id} mit fixed_party_code: $fixedPartyCode');
      return locationRef.id;
    }
  }

  /// Prüft, ob der User eine Party anlegen darf (Free-DJ-Limit: 1 pro Abrechnungszeitraum).
  /// [plannedStartDate]: optional; wenn gesetzt (z. B. aus dem Wizard), wird der Zeitraum für dieses Datum geprüft.
  /// Vor [generatePartyCode] / Speichern aufrufen; bei false Vorgang abbrechen.
  static Future<bool> canCreateParty(UserModel user, {DateTime? plannedStartDate}) async {
    return LimitService.checkPartyCreationLimit(user, plannedStartDate: plannedStartDate);
  }

  /// Bestimmt den Party-Code für eine neue Party
  /// 
  /// [partyType]: 'private' oder 'public'
  /// [locationId]: Optional: Location-ID für öffentliche Partys
  /// [createdBy]: DJ-ID
  /// 
  /// Returns: Party-Code (entweder fixed_party_code der Location oder dynamischer Code)
  static Future<String> determinePartyCodeForNewParty({
    required String partyType,
    String? locationId,
    required String createdBy,
  }) async {
    // Für öffentliche Partys: Prüfe ob Location einen fixed_party_code hat
    if (partyType == 'public' && locationId != null && locationId.isNotEmpty) {
      final fixedCode = await getFixedPartyCodeForLocation(locationId);
      if (fixedCode != null) {
        debugLog('✅ Verwende fixed_party_code der Location: $fixedCode');
        return fixedCode;
      }
    }

    // Für private Partys oder wenn keine Location/fixedCode vorhanden: Generiere dynamischen Code
    debugLog('✅ Generiere dynamischen Party-Code');
    return await generatePartyCode(
      isFixedCode: false,
      createdBy: createdBy,
    );
  }
}
