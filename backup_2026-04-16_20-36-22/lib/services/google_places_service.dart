import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/location_result.dart';
import '../utils/debug_log.dart';

/// Service für Google Places API Kommunikation
class GooglePlacesService {
  // ✅ VORBEREITET: Struktur für Remote Config, aktuell verwendet wird AppConfig
  static String? _cachedApiKey;
  
  /// Lädt den Google Maps API Key
  /// Phase 1: Aus AppConfig (Konstante)
  /// Phase 2: Aus Remote Config (vorbereitet)
  static Future<String> _getApiKey() async {
    // Cache prüfen
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }
    
    // ✅ PHASE 2 VORBEREITUNG: Versuche Remote Config (später aktivieren)
    // final remoteConfigKey = RemoteConfigService.getString('google_maps_api_key');
    // if (remoteConfigKey.isNotEmpty) {
    //   _cachedApiKey = remoteConfigKey;
    //   return _cachedApiKey!;
    // }
    
    // ✅ PHASE 1: Aktuell aus AppConfig
    final configKey = AppConfig.googleMapsApiKey;
    if (configKey.isNotEmpty) {
      _cachedApiKey = configKey;
      return _cachedApiKey!;
    }
    
    throw Exception('Google Maps API Key nicht gefunden. Bitte in AppConfig setzen.');
  }

  /// Autocomplete-Suche für Places
  /// Gibt eine Liste von Vorschlägen zurück
  static Future<List<PlacePrediction>> searchAutocomplete(String input) async {
    if (input.trim().isEmpty) {
      return [];
    }

    try {
      final apiKey = await _getApiKey();
      final encodedInput = Uri.encodeComponent(input);
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$encodedInput'
        '&key=$apiKey'
        '&language=de'
        // Keine regionale Einschränkung - globale Suche (z.B. Marsa Alam, Ägypten)
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugLog('❌ Google Places Autocomplete Fehler: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        debugLog('❌ Google Places API Status: ${data['status']}');
        return [];
      }

      final predictions = data['predictions'] as List? ?? [];
      
      return predictions.map((prediction) {
        final structuredFormatting = prediction['structured_formatting'] ?? {};
        return PlacePrediction(
          placeId: prediction['place_id'] as String? ?? '',
          description: prediction['description'] as String? ?? '',
          mainText: structuredFormatting['main_text'] as String? ?? '',
          secondaryText: structuredFormatting['secondary_text'] as String?,
        );
      }).toList();
    } catch (e) {
      debugLog('❌ Fehler bei Google Places Autocomplete: $e');
      return [];
    }
  }

  /// Ruft Place-Details ab (Name, Adresse, Koordinaten)
  /// Wird aufgerufen, wenn User einen Vorschlag auswählt
  static Future<LocationResult?> getPlaceDetails(String placeId) async {
    try {
      final apiKey = await _getApiKey();
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=name,formatted_address,geometry,place_id,address_components'
        '&key=$apiKey'
        '&language=de'
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugLog('❌ Google Place Details Fehler: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        debugLog('❌ Google Place Details API Status: ${data['status']}');
        return null;
      }

      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) {
        return null;
      }

      final geometry = result['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;

      if (location == null) {
        return null;
      }

      final lat = (location['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (location['lng'] as num?)?.toDouble() ?? 0.0;

      // address_components auswerten (PLZ, Ort, Straße)
      String? postalCode;
      String? city;
      String? street;
      final components = result['address_components'] as List?;
      if (components != null) {
        String? route;
        String? streetNumber;
        for (final c in components) {
          final map = c is Map<String, dynamic> ? c : Map<String, dynamic>.from(c as Map);
          final types = (map['types'] as List?)?.cast<String>() ?? [];
          final longName = map['long_name'] as String? ?? '';
          if (types.contains('postal_code')) postalCode = longName.isNotEmpty ? longName : null;
          if (types.contains('locality')) city = longName.isNotEmpty ? longName : null;
          if (types.contains('route')) route = longName.isNotEmpty ? longName : null;
          if (types.contains('street_number')) streetNumber = longName.isNotEmpty ? longName : null;
        }
        if (route != null || streetNumber != null) {
          street = [route, streetNumber].where((e) => e != null && e.isNotEmpty).join(' ').trim();
          if (street.isEmpty) street = null;
        }
      }

      // Hole Time Zone ID über Google Time Zone API
      String? timezoneId;
      if (lat != 0.0 && lng != 0.0) {
        timezoneId = await _getTimezoneId(lat, lng);
      }

      return LocationResult(
        placeId: placeId,
        name: result['name'] as String? ?? '',
        address: result['formatted_address'] as String? ?? '',
        latitude: lat,
        longitude: lng,
        timezoneId: timezoneId,
        postalCode: postalCode,
        city: city,
        street: street,
      );
    } catch (e) {
      debugLog('❌ Fehler bei Google Place Details: $e');
      return null;
    }
  }

  /// Ruft die Time Zone ID für gegebene Koordinaten ab (öffentliche Methode)
  /// Nutzt die Google Time Zone API
  static Future<String?> getTimezoneIdForCoordinates(double latitude, double longitude) async {
    return await _getTimezoneId(latitude, longitude);
  }

  /// Ruft die Time Zone ID für gegebene Koordinaten ab
  /// Nutzt die Google Time Zone API
  static Future<String?> _getTimezoneId(double latitude, double longitude) async {
    try {
      final apiKey = await _getApiKey();
      
      // Aktueller Unix-Timestamp für die Time Zone API
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/timezone/json'
        '?location=$latitude,$longitude'
        '&timestamp=$timestamp'
        '&key=$apiKey'
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugLog('❌ Google Time Zone API Fehler: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        debugLog('❌ Google Time Zone API Status: ${data['status']}');
        return null;
      }

      // Die Time Zone ID ist im Feld 'timeZoneId' (z.B. 'Europe/Berlin')
      final timezoneId = data['timeZoneId'] as String?;
      
      if (timezoneId != null && timezoneId.isNotEmpty) {
        debugLog('✅ Time Zone ID gefunden: $timezoneId');
        return timezoneId;
      }

      return null;
    } catch (e) {
      debugLog('❌ Fehler bei Google Time Zone API: $e');
      return null;
    }
  }
}
