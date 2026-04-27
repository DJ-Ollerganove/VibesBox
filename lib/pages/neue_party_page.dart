import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../widgets/places_autocomplete_field.dart';
import '../models/location_result.dart';
import '../models/location_model.dart';
import '../services/party_service.dart';
import '../services/google_places_service.dart';
import '../config/app_config.dart';
import '../services/user_service.dart';
import '../services/limit_service.dart';
import '../services/party_limit_service.dart';
import '../utils/ui_constants.dart';
import '../utils/party_validator.dart';
import '../widgets/common/pwa_widget_cell.dart';
import '../helpers/security_helper.dart';
import 'location_map_picker_page.dart';
import '../widgets/party_creation/location_picker.dart';
import '../widgets/scroll_indicator_overlay.dart';
import '../utils/debug_log.dart';

// Sanitization-Funktion: Entfernt potenziell gefährliche Zeichen und HTML-Tags
String sanitizeInput(String input) {
  return SecurityHelper.sanitize(input, maxLength: 500);
}

class NeuePartyPage extends StatefulWidget {
  const NeuePartyPage({super.key});

  @override
  State<NeuePartyPage> createState() => _NeuePartyPageState();

  /// Zeigt die Neue Party Seite als Dialog
  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: const NeuePartyPage(),
        ),
      ),
    );
  }
}

class _NeuePartyPageState extends State<NeuePartyPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _startTimePickerKey = GlobalKey();
  final _partyNameController = TextEditingController();
  final _locationNameController = TextEditingController();
  int? _selectedGuestLimit = 2; // Standard: 2 Wünsche/Stunde
  int? _selectedUserLimit = 5; // Standard: 5 Wünsche/Stunde
  DateTime? _startDate;
  int? _startHour; // Schrittweise: Stunde
  int? _startMinute; // Schrittweise: Minute
  DateTime? _endDate;
  int? _endHour; // Schrittweise: Stunde
  int? _endMinute; // Schrittweise: Minute
  String _partyType = 'private'; // Standard: privat
  bool _isLoading = false;
  String? _selectedLocationId; // Ausgewählte Location-ID
  String? locationId; // Location-ID für Party-Speicherung
  List<Map<String, dynamic>> _locations = []; // Liste aller Locations des DJs
  LocationResult? _selectedGooglePlace; // Ausgewählter Google Place
  String? _currentTimezoneId; // Aktuelle Zeitzone (Google Place oder System)
  String _locationSelectionMode =
      'current'; // 'current', 'search' oder 'dropdown' - Standort-Auswahlmodus
  bool _showLocationPublicly =
      false; // Location-Details auf QR-Code & Übersicht anzeigen
  bool _saveLocationForFutureParties =
      false; // Location für zukünftige Partys speichern
  bool _useFixedPartyCodeForLocation =
      false; // Immer denselben Party-Code für diesen Ort verwenden
  bool _useOneTimeEventCode =
      false; // Einmaligen Event-Code nutzen (ignoriere festen Code)
  LocationModel? _selectedLocationModel; // Ausgewählte Location aus Dialog
  bool _wasMapAdjusted =
      false; // true wenn Ort gerade über Karte gewählt/angepasst wurde → Button dezenter

  // Erstelle Listen für Dropdown-Optionen
  final List<int> _guestLimitOptions = List.generate(
    11,
    (index) => index,
  ); // 0-10
  final List<int> _userLimitOptions = List.generate(
    26,
    (index) => index,
  ); // 0-25

  // Validierungsstatus
  String? _validationError;
  List<QueryDocumentSnapshot>?
  _allParties; // Alle Partys des DJs für Überschneidungsprüfung

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _updateSystemTimezone();
    _loadAllParties(); // Lade alle Partys für Überschneidungsprüfung
    // Free-DJ: Limits fest auf 1 setzen (UI wird in _buildWishLimitsSection deaktiviert)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = UserService().currentUser.value;
      if (user != null && user.isFree) {
        setState(() {
          _selectedGuestLimit = 1;
          _selectedUserLimit = 1;
        });
      }
    });
  }

  /// Lädt alle Partys des aktuellen DJs für Überschneidungsprüfung
  Future<void> _loadAllParties() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final partiesSnapshot = await FirebaseFirestore.instance
            .collection('parties')
            .where('created_by', isEqualTo: user.uid)
            .get();
        if (mounted) {
          setState(() {
            _allParties = partiesSnapshot.docs;
          });
        }
      }
    } catch (e) {
      debugLog('⚠️ Fehler beim Laden der Partys für Überschneidungs-Check: $e');
      if (mounted) {
        setState(() {
          _allParties = [];
        });
      }
    }
  }

  /// Validiert die Party-Zeiten in Echtzeit
  void _validatePartyTimes() {
    if (_startDate == null ||
        _startHour == null ||
        _startMinute == null ||
        _endDate == null ||
        _endHour == null ||
        _endMinute == null) {
      setState(() {
        _validationError = null; // Noch nicht alle Felder ausgefüllt
      });
      return;
    }

    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startHour!,
      _startMinute!,
    );

    final endDateTime = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endHour!,
      _endMinute!,
    );

    // Ermittle Admin-Status (Firestore-Rolle)
    final isAdmin = AppConfig.isAdminRole(UserService().currentUser.value);

    // Nutze zentrale Validierungsklasse mit Admin-Status
    final error = PartyValidator.validate(
      startDateTime,
      endDateTime,
      allParties: _allParties,
      isAdmin: isAdmin,
      context: context,
    );

    setState(() {
      _validationError = error;
    });
  }

  /// Prüft, ob alle Felder ausgefüllt sind und die Validierung erfolgreich ist
  bool get _isFormValid {
    return _startDate != null &&
        _startHour != null &&
        _startMinute != null &&
        _endDate != null &&
        _endHour != null &&
        _endMinute != null &&
        _selectedGuestLimit != null &&
        _selectedUserLimit != null &&
        _validationError == null &&
        _partyNameController.text.trim().isNotEmpty;
  }

  /// Ermittelt synchron die System-Zeitzone des Geräts (für Anzeige & Speicherung bei "Meine aktuelle Zeitzone")
  String _getSystemTimezoneId() {
    try {
      final now = DateTime.now();
      final timeZoneName = now.timeZoneName;
      final offset = now.timeZoneOffset;
      final offsetHours = offset.inHours;

      String systemTimezoneId;
      if (offsetHours == 1) {
        systemTimezoneId = 'Europe/Berlin'; // CET
      } else if (offsetHours == 2) {
        systemTimezoneId = 'Europe/Berlin'; // CEST
      } else if (offsetHours == 0) {
        systemTimezoneId = 'UTC';
      } else if (timeZoneName.contains('CET') ||
          timeZoneName.contains('CEST')) {
        systemTimezoneId = 'Europe/Berlin';
      } else if (timeZoneName == 'UTC') {
        systemTimezoneId = 'UTC';
      } else {
        systemTimezoneId = 'UTC';
      }
      return systemTimezoneId;
    } catch (e) {
      return 'UTC';
    }
  }

  /// Ermittelt die System-Zeitzone des Geräts (asynchron, setzt _currentTimezoneId)
  /// Fallback-Mechanismus wenn keine Google Location gewählt wurde
  void _updateSystemTimezone() {
    final systemTimezoneId = _getSystemTimezoneId();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentTimezoneId = systemTimezoneId;
          });
        }
      });
    }
    debugLog('✅ System-Zeitzone ermittelt: $systemTimezoneId');
  }

  /// Prüft, ob der Ortsname ein expliziter POI-Name ist (z.B. Hotel, Club) und nicht nur Adresse/Straße/Ort.
  /// Wenn name == address/street/city, handelt es sich um eine Dublette → false.
  bool _isExplicitLocationName(
    String name,
    String address,
    String? street,
    String? city,
  ) {
    final n = name.trim();
    if (n.isEmpty) return false;
    final a = address.trim().toLowerCase();
    final s = (street ?? '').trim().toLowerCase();
    final c = (city ?? '').trim().toLowerCase();
    final nLower = n.toLowerCase();
    if (a.isNotEmpty && nLower == a) return false;
    if (s.isNotEmpty && nLower == s) return false;
    if (c.isNotEmpty && nLower == c) return false;
    return true;
  }

  /// Lädt alle gespeicherten Locations des aktuellen DJs
  Future<void> _loadLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugLog('⚠️ Kein User eingeloggt, kann keine Locations laden');
        return;
      }

      debugLog('🔍 Lade Locations für User: …');

      // Versuche zuerst mit orderBy
      try {
        final locationsSnapshot = await FirebaseFirestore.instance
            .collection('locations')
            .where('created_by', isEqualTo: user.uid)
            .orderBy('location_name')
            .get();

        setState(() {
          _locations = locationsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'location_name': data['location_name'] ?? '',
              'address': data['address'] ?? '',
              'latitude': data['latitude'],
              'longitude': data['longitude'],
              'timezone_id': data['timezone_id'] ?? 'UTC',
              'fixed_party_code': data['fixed_party_code'],
              'party_code':
                  data['party_code'] ?? '', // Altes Feld (für Kompatibilität)
              'created_by': data['created_by'] ?? '',
            };
          }).toList();
        });

        debugLog('✅ Locations geladen (mit orderBy): ${_locations.length}');
      } catch (e) {
        // Falls orderBy fehlschlägt (z.B. wegen fehlendem Index), versuche ohne orderBy
        debugLog('⚠️ Fehler mit orderBy, versuche ohne: $e');
        try {
          final locationsSnapshot = await FirebaseFirestore.instance
              .collection('locations')
              .where('created_by', isEqualTo: user.uid)
              .get();

          final locationsList = locationsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'location_name': data['location_name'] ?? '',
              'address': data['address'] ?? '',
              'latitude': data['latitude'],
              'longitude': data['longitude'],
              'timezone_id': data['timezone_id'] ?? 'UTC',
              'fixed_party_code': data['fixed_party_code'],
              'party_code':
                  data['party_code'] ?? '', // Altes Feld (für Kompatibilität)
              'created_by': data['created_by'] ?? '',
            };
          }).toList();

          // Sortiere manuell nach location_name
          locationsList.sort((a, b) {
            final nameA = (a['location_name'] as String).toLowerCase();
            final nameB = (b['location_name'] as String).toLowerCase();
            return nameA.compareTo(nameB);
          });

          setState(() {
            _locations = locationsList;
          });

          debugLog(
            '✅ Locations geladen (ohne orderBy, manuell sortiert): ${_locations.length}',
          );
        } catch (e2) {
          debugLog('❌ Fehler beim Laden ohne orderBy: $e2');
          // Als letzter Fallback: Lade alle Locations (ohne Filter)
          debugLog('⚠️ Versuche alle Locations zu laden (ohne Filter)...');
          try {
            final allLocationsSnapshot = await FirebaseFirestore.instance
                .collection('locations')
                .get();

            // Filtere manuell nach created_by
            final filteredLocations = allLocationsSnapshot.docs
                .where((doc) {
                  final data = doc.data();
                  final createdBy = data['created_by'] as String?;
                  return createdBy == user.uid;
                })
                .map((doc) {
                  final data = doc.data();
                  return {
                    'id': doc.id,
                    'location_name': data['location_name'] ?? '',
                    'address': data['address'] ?? '',
                    'latitude': data['latitude'],
                    'longitude': data['longitude'],
                    'timezone_id': data['timezone_id'] ?? 'UTC',
                    'fixed_party_code': data['fixed_party_code'],
                    'party_code':
                        data['party_code'] ??
                        '', // Altes Feld (für Kompatibilität)
                    'created_by': data['created_by'] ?? '',
                  };
                })
                .toList();

            filteredLocations.sort((a, b) {
              final nameA = (a['location_name'] as String).toLowerCase();
              final nameB = (b['location_name'] as String).toLowerCase();
              return nameA.compareTo(nameB);
            });

            setState(() {
              _locations = filteredLocations;
            });

            debugLog(
              '✅ Locations geladen (manuell gefiltert): ${_locations.length}',
            );
          } catch (e3) {
            debugLog('❌ Fehler beim Laden aller Locations: $e3');
          }
        }
      }

      // Debug: Zeige alle geladenen Locations
      debugLog('📋 Finale Locations-Liste: ${_locations.length}');
      for (var location in _locations) {
        debugLog(
          '  ✅ Location: ${location['location_name']} (ID: ${location['id']})',
        );
      }
    } catch (e) {
      debugLog('❌ Fehler beim Laden der Locations: $e');
    }
  }

  // Generiere einen eindeutigen 8-stelligen Party-Code (parties + locations.party_code)
  Future<String> _generateUniquePartyCode(
    int min,
    int max,
    BuildContext context,
  ) async {
    final random = Random();
    String code = '';
    bool isUnique = false;
    int attempts = 0;
    const maxAttempts = 100;

    while (!isUnique && attempts < maxAttempts) {
      code = (min + random.nextInt(max - min + 1)).toString();

      if (await PartyService.isPartyCodeTakenInParties(code)) {
        attempts++;
        continue;
      }

      final existingLocations = await FirebaseFirestore.instance
          .collection('locations')
          .where('party_code', isEqualTo: code)
          .limit(1)
          .get();

      if (existingLocations.docs.isEmpty) {
        isUnique = true;
      } else {
        attempts++;
      }
    }

    if (!isUnique || code.isEmpty) {
      throw Exception(
        AppLocalizations.of(context)!.error_generating_party_code,
      );
    }

    return code;
  }

  // Finde oder erstelle eine Location
  Future<String?> _findOrCreateLocation(
    String locationName,
    String createdBy,
  ) async {
    if (locationName.isEmpty) {
      return null;
    }

    // Normalisiere Location-Name für Vergleich (kleinschreibung, trim)
    final normalizedName = locationName.trim().toLowerCase();

    // Prüfe ob Location bereits existiert (case-insensitive)
    final existingLocations = await FirebaseFirestore.instance
        .collection('locations')
        .get();

    for (var doc in existingLocations.docs) {
      final data = doc.data();
      final existingName = (data['location_name'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (existingName == normalizedName) {
        debugLog('Location bereits vorhanden: ${doc.id}');
        return doc.id;
      }
    }

    // Location existiert nicht, erstelle neue
    debugLog('Erstelle neue Location: $locationName');

    // Generiere eindeutigen 8-stelligen Code für Location (99000000–99999999)
    final locationCode = await _generateUniquePartyCode(
      PartyService.fixedCodeMin,
      PartyService.fixedCodeMax,
      context,
    );

    final locationRef = await FirebaseFirestore.instance
        .collection('locations')
        .add({
          'location_name': sanitizeInput(locationName.trim()),
          'party_code': locationCode,
          'created_by': createdBy,
          'created_at': Timestamp.now(),
        });

    debugLog('Neue Location erstellt: ${locationRef.id} mit Code: $locationCode');

    // Lade Locations neu
    await _loadLocations();

    return locationRef.id;
  }

  /// Konvertiert lokale Zeit zu UTC Unix-Timestamp (in Sekunden seit Epoch)
  /// Nutzt Google Time Zone API für präzise Offset-Berechnung
  /// WICHTIG: Diese Funktion ist kritisch für den Cronjob - muss absolut präzise sein
  Future<int> _convertLocalTimeToUnixTimestamp(
    DateTime localDateTime,
    String timezoneId,
    double? latitude,
    double? longitude,
  ) async {
    try {
      // Wenn wir Koordinaten haben, nutze Google Time Zone API für präzisen Offset
      if (latitude != null &&
          longitude != null &&
          latitude != 0.0 &&
          longitude != 0.0) {
        try {
          final apiKey = AppConfig.googleMapsApiKey;

          // Erstelle einen vorläufigen UTC-Timestamp für die API-Anfrage
          // Verwende die lokale Zeit als Basis für die Schätzung
          final tempUtcDateTime = DateTime.utc(
            localDateTime.year,
            localDateTime.month,
            localDateTime.day,
            localDateTime.hour,
            localDateTime.minute,
          );
          final tempUtcTimestamp =
              tempUtcDateTime.millisecondsSinceEpoch ~/ 1000;

          final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/timezone/json'
            '?location=$latitude,$longitude'
            '&timestamp=$tempUtcTimestamp'
            '&key=$apiKey',
          );

          final response = await http.get(url);

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['status'] == 'OK') {
              final rawOffset =
                  (data['rawOffset'] as num?)?.toInt() ??
                  0; // Sekunden (ohne DST)
              final dstOffset =
                  (data['dstOffset'] as num?)?.toInt() ?? 0; // Sekunden (DST)
              final totalOffset =
                  rawOffset + dstOffset; // Gesamt-Offset in Sekunden

              // Logik: Lokale Zeit = UTC Zeit + Offset
              // Also: UTC Zeit = Lokale Zeit - Offset
              // Erstelle UTC DateTime aus lokaler Zeit
              final utcDateTime = DateTime.utc(
                localDateTime.year,
                localDateTime.month,
                localDateTime.day,
                localDateTime.hour,
                localDateTime.minute,
              );

              // Subtrahiere den Offset um die echte UTC-Zeit zu bekommen
              final actualUtcDateTime = utcDateTime.subtract(
                Duration(seconds: totalOffset),
              );
              final unixTimestamp =
                  actualUtcDateTime.millisecondsSinceEpoch ~/ 1000;

              debugLog(
                '   ✅ Präzise Umrechnung: Lokal ${localDateTime.year}-${localDateTime.month.toString().padLeft(2, '0')}-${localDateTime.day.toString().padLeft(2, '0')} ${localDateTime.hour.toString().padLeft(2, '0')}:${localDateTime.minute.toString().padLeft(2, '0')} -> UTC Unix: $unixTimestamp (Offset: ${totalOffset}s = ${totalOffset ~/ 3600}h)',
              );
              return unixTimestamp;
            }
          }
        } catch (e) {
          debugLog('⚠️ Google Time Zone API Fehler, verwende Fallback: $e');
        }
      }

      // Fallback: Verwende System-Zeitzone (nicht perfekt, aber funktional)
      // Dies wird verwendet wenn keine Koordinaten vorhanden sind (z.B. "Meine aktuelle Zeitzone")
      final utcDateTime = localDateTime.toUtc();
      final unixTimestamp = utcDateTime.millisecondsSinceEpoch ~/ 1000;
      debugLog('   ⚠️ Fallback-Umrechnung (System-Zeitzone): $unixTimestamp');
      return unixTimestamp;
    } catch (e) {
      debugLog('❌ Fehler bei Zeit-Umrechnung: $e');
      // Letzter Fallback
      final fallbackTimestamp =
          localDateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
      debugLog('   ❌ Letzter Fallback: $fallbackTimestamp');
      return fallbackTimestamp;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _partyNameController.dispose();
    _locationNameController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 365));
    final locale = Localizations.localeOf(context);

    final picked = await showDatePicker(
      context: context,
      locale: locale,
      initialDate: _startDate ?? now,
      firstDate: now, // Nur ab heute
      lastDate: maxDate, // Max 1 Jahr in die Zukunft
      selectableDayPredicate: (DateTime date) {
        // Alle Tage zwischen heute und maxDate sind wählbar
        return date.isAfter(now.subtract(const Duration(days: 1))) &&
            date.isBefore(maxDate.add(const Duration(days: 1)));
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Zurücksetzen von Stunde/Minute wenn Datum geändert wird
        _startHour = null;
        _startMinute = null;
        // Endzeit zurücksetzen wenn Startzeit geändert wird
        _endDate = null;
        _endHour = null;
        _endMinute = null;
      });
      _validatePartyTimes(); // Validierung nach Änderung
      _scrollToStartTimePicker();
      // Free-DJ: Limit-Check für gewähltes Datum (Abrechnungszeitraum mit Stichtag-Logik)
      final userModel = UserService().currentUser.value;
      if (userModel != null && userModel.isFree && mounted) {
        final canCreate = await LimitService.checkPartyCreationLimit(
          userModel,
          plannedStartDate: picked,
        );
        if (!canCreate && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!
                    .free_party_quota_used_this_period,
              ),
              backgroundColor: UIConstants.appOrange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _scrollToStartTimePicker() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = _startTimePickerKey.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.5,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  Future<void> _selectStartTime() async {
    // Wenn noch kein Datum gewählt, zeige Fehler
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.party_validation_start_date_first,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Wenn noch keine Stunde gewählt, öffne Stunde-Auswahl
    if (_startHour == null) {
      await _selectStartHour();
      return;
    }

    // Wenn Stunde gewählt aber keine Minute, öffne Minute-Auswahl
    if (_startMinute == null) {
      await _selectStartMinute();
      return;
    }

    // Wenn beide gewählt, erlaube Änderung (öffne Stunde-Auswahl)
    await _selectStartHour();
  }

  Future<void> _selectStartHour() async {
    if (_startDate == null) return;

    final l10n = AppLocalizations.of(context)!;
    final availableHours = _getAvailableStartHours();
    if (availableHours.isEmpty) return;

    int? selectedHour;
    bool showMinutes = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Material(
        type: MaterialType.transparency,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            if (showMinutes && selectedHour != null) {
              // Minutenauswahl anzeigen - Kompakt mit Grid
              final availableMinutes = _getAvailableStartMinutes(selectedHour);
              return Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment(-1.0, -1.0),
                    end: Alignment(1.0, 1.0),
                    colors: [Color(0xFF1F2937), Color(0xFF121417)],
                  ),
                  border: Border.all(color: UIConstants.appOrange, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Transform.flip(
                              flipX: ['ar', 'he', 'fa', 'ur'].contains(
                                Localizations.localeOf(context).languageCode,
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: UIConstants.appOrange,
                              ),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                showMinutes = false;
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              l10n.party_pick_start_minute_title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 400),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.2,
                              ),
                          itemCount: availableMinutes.length,
                          itemBuilder: (context, index) {
                            final minute = availableMinutes[index];
                            final isSelected = _startMinute == minute;
                            return Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _startHour = selectedHour;
                                    _startMinute = minute;
                                    // Endzeit zurücksetzen wenn Startzeit geändert wird
                                    _endDate = null;
                                    _endHour = null;
                                    _endMinute = null;
                                  });
                                  Navigator.pop(dialogContext);
                                  _validatePartyTimes(); // Validierung nach Änderung
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? UIConstants.appOrange.withValues(alpha: 0.5)
                                        : Colors.grey.shade800,
                                    border: Border.all(
                                      color: isSelected
                                          ? UIConstants.appOrange
                                          : Colors.grey.shade600,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      minute.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          AppLocalizations.of(dialogContext)!.cancel,
                          style: const TextStyle(color: UIConstants.appOrange),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Stundenauswahl anzeigen - Kompakt mit Grid
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment(-1.0, -1.0),
                  end: Alignment(1.0, 1.0),
                  colors: [Color(0xFF1F2937), Color(0xFF121417)],
                ),
                border: Border.all(color: UIConstants.appOrange, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      l10n.party_pick_start_hour_title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.5,
                            ),
                        itemCount: availableHours.length,
                        itemBuilder: (context, index) {
                          final hour = availableHours[index];
                          final isSelected = _startHour == hour;
                          return Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              onTap: () {
                                selectedHour = hour;
                                setDialogState(() {
                                  showMinutes = true;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? UIConstants.appOrange.withValues(alpha: 0.5)
                                      : Colors.grey.shade800,
                                  border: Border.all(
                                    color: isSelected
                                        ? UIConstants.appOrange
                                        : Colors.grey.shade600,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${hour.toString().padLeft(2, '0')}:00',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        AppLocalizations.of(dialogContext)!.cancel,
                        style: const TextStyle(color: UIConstants.appOrange),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _selectStartMinute() async {
    if (_startDate == null || _startHour == null) return;

    final availableMinutes = _getAvailableStartMinutes();
    if (availableMinutes.isEmpty) return;

    final selectedMinute = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UIConstants.djShellPageBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: UIConstants.appOrange, width: 2),
        ),
        title: Builder(
          builder: (dialogContext) {
            final isRtl = [
              'ar',
              'he',
              'fa',
              'ur',
            ].contains(Localizations.localeOf(dialogContext).languageCode);
            return Row(
              children: [
                IconButton(
                  icon: Transform.flip(
                    flipX: isRtl,
                    child: const Icon(
                      Icons.arrow_back,
                      color: UIConstants.appOrange,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Öffne Stundenauswahl erneut
                    _selectStartHour();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(dialogContext)!
                        .party_pick_start_minute_title,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableMinutes.length,
            itemBuilder: (context, index) {
              final minute = availableMinutes[index];
              return ListTile(
                title: Text(
                  '${_startHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white),
                ),
                selected: _startMinute == minute,
                selectedTileColor: UIConstants.appOrange.withValues(alpha: 0.3),
                onTap: () => Navigator.pop(context, minute),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: const TextStyle(color: UIConstants.appOrange),
            ),
          ),
        ],
      ),
    );

    if (selectedMinute != null) {
      setState(() {
        _startMinute = selectedMinute;
        // Endzeit zurücksetzen wenn Startzeit geändert wird
        _endDate = null;
        _endHour = null;
        _endMinute = null;
      });
      _validatePartyTimes(); // Validierung nach Änderung
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null || _startHour == null || _startMinute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.party_validation_start_required,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final minEndDate = _getMinEndDate();
    final maxEndDate = _getMaxEndDate();
    if (minEndDate == null || maxEndDate == null) return;

    // Prüfe, ob Startzeit 23:55 ist oder Startzeit + 5 Minuten bereits den nächsten Tag erreicht
    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startHour!,
      _startMinute!,
    );
    DateTime actualFirstDate = minEndDate;

    // Wenn Startzeit 23:55 ist, darf "Heute" nicht als Enddatum wählbar sein
    if (_startHour == 23 && _startMinute == 55) {
      // Startzeit ist 23:55: firstDate muss auf den nächsten Tag springen
      final nextDay = startDateTime.add(const Duration(days: 1));
      actualFirstDate = DateTime(nextDay.year, nextDay.month, nextDay.day);
    } else {
      // Prüfe, ob Startzeit + 5 Minuten bereits den nächsten Tag erreicht
      final startPlusFiveMinutes = startDateTime.add(
        const Duration(minutes: 5),
      );
      if (startPlusFiveMinutes.day != _startDate!.day ||
          startPlusFiveMinutes.month != _startDate!.month ||
          startPlusFiveMinutes.year != _startDate!.year) {
        // Startzeit + 5 Minuten erreicht bereits den nächsten Tag
        actualFirstDate = DateTime(
          startPlusFiveMinutes.year,
          startPlusFiveMinutes.month,
          startPlusFiveMinutes.day,
        );
      }
    }

    final locale = Localizations.localeOf(context);
    final picked = await showDatePicker(
      context: context,
      locale: locale,
      initialDate: _endDate ?? actualFirstDate,
      firstDate: actualFirstDate,
      lastDate: maxEndDate,
      selectableDayPredicate: (DateTime date) {
        // Nur Tage zwischen minEndDate und maxEndDate sind wählbar
        return (date.isAfter(minEndDate.subtract(const Duration(days: 1))) ||
                date.isAtSameMomentAs(minEndDate)) &&
            (date.isBefore(maxEndDate.add(const Duration(days: 1))) ||
                date.isAtSameMomentAs(maxEndDate));
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        // Zurücksetzen von Stunde/Minute wenn Datum geändert wird
        _endHour = null;
        _endMinute = null;
      });
    }
  }

  Future<void> _selectEndHour() async {
    final availableHours = _getAvailableEndHours();

    int? selectedHour;
    bool showMinutes = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Material(
        type: MaterialType.transparency,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final l10n = AppLocalizations.of(dialogContext)!;
            if (showMinutes && selectedHour != null) {
              // Minutenauswahl anzeigen - Kompakt mit Grid
              final availableMinutes = _getAvailableEndMinutes(selectedHour);
              return Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment(-1.0, -1.0),
                    end: Alignment(1.0, 1.0),
                    colors: [Color(0xFF1F2937), Color(0xFF121417)],
                  ),
                  border: Border.all(color: UIConstants.appOrange, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Transform.flip(
                              flipX: ['ar', 'he', 'fa', 'ur'].contains(
                                Localizations.localeOf(context).languageCode,
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: UIConstants.appOrange,
                              ),
                            ),
                            onPressed: () {
                              setDialogState(() {
                                showMinutes = false;
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              l10n.party_pick_end_minute_title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 400),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 6,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.2,
                              ),
                          itemCount: availableMinutes.length,
                          itemBuilder: (context, index) {
                            final minute = availableMinutes[index];
                            final isSelected = _endMinute == minute;
                            return Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _endHour = selectedHour;
                                    _endMinute = minute;
                                  });
                                  Navigator.pop(dialogContext);
                                  _validatePartyTimes(); // Validierung nach Änderung
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? UIConstants.appOrange.withValues(alpha: 0.5)
                                        : Colors.grey.shade800,
                                    border: Border.all(
                                      color: isSelected
                                          ? UIConstants.appOrange
                                          : Colors.grey.shade600,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      minute.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          AppLocalizations.of(dialogContext)!.cancel,
                          style: const TextStyle(color: UIConstants.appOrange),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Stundenauswahl anzeigen - Kompakt mit Grid
            return Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment(-1.0, -1.0),
                  end: Alignment(1.0, 1.0),
                  colors: [Color(0xFF1F2937), Color(0xFF121417)],
                ),
                border: Border.all(color: UIConstants.appOrange, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      l10n.party_pick_end_hour_title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.5,
                            ),
                        itemCount: availableHours.length,
                        itemBuilder: (context, index) {
                          final hour = availableHours[index];
                          final isSelected = _endHour == hour;
                          return Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              onTap: () {
                                selectedHour = hour;
                                setDialogState(() {
                                  showMinutes = true;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? UIConstants.appOrange.withValues(alpha: 0.5)
                                      : Colors.grey.shade800,
                                  border: Border.all(
                                    color: isSelected
                                        ? UIConstants.appOrange
                                        : Colors.grey.shade600,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${hour.toString().padLeft(2, '0')}:00',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        AppLocalizations.of(dialogContext)!.cancel,
                        style: const TextStyle(color: UIConstants.appOrange),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _selectEndMinute() async {
    if (_endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.party_validation_end_date_first,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_endHour == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.party_validation_end_hour_first,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final availableMinutes = _getAvailableEndMinutes();
    if (availableMinutes.isEmpty) return;

    final selectedMinute = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UIConstants.djShellPageBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: UIConstants.appOrange, width: 2),
        ),
        title: Builder(
          builder: (dialogContext) {
            final isRtl = [
              'ar',
              'he',
              'fa',
              'ur',
            ].contains(Localizations.localeOf(dialogContext).languageCode);
            return Row(
              children: [
                IconButton(
                  icon: Transform.flip(
                    flipX: isRtl,
                    child: const Icon(
                      Icons.arrow_back,
                      color: UIConstants.appOrange,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // Öffne Stundenauswahl erneut
                    _selectEndHour();
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(dialogContext)!
                        .party_pick_end_minute_title,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableMinutes.length,
            itemBuilder: (context, index) {
              final minute = availableMinutes[index];
              return ListTile(
                title: Text(
                  '${_endHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white),
                ),
                selected: _endMinute == minute,
                selectedTileColor: UIConstants.appOrange.withValues(alpha: 0.3),
                onTap: () => Navigator.pop(context, minute),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.cancel,
              style: const TextStyle(color: UIConstants.appOrange),
            ),
          ),
        ],
      ),
    );

    if (selectedMinute != null) {
      setState(() {
        _endMinute = selectedMinute;
      });
      _validatePartyTimes(); // Validierung nach Änderung
    }
  }

  Future<void> _selectEndTime() async {
    // Wenn noch kein Startdatum/Startzeit gewählt, zeige Fehler
    if (_startDate == null || _startHour == null || _startMinute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.party_validation_start_required,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Wenn noch kein Enddatum gewählt, zeige Fehler
    if (_endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.party_validation_end_date_first,
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Wenn noch keine Stunde gewählt, öffne Stunde-Auswahl
    if (_endHour == null) {
      await _selectEndHour();
      return;
    }

    // Wenn Stunde gewählt aber keine Minute, öffne Minute-Auswahl
    if (_endMinute == null) {
      await _selectEndMinute();
      return;
    }

    // Wenn beide gewählt, erlaube Änderung (öffne Stunde-Auswahl)
    await _selectEndHour();
  }

  void _showLocationSelectionDialog(BuildContext context) {
    LocationPicker.show(
      context: context,
      locations: _locations,
      onLocationSelected: (locationModel, useOneTimeEventCode) {
        setState(() {
          _selectedLocationModel = locationModel;
          _selectedLocationId = locationModel.id;
          _locationSelectionMode = 'dropdown';
          _selectedGooglePlace = null;
          _locationNameController.clear();
          _currentTimezoneId = locationModel.timezoneId ?? 'UTC';
          locationId = locationModel.id;
          _saveLocationForFutureParties = false;
          _useFixedPartyCodeForLocation = false;
          _useOneTimeEventCode = useOneTimeEventCode;
        });
        debugLog('✅ Location ausgewählt: ${locationModel.locationName}');
        debugLog('   Einmaligen Code generieren: $useOneTimeEventCode');
        if (locationModel.fixedPartyCode != null) {
          debugLog('   Fester Code vorhanden: ${locationModel.fixedPartyCode}');
        }
      },
    );
  }

  Future<void> _saveParty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    if (_startDate == null ||
        _startHour == null ||
        _startMinute == null ||
        _endDate == null ||
        _endHour == null ||
        _endMinute == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.validation_all_datetimes_required),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startHour!,
      _startMinute!,
    );

    final endDateTime = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endHour!,
      _endMinute!,
    );

    // Validierung: Startzeit muss mindestens 5 Minuten in der Zukunft sein
    final minStartDateTime = _getMinStartDateTime();
    if (startDateTime.isBefore(minStartDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.party_validation_start_min_future),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Ermittle Admin-Status (Firestore-Rolle)
    final isAdmin = AppConfig.isAdminRole(UserService().currentUser.value);

    // Nutze zentrale Validierungsklasse mit Admin-Status
    final validationError = PartyValidator.validate(
      startDateTime,
      endDateTime,
      allParties: _allParties,
      isAdmin: isAdmin,
      context: context,
    );

    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationError), backgroundColor: Colors.red),
      );
      return;
    }

    // Validierung der Limits
    if (_selectedGuestLimit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.validation_guest_limit_required_new),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedUserLimit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.validation_user_limit_required_new),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Free-DJ: Limits hart auf 1 (Safety Check – unabhängig vom State)
    final userModel = UserService().currentUser.value;
    final isFree = userModel != null && userModel.isFree;
    final guestLimit = isFree ? 1 : _selectedGuestLimit!;
    final userLimit = isFree ? 1 : _selectedUserLimit!;

    setState(() {
      _isLoading = true;
    });

    try {
      // Hole aktuellen User (DJ)
      final user = FirebaseAuth.instance.currentUser;
      final createdBy = user?.uid ?? '';
      final createdByEmail = user?.email ?? '';

      // ✅ Hole DJ-Logo aus User-Profil für Party-Dokument
      String? djLogoUrl;
      try {
        if (user != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            djLogoUrl = userData?['dj_logo_url'] as String?;
          }
        }
      } catch (e) {
        debugLog(
          '⚠️ Fehler beim Laden des DJ-Logos für Party (nicht kritisch): $e',
        );
        // Fehler ist nicht kritisch - Party kann auch ohne Logo erstellt werden
      }

      String partyName;
      String partyCode =
          ''; // Initialisiert, wird später durch PartyService gesetzt

      // Location-Daten aus Google Place (falls vorhanden)
      String? locationName;
      String? locationAddress;
      String? locationZip;
      String? locationCity;
      String? locationStreet;
      double? latitude;
      double? longitude;
      String? timezoneId;
      String? placeId;

      // Daten-Trennung basierend auf Auswahlmodus
      String?
      locationIdForPartyCode; // Für Code-Generierung (wird nur verwendet wenn festen Code nutzen)

      if (_locationSelectionMode == 'dropdown' &&
          _selectedLocationModel != null) {
        // Location aus Dialog ausgewählt (locations-Collection hat aktuell keine PLZ/Ort/Straße)
        locationName = _selectedLocationModel!.locationName;
        locationAddress = _selectedLocationModel!.address;
        locationZip = null;
        locationCity = null;
        locationStreet = null;
        latitude = _selectedLocationModel!.latitude;
        longitude = _selectedLocationModel!.longitude;
        timezoneId = _selectedLocationModel!.timezoneId;
        placeId = null; // Kein Google Place ID für gespeicherte Locations
        // locationIdForPartyCode wird nur gesetzt wenn festen Code verwenden
        // WICHTIG: Nur wenn useCustomCode NICHT aktiv ist (für beide Party-Typen)
        if (_selectedLocationModel!.fixedPartyCode != null &&
            !_useOneTimeEventCode) {
          // Bei öffentlichen Partys: locationIdForPartyCode wird für Code-Generierung verwendet
          // Bei privaten Partys: locationIdForPartyCode wird ignoriert (immer dynamisch)
          if (_partyType == 'public') {
            locationIdForPartyCode = _selectedLocationModel!.id;
          }
        }
        debugLog('✅ Location aus Dialog ausgewählt: $locationName');
        if (_selectedLocationModel!.fixedPartyCode != null) {
          debugLog(
            '   Fester Code vorhanden: ${_selectedLocationModel!.fixedPartyCode}',
          );
          debugLog('   Einmaligen Code nutzen: $_useOneTimeEventCode');
        }
      } else if (_locationSelectionMode == 'search' &&
          _selectedGooglePlace != null) {
        // "Anderen Ort suchen" wurde gewählt und Google Place ausgewählt (inkl. address_components)
        locationName = _selectedGooglePlace!.name;
        locationAddress = _selectedGooglePlace!.address;
        locationZip = _selectedGooglePlace!.postalCode;
        locationCity = _selectedGooglePlace!.city;
        locationStreet = _selectedGooglePlace!.street;
        latitude = _selectedGooglePlace!.latitude;
        longitude = _selectedGooglePlace!.longitude;
        timezoneId = _selectedGooglePlace!.timezoneId;
        placeId = _selectedGooglePlace!.placeId;
        locationIdForPartyCode =
            null; // Wird später gesetzt wenn Location gespeichert wird
        debugLog('✅ Google Place ausgewählt: $locationName');
      } else {
        // "Mein aktueller Standort" wurde gewählt oder keine Location ausgewählt
        // Location-Details werden nicht angegeben, aber Zeitzone wird gespeichert
        locationName = null;
        locationAddress = null;
        locationZip = null;
        locationCity = null;
        locationStreet = null;
        latitude = null;
        longitude = null;
        placeId = null;
        locationIdForPartyCode = null;
        // Verwende System-Zeitzone
        timezoneId = _currentTimezoneId ?? 'UTC';
        debugLog('✅ Verwende System-Zeitzone: $timezoneId');
      }

      // Sicherstellen, dass timezoneId immer vorhanden ist
      if (timezoneId == null || timezoneId.isEmpty) {
        timezoneId = _currentTimezoneId ?? 'UTC';
        debugLog('⚠️ Fallback auf UTC-Zeitzone');
      }

      // Party-Name und Party-Code für beide Party-Typen
      partyName = SecurityHelper.sanitize(
        _partyNameController.text.trim(),
        maxLength: 100,
      );

      // Nutze PartyService für Code-Generierung mit Retry-Logik
      // Logik:
      // - Öffentlich + Location mit fixed_party_code + "Einmaligen Code" AUS: Nutze festen Code
      // - Öffentlich + Location mit fixed_party_code + "Einmaligen Code" AN: Generiere dynamischen Code
      // - Öffentlich + Location ohne fixed_party_code: Generiere dynamischen Code
      // - Privat: Immer dynamischen Code (auch bei gespeicherten Locations)
      try {
        // Prüfe ob Location mit festem Code gewählt wurde und ob dieser verwendet werden soll
        bool shouldUseFixedCode = false;
        if (_partyType == 'public' &&
            locationIdForPartyCode != null &&
            _selectedLocationModel != null &&
            _selectedLocationModel!.fixedPartyCode != null &&
            !_useOneTimeEventCode) {
          // Öffentlich + Location mit festem Code + Option "Einmaligen Code" ist AUS
          shouldUseFixedCode = true;
        }

        if (shouldUseFixedCode) {
          // Verwende festen Code der Location
          partyCode = _selectedLocationModel!.fixedPartyCode!;
          debugLog('✅ Verwende festen Code der Location: $partyCode');
        } else {
          // Generiere dynamischen Code (100k-899k)
          // Bei privaten Partys: locationIdForPartyCode wird ignoriert (immer dynamisch)
          // Bei öffentlichen Partys: locationIdForPartyCode wird ignoriert wenn _useOneTimeEventCode = true
          partyCode = await PartyService.generatePartyCode(
            isFixedCode: false,
            createdBy: createdBy,
          );
          debugLog('✅ Dynamischer Party-Code generiert: $partyCode');
        }
      } catch (e) {
        debugLog('❌ Fehler bei Party-Code-Generierung: $e');
        // Retry-Logik: Versuche es nochmal (max. 3 Versuche)
        bool codeGenerated = false;
        int retryCount = 0;
        const maxRetries = 3;

        while (!codeGenerated && retryCount < maxRetries) {
          retryCount++;
          debugLog(
            '🔄 Wiederhole Code-Generierung (Versuch $retryCount/$maxRetries)...',
          );

          try {
            // Warte kurz bevor Retry (um Race Conditions zu vermeiden)
            await Future.delayed(Duration(milliseconds: 500 * retryCount));

            partyCode = await PartyService.determinePartyCodeForNewParty(
              partyType: _partyType,
              locationId: locationIdForPartyCode,
              createdBy: createdBy,
            );
            codeGenerated = true;
            debugLog('✅ Party-Code nach Retry generiert: $partyCode');
          } catch (retryError) {
            debugLog('❌ Retry $retryCount fehlgeschlagen: $retryError');
            if (retryCount >= maxRetries) {
              // Alle Versuche fehlgeschlagen
              throw Exception(l10n.party_code_retry_exhausted(maxRetries));
            }
          }
        }

        if (!codeGenerated) {
          throw Exception(l10n.party_code_generate_failed_retry);
        }
      }

      // locationId wird nur für öffentliche Partys mit vorhandenen Locations verwendet
      // (alte Logik für Dropdown-Auswahl - kann später entfernt werden)
      locationId = null;

      // Unix-Berechnung: Konvertiere lokale Zeit zu UTC Unix-Timestamp
      // Nutze timezone_id für die präzise Umrechnung (wichtig für Cronjob)
      int startTimePosix;
      int endTimePosix;

      // Erstelle DateTime-Objekte in lokaler Zeit (basierend auf gewählter Zeitzone)
      // WICHTIG: Diese werden nur für die Anzeige verwendet, nicht für die Speicherung
      final localStartDateTime = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
        _startHour!,
        _startMinute!,
      );

      final localEndDateTime = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        _endHour!,
        _endMinute!,
      );

      try {
        // Konvertiere zu UTC Unix-Timestamp basierend auf timezone_id
        // Verwende Google Time Zone API um den Offset für das jeweilige Datum zu bekommen
        startTimePosix = await _convertLocalTimeToUnixTimestamp(
          localStartDateTime,
          timezoneId,
          latitude,
          longitude,
        );

        endTimePosix = await _convertLocalTimeToUnixTimestamp(
          localEndDateTime,
          timezoneId,
          latitude,
          longitude,
        );

        debugLog('✅ Unix-Timestamps berechnet (präzise):');
        debugLog('   Start (UTC): $startTimePosix');
        debugLog('   End (UTC): $endTimePosix');
        debugLog('   Zeitzone: $timezoneId');
        debugLog(
          '   Start lokale Zeit: ${localStartDateTime.year}-${localStartDateTime.month.toString().padLeft(2, '0')}-${localStartDateTime.day.toString().padLeft(2, '0')} ${localStartDateTime.hour.toString().padLeft(2, '0')}:${localStartDateTime.minute.toString().padLeft(2, '0')}',
        );
        debugLog(
          '   End lokale Zeit: ${localEndDateTime.year}-${localEndDateTime.month.toString().padLeft(2, '0')}-${localEndDateTime.day.toString().padLeft(2, '0')} ${localEndDateTime.hour.toString().padLeft(2, '0')}:${localEndDateTime.minute.toString().padLeft(2, '0')}',
        );
      } catch (e) {
        debugLog('❌ Fehler bei Unix-Berechnung: $e');
        // Fallback: Verwende normale Timestamps (System-Zeitzone)
        startTimePosix = startDateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
        endTimePosix = endDateTime.toUtc().millisecondsSinceEpoch ~/ 1000;
        debugLog('⚠️ Fallback auf System-Zeitzone für Unix-Berechnung');
      }

      // VERGLEICHS-CHECK: Prüfe Dauer der Party (Ende minus Start) in UTC
      final durationSeconds = endTimePosix - startTimePosix;
      final durationHours = durationSeconds / 3600.0;
      final durationMinutes = (durationSeconds % 3600) / 60.0;
      debugLog('=== Speichere Party ===');
      debugLog('Party Name: $partyName');
      debugLog('Party Code: $partyCode');
      debugLog(
        'Start lokale Zeit: ${localStartDateTime.year}-${localStartDateTime.month.toString().padLeft(2, '0')}-${localStartDateTime.day.toString().padLeft(2, '0')} ${localStartDateTime.hour.toString().padLeft(2, '0')}:${localStartDateTime.minute.toString().padLeft(2, '0')}',
      );
      debugLog(
        'End lokale Zeit: ${localEndDateTime.year}-${localEndDateTime.month.toString().padLeft(2, '0')}-${localEndDateTime.day.toString().padLeft(2, '0')} ${localEndDateTime.hour.toString().padLeft(2, '0')}:${localEndDateTime.minute.toString().padLeft(2, '0')}',
      );
      debugLog('Start Unix (UTC): $startTimePosix');
      debugLog('End Unix (UTC): $endTimePosix');
      debugLog(
        'Dauer (UTC): ${durationHours.toStringAsFixed(2)} Stunden (${durationMinutes.toStringAsFixed(0)} Minuten)',
      );

      // ENDZEIT-SYNCHRONISATION: Beide Felder müssen aus demselben UTC-Wert abgeleitet werden
      // WICHTIG: Keine lokale Umrechnung - der bereits berechnete UTC-Wert ist das Gesetz
      final startDateUtc = Timestamp.fromMillisecondsSinceEpoch(
        startTimePosix * 1000,
      );
      final endDateUtc = Timestamp.fromMillisecondsSinceEpoch(
        endTimePosix * 1000,
      );

      debugLog('Start Timestamp (UTC): $startDateUtc');
      debugLog('End Timestamp (UTC): $endDateUtc');

      final partyData = {
        'party_name': partyName,
        'start_date':
            startDateUtc, // Abgeleitet vom UTC Unix-Timestamp - ABSOLUT KONSISTENT
        'end_date':
            endDateUtc, // Abgeleitet vom UTC Unix-Timestamp - ABSOLUT KONSISTENT
        'start_time_posix':
            startTimePosix, // Unix-Timestamp in UTC (Sekunden seit Epoch) - PRÄZISE für Cronjob
        'end_time_posix':
            endTimePosix, // Unix-Timestamp in UTC (Sekunden seit Epoch) - PRÄZISE für Cronjob
        'lifecycle_status': 'active', // Status für Cronjob
        'created_at': Timestamp.now(),
        'party_code': partyCode,
        'party_type': _partyType, // 'private' oder 'public'
        'created_by': createdBy, // User-ID des DJs
        'djId': createdBy, // Explizit für Firestore-Rules (allow create: djId == request.auth.uid)
        'created_by_email': createdByEmail, // Email des DJs
        'dj_code': createdBy, // DJ-Code (User-ID des DJs)
        // Für Gäste: Abo-Stufe ohne users-Lesezugriff (Wish-Limit pro 2h-Block)
        'dj_plan_type':
            (userModel?.planType ?? 'free').trim().toLowerCase(),
        'guest_limit_per_hour': guestLimit,
        'user_limit_per_hour': userLimit,
      };

      // Füge location_id nur bei öffentlichen Partys hinzu (wenn vorhandene Location ausgewählt)
      if (_partyType == 'public' && locationIdForPartyCode != null) {
        partyData['location_id'] = locationIdForPartyCode;
      }

      // Füge Location-Daten hinzu (nur wenn vorhanden – keine Platzhalter)
      if (locationName != null && locationName!.trim().isNotEmpty) {
        partyData['location_name'] = SecurityHelper.sanitize(
          locationName!.trim(),
          maxLength: 120,
        );
      }
      if (locationAddress != null && locationAddress!.trim().isNotEmpty) {
        partyData['location_address'] = SecurityHelper.sanitize(
          locationAddress!.trim(),
          maxLength: 200,
        );
      }
      if (locationZip != null && locationZip!.trim().isNotEmpty) {
        partyData['location_zip'] = SecurityHelper.sanitize(
          locationZip!.trim(),
          maxLength: 20,
        );
      }
      if (locationCity != null && locationCity!.trim().isNotEmpty) {
        partyData['location_city'] = SecurityHelper.sanitize(
          locationCity!.trim(),
          maxLength: 80,
        );
      }
      if (locationStreet != null && locationStreet!.trim().isNotEmpty) {
        partyData['location_street'] = SecurityHelper.sanitize(
          locationStreet!.trim(),
          maxLength: 120,
        );
      }
      // Pin-Drop / Google Place: Koordinaten aus LocationResult (_selectedGooglePlace) bzw.
      // aus gespeicherter Location (_selectedLocationModel) landen hier im Party-Dokument.
      if (latitude != null && latitude != 0.0) {
        partyData['latitude'] = latitude;
      }
      if (longitude != null && longitude != 0.0) {
        partyData['longitude'] = longitude;
      }
      // Zeitzone ist immer vorhanden (entweder Google oder System-Fallback)
      partyData['timezone_id'] = timezoneId ?? 'UTC';
      if (placeId != null && placeId.isNotEmpty) {
        partyData['place_id'] = placeId;
      }
      // Privatsphäre-Einstellung
      partyData['show_location_publicly'] = _showLocationPublicly;

      // ✅ Füge DJ-Logo hinzu (Key: dj_logo für PWA-Kompatibilität)
      if (djLogoUrl != null && djLogoUrl.isNotEmpty) {
        partyData['dj_logo'] = djLogoUrl; // Key ohne _url für PWA
      }

      // Debug-Logs für Permission-Denied-Fehler
      debugLog('🔍 Speichere Party - DJ');
      debugLog('🔍 Location ID: ${locationIdForPartyCode ?? "null"}');
      debugLog('🔍 DJ Logo URL: ${djLogoUrl ?? "kein Logo"}');

      // Free-DJ: Wenn bereits eine aktive Party im Zyklus existiert, neue als standby speichern (mit Hinweis).
      // Sonst: bei Limit-Erreichen (canCreate=false) trotzdem speichern als standby, damit User die Party anlegt.
      bool saveAsStandby = false;
      if (userModel != null && userModel.isFree) {
        final canCreate = await PartyService.canCreateParty(
          userModel,
          plannedStartDate: localStartDateTime,
        );
        if (!canCreate) {
          saveAsStandby =
              true; // Kontingent ausgeschöpft → neue Party als standby speichern
        } else {
          final activeCount =
              await PartyLimitService.countActivePartiesInCurrentPeriod(
                userModel,
              );
          if (activeCount >= 1) saveAsStandby = true;
        }
      }
      partyData['lifecycle_status'] = saveAsStandby ? 'standby' : 'active';

      DocumentReference? docRef;
      try {
        docRef = await FirebaseFirestore.instance
            .collection('parties')
            .add(SecurityHelper.sanitizeMap(partyData));

        debugLog('Party gespeichert mit ID: ${docRef.id}');
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          debugLog('❌ Permission Denied - DJ');
          debugLog('❌ Location ID: ${locationIdForPartyCode ?? "null"}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.party_save_permission_denied),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
        // Andere Firebase-Fehler weiterwerfen
        rethrow;
      } catch (e) {
        // Andere Fehler weiterwerfen
        rethrow;
      }

      // Sicherstellen, dass docRef nicht null ist
      if (docRef == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Location speichern (wenn Checkbox aktiviert und Google Place/Karte ausgewählt)
      // WICHTIG: Dies passiert NACH dem Party-Speichern, damit wir die Party-ID haben
      if (_saveLocationForFutureParties &&
          (_selectedGooglePlace != null ||
              (_locationSelectionMode == 'search' &&
                  latitude != null &&
                  longitude != null))) {
        try {
          String? fixedPartyCode;
          if (_useFixedPartyCodeForLocation) {
            // Generiere festen Party-Code (900k-Bereich) für die Location
            // Dieser Code wird dann für zukünftige Partys an dieser Location verwendet
            fixedPartyCode = await PartyService.generatePartyCode(
              isFixedCode: true,
              createdBy: createdBy,
            );
            debugLog(
              '✅ Fester Party-Code für Location generiert: $fixedPartyCode',
            );

            // Aktualisiere die gerade erstellte Party mit diesem festen Code
            // (nur wenn noch kein fester Code von der Location verwendet wurde)
            if (locationIdForPartyCode == null) {
              await docRef.update(
                SecurityHelper.sanitizeMap({'party_code': fixedPartyCode}),
              );
              partyCode = fixedPartyCode; // Aktualisiere für party_status
              debugLog(
                '✅ Party-Code auf festen Location-Code aktualisiert: $fixedPartyCode',
              );
            }
          }

          // Erstelle oder aktualisiere Location
          final savedLocationId = await PartyService.createOrUpdateLocation(
            locationName: locationName ?? l10n.unnamed_location,
            address: locationAddress,
            latitude: latitude,
            longitude: longitude,
            timezoneId: timezoneId ?? 'UTC',
            createdBy: createdBy,
            fixedPartyCode: fixedPartyCode,
            updateExisting: true,
          );

          debugLog('✅ Location gespeichert/aktualisiert: $savedLocationId');

          // Aktualisiere die Party mit der location_id (falls noch nicht gesetzt)
          if (_partyType == 'public' && locationIdForPartyCode == null) {
            await docRef.update(
              SecurityHelper.sanitizeMap({'location_id': savedLocationId}),
            );
            debugLog('✅ Party mit location_id verknüpft: $savedLocationId');
          }
        } catch (e) {
          debugLog('❌ Fehler beim Speichern der Location: $e');
          // Fehler beim Speichern der Location ist nicht kritisch, Party wurde bereits erstellt
          // Zeige Warnung aber keine Fehlermeldung
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!
                      .party_created_location_save_failed(e.toString()),
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }

      // Erstelle Eintrag in party_status Collection
      await FirebaseFirestore.instance
          .collection('party_status')
          .add(
            SecurityHelper.sanitizeMap({
              'party_code': partyCode,
              'dj_code': createdBy, // User-ID des aktuellen DJ-Users
              'status': true, // true = aktiv, false = inaktiv
              'created_at': Timestamp.now(),
              'party_id': docRef.id, // Referenz zur Party-Dokument-ID
            }),
          );

      debugLog(
        'Party-Status gespeichert für Party-Code: $partyCode, DJ-Code: $createdBy',
      );
      debugLog('✅ Party erfolgreich erstellt: ${docRef.id} mit Code: $partyCode');

      if (mounted) {
        if (saveAsStandby) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.party_saved_standby_free_limit,
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.party_created_success,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        Navigator.pop(context);
      }
    } catch (e) {
      debugLog('❌ Fehler beim Speichern der Party: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context)!;

        // Prüfe ob es ein Netzwerkfehler ist
        String errorMessage;
        if (e.toString().contains('network') ||
            e.toString().contains('internet') ||
            e.toString().contains('connection') ||
            e.toString().contains('timeout')) {
          errorMessage = loc.error_no_network_retry;
        } else if (e.toString().contains('Party-Code') ||
            e.toString().contains('Code generieren')) {
          errorMessage = loc.error_generating_party_code;
        } else {
          errorMessage = '${loc.error_saving_party} ${e.toString()}';
        }

        // Zeige Fehler-Dialog im Schwarz/Orange Design
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: UIConstants.djShellPageBackground,
            title: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: UIConstants.appOrange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(dialogContext)!.error,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  loc.ok,
                  style: const TextStyle(
                    color: UIConstants.appOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: UIConstants.appOrange, width: 2),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime? date, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (date == null) return localizations.not_selected;
    // Verwende dynamisches Datumsformat basierend auf Locale
    final locale = Localizations.localeOf(context);
    return DateFormat.yMd(locale.toString()).format(date);
  }

  String _formatStartTime(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (_startDate == null) return localizations.not_selected;
    if (_startHour == null) return localizations.select_hour;
    if (_startMinute == null) return localizations.select_minute;
    return _formatTime(
      TimeOfDay(hour: _startHour!, minute: _startMinute!),
      context,
    );
  }

  String _formatEndTime(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (_endDate == null) return localizations.not_selected;
    if (_endHour == null) return localizations.select_hour;
    if (_endMinute == null) return localizations.select_minute;
    return _formatTime(
      TimeOfDay(hour: _endHour!, minute: _endMinute!),
      context,
    );
  }

  /// 5-Minuten-Schritte für Zeit-Dropdowns
  final List<int> _kFiveMinuteSteps = const [
    0,
    5,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55,
  ];

  /// Aufrunden auf nächstes 5-Minuten-Intervall (z. B. 12:51 → 12:55, 12:56 → 13:00).
  int _roundToNext5Minutes(int minute) {
    if (minute <= 0) return 0;
    return ((minute + 4) ~/ 5) * 5;
  }

  /// Frühestmögliche Startzeit: jetzt + 5 Min Puffer, aufgerundet auf nächstes 5-Min-Intervall.
  /// Wenn Aufrunden Minuten >= 60 ergibt (z. B. 12:56 → 13:00), muss die aktuelle Stunde aus der Auswahl.
  /// Returns (hour, minute) für heute.
  ({int hour, int minute}) _getEarliestStartHourMinute() {
    final now = DateTime.now();
    final buffered = now.add(const Duration(minutes: 5));
    int bufferedMinute = buffered.minute;
    int roundedMinute = _roundToNext5Minutes(bufferedMinute);
    int earliestHour = buffered.hour;
    int earliestMinute = roundedMinute;
    if (roundedMinute >= 60) {
      earliestHour = buffered.hour + 1;
      earliestMinute = 0;
    }
    if (earliestHour >= 24) {
      earliestHour =
          0; // nächster Tag – für „heute“ keine Stunde wählbar, Liste leer
    }
    return (hour: earliestHour, minute: earliestMinute);
  }

  /// Berechnet die minimale Startzeit (aktuell + 5 Minuten, auf 5-Minuten-Intervall aufgerundet)
  DateTime _getMinStartDateTime() {
    final now = DateTime.now();
    final buffered = now.add(const Duration(minutes: 5));
    final roundedMinute = _roundToNext5Minutes(buffered.minute);
    if (roundedMinute >= 60) {
      return DateTime(
        buffered.year,
        buffered.month,
        buffered.day,
        buffered.hour + 1,
        0,
      );
    }
    return DateTime(
      buffered.year,
      buffered.month,
      buffered.day,
      buffered.hour,
      roundedMinute,
    );
  }

  /// Berechnet die maximale Endzeit (Startzeit + 23:55 Stunden)
  DateTime? _getMaxEndDateTime() {
    if (_startDate == null || _startHour == null || _startMinute == null) {
      return null;
    }
    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startHour!,
      _startMinute!,
    );
    // Maximal 23 Stunden und 55 Minuten später
    return startDateTime.add(const Duration(hours: 23, minutes: 55));
  }

  /// Berechnet verfügbare Startstunden basierend auf gewähltem Datum (12:51-Fix: bei Aufrunden auf 60 Min Stunde ausschließen)
  List<int> _getAvailableStartHours() {
    if (_startDate == null) return [];
    final now = DateTime.now();
    if (_startDate!.year == now.year &&
        _startDate!.month == now.month &&
        _startDate!.day == now.day) {
      final earliest = _getEarliestStartHourMinute();
      if (earliest.hour >= 24) return [];
      return List.generate(
        24 - earliest.hour,
        (index) => earliest.hour + index,
      );
    }
    return List.generate(24, (index) => index);
  }

  /// Berechnet verfügbare Startminuten: bei frühestmöglicher Stunde nur Werte >= earliestMinute
  List<int> _getAvailableStartMinutes([int? tempHour]) {
    final hourToUse = tempHour ?? _startHour;
    if (_startDate == null || hourToUse == null) return [];
    final now = DateTime.now();
    if (_startDate!.year == now.year &&
        _startDate!.month == now.month &&
        _startDate!.day == now.day) {
      final earliest = _getEarliestStartHourMinute();
      if (hourToUse == earliest.hour) {
        return _kFiveMinuteSteps.where((m) => m >= earliest.minute).toList();
      }
    }
    return List<int>.from(_kFiveMinuteSteps);
  }

  /// Berechnet verfügbare Enddaten basierend auf Startzeit
  DateTime? _getMinEndDate() {
    if (_startDate == null || _startHour == null || _startMinute == null) {
      return null;
    }
    return _startDate; // Enddatum kann am selben Tag wie Startdatum sein
  }

  DateTime? _getMaxEndDate() {
    final maxEndDateTime = _getMaxEndDateTime();
    if (maxEndDateTime == null) return null;
    return DateTime(
      maxEndDateTime.year,
      maxEndDateTime.month,
      maxEndDateTime.day,
    );
  }

  /// Berechnet verfügbare Endstunden basierend auf Startzeit und gewähltem Enddatum
  List<int> _getAvailableEndHours() {
    if (_startDate == null ||
        _startHour == null ||
        _startMinute == null ||
        _endDate == null) {
      return [];
    }

    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startHour!,
      _startMinute!,
    );
    final maxEndDateTime = startDateTime.add(
      const Duration(hours: 23, minutes: 55),
    );

    // Wenn Enddatum == Startdatum
    if (_endDate!.year == _startDate!.year &&
        _endDate!.month == _startDate!.month &&
        _endDate!.day == _startDate!.day) {
      // minHour ist die aktuelle Startstunde
      final minHour = _startHour!;
      // maxHour ist 23, außer wenn das 23:55h-Limit noch am selben Tag endet
      int maxHour;
      if (maxEndDateTime.year == _startDate!.year &&
          maxEndDateTime.month == _startDate!.month &&
          maxEndDateTime.day == _startDate!.day) {
        // 23:55h-Limit endet noch am selben Tag: maxHour = Stunde von maxEndDateTime
        maxHour = maxEndDateTime.hour;
      } else {
        // 23:55h-Limit endet am nächsten Tag: maxHour = 23
        maxHour = 23;
      }
      debugLog('DEBUG: minHour: $minHour, maxHour: $maxHour');
      debugLog('DEBUG: maxEndDateTime: $maxEndDateTime');
      return List.generate(maxHour - minHour + 1, (index) => minHour + index);
    } else {
      // Enddatum ist später: prüfe ob Enddatum der Tag des 23:55h-Limits ist
      final maxEndDate = maxEndDateTime;
      int maxHour;
      if (_endDate!.year == maxEndDate.year &&
          _endDate!.month == maxEndDate.month &&
          _endDate!.day == maxEndDate.day) {
        // Enddatum ist der Tag des 23:55h-Limits: maxHour = Stunde von maxEndDateTime
        maxHour = maxEndDateTime.hour;
      } else {
        // Enddatum ist später: maxHour auf 23 setzen
        maxHour = 23;
      }
      return List.generate(maxHour + 1, (index) => index);
    }
  }

  /// Berechnet verfügbare Endminuten basierend auf Startzeit, Enddatum und gewählter Endstunde
  List<int> _getAvailableEndMinutes([int? tempHour]) {
    final hourToUse = tempHour ?? _endHour;
    if (_startDate == null ||
        _startHour == null ||
        _startMinute == null ||
        _endDate == null ||
        hourToUse == null) {
      return [];
    }

    final startDateTime = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startHour!,
      _startMinute!,
    );
    final maxEndDateTime = startDateTime.add(
      const Duration(hours: 23, minutes: 55),
    );

    // Fall "Gleicher Tag & Gleiche Stunde": nur Minuten > Startminute
    if (_endDate!.year == _startDate!.year &&
        _endDate!.month == _startDate!.month &&
        _endDate!.day == _startDate!.day &&
        hourToUse == _startHour) {
      final startMinute = _startMinute!;
      final filtered = _kFiveMinuteSteps.where((m) => m > startMinute).toList();
      return filtered.isEmpty ? [0] : filtered;
    }

    // Fall "Maximales Limit": Endstunde = maxEndDateTime.hour
    if (_endDate!.year == maxEndDateTime.year &&
        _endDate!.month == maxEndDateTime.month &&
        _endDate!.day == maxEndDateTime.day &&
        hourToUse == maxEndDateTime.hour) {
      final maxMinute = maxEndDateTime.minute;
      final filtered = _kFiveMinuteSteps.where((m) => m <= maxMinute).toList();
      return filtered.isEmpty ? [0] : filtered;
    }

    return List<int>.from(_kFiveMinuteSteps);
  }

  /// Prüft Endzeit > Startzeit; falls nicht, setzt Endzeit auf Startzeit + 1 Stunde.
  void _validateAndCorrectEndTime() {
    if (_startDate == null ||
        _startHour == null ||
        _startMinute == null ||
        _endDate == null ||
        _endHour == null ||
        _endMinute == null)
      return;
    final start = DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startHour!,
      _startMinute!,
    );
    final end = DateTime(
      _endDate!.year,
      _endDate!.month,
      _endDate!.day,
      _endHour!,
      _endMinute!,
    );
    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      final corrected = start.add(const Duration(hours: 1));
      setState(() {
        _endDate = DateTime(corrected.year, corrected.month, corrected.day);
        _endHour = corrected.hour;
        _endMinute = corrected.minute;
      });
    }
  }

  // Legacy-Methoden für Kompatibilität (werden aus den neuen Werten berechnet)
  TimeOfDay? get _startTime {
    if (_startHour == null || _startMinute == null) return null;
    return TimeOfDay(hour: _startHour!, minute: _startMinute!);
  }

  TimeOfDay? get _endTime {
    if (_endHour == null || _endMinute == null) return null;
    return TimeOfDay(hour: _endHour!, minute: _endMinute!);
  }

  String _formatTime(TimeOfDay? time, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    if (time == null) return localizations.not_selected;

    // Erstelle ein DateTime-Objekt für die Formatierung
    final now = DateTime.now();
    final dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Verwende die zentrale Formatierungsfunktion
    final locale = Localizations.localeOf(context);
    final minute = time.minute.toString().padLeft(2, '0');
    final use12HourFormat = locale.languageCode == 'en';
    final useHInsteadOfColon = locale.languageCode == 'fr';
    final timeSeparator = useHInsteadOfColon ? 'h' : ':';

    if (use12HourFormat) {
      final hour12 = time.hour == 0
          ? 12
          : (time.hour > 12 ? time.hour - 12 : time.hour);
      final amPm = time.hour < 12
          ? localizations.time_am
          : localizations.time_pm;
      return '$hour12$timeSeparator$minute $amPm';
    } else {
      final hour = time.hour.toString().padLeft(2, '0');
      final clock = localizations.party_time_clock;
      if (useHInsteadOfColon) {
        return '$hour$timeSeparator$minute';
      } else {
        return '$hour$timeSeparator$minute $clock';
      }
    }
  }

  // Helper-Methoden für die einzelnen Sektionen der build-Methode
  Widget _buildEventTypeSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.event_type_label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        RadioGroup<String>(
          groupValue: _partyType,
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _partyType = value);
            }
          },
          child: Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: Text(
                    l10n.party_type_private,
                  ),
                  value: 'private',
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: Text(
                    l10n.party_type_public,
                  ),
                  value: 'public',
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPartyNameSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      controller: _partyNameController,
      maxLength: 100,
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[<>]'))],
      decoration: InputDecoration(
        labelText: l10n.party_name_label_new,
        hintText: l10n.party_name_hint,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return l10n.party_name_required;
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      body: Material(
        type: MaterialType.transparency,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3)),
            child: PwaWidgetCell(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header mit Titel und Schließen-Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.new_party_title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Scrollbarer Inhalt
                  Flexible(
                    child: ScrollIndicatorOverlay(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 8),
                              // Art der Veranstaltung
                              _buildEventTypeSection(context),
                              const SizedBox(height: 16),
                              // Party-Name
                              _buildPartyNameSection(context),
                              const SizedBox(height: 16),
                              // Standort & Zeitzone
                              _buildLocationSection(context),
                              const SizedBox(height: 16),
                              // Beginn
                              _buildStartTimeSection(context, isRtl),
                              const SizedBox(height: 16),
                              // Ende
                              _buildEndTimeSection(context, isRtl),
                              const SizedBox(height: 24),
                              // Wunsch-Limits
                              _buildWishLimitsSection(context),
                              const SizedBox(height: 24),
                              // Speichern-Button
                              _buildSaveButton(context),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper-Methoden für die einzelnen Sektionen
  Widget _buildLocationSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.party_location_timezone_title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        // Button für gespeicherte Locations (bei beiden Party-Typen)
        if (_locations.isNotEmpty) ...[
          ElevatedButton.icon(
            onPressed: () => _showLocationSelectionDialog(context),
            icon: const Icon(Icons.location_on, color: Colors.white),
            label: Text(l10n.party_from_saved_locations),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              side: const BorderSide(color: UIConstants.appOrange, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Radiobuttons für Standort-Auswahl
        RadioGroup<String>(
          groupValue: _locationSelectionMode,
          onChanged: (String? value) {
            if (value == null) return;
            setState(() {
              _locationSelectionMode = value;
              _selectedLocationId = null;
              _selectedLocationModel = null;
              locationId = null;
              if (value == 'current') {
                _selectedGooglePlace = null;
                _locationNameController.clear();
                _updateSystemTimezone();
                _wasMapAdjusted = false;
              } else if (value == 'search') {
                _saveLocationForFutureParties = false;
                _useFixedPartyCodeForLocation = false;
                _useOneTimeEventCode = false;
              }
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_partyType == 'private')
                RadioListTile<String>(
                  title: Text(
                    l10n.party_use_current_timezone_radio,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${l10n.party_timezone_prefix} ${_currentTimezoneId ?? l10n.party_timezone_pending}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  value: 'current',
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: UIConstants.appOrange,
                ),
              RadioListTile<String>(
                title: Text(
                  _partyType == 'public'
                      ? l10n.party_search_place
                      : l10n.party_search_other_place,
                  style: const TextStyle(color: Colors.white),
                ),
                value: 'search',
                contentPadding: EdgeInsets.zero,
                dense: true,
                activeColor: UIConstants.appOrange,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Hybrid-Suche: PlacesAutocompleteField + Karten-Button
        if (_locationSelectionMode == 'search') ...[
          Row(
            children: [
              Expanded(
                child: PlacesAutocompleteField(
                  initialValue:
                      _selectedGooglePlace?.name ??
                      _locationNameController.text,
                  validator: (value) => null,
                  onPlaceSelected: (LocationResult? result) async {
                    if (result == null) {
                      setState(() {
                        _locationNameController.clear();
                        _updateSystemTimezone();
                        _saveLocationForFutureParties = false;
                        _useFixedPartyCodeForLocation = false;
                        _useOneTimeEventCode = false;
                        _wasMapAdjusted = false;
                      });
                      return;
                    }
                    // Suche → Karte öffnen (Startpunkt = gewählter Ort, kein Berlin-Fallback)
                    final refined = await Navigator.push<LocationResult?>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationMapPickerPage(
                          initialLatitude: result.latitude,
                          initialLongitude: result.longitude,
                          initialLocationName: result.name,
                        ),
                      ),
                    );
                    if (refined != null && mounted) {
                      setState(() {
                        _selectedGooglePlace = refined;
                        // Namen-Reset: Nur expliziten POI-Namen übernehmen (z.B. Hotel, Club), nicht wenn Name = Adresse/Straße/Ort
                        final isExplicitName = _isExplicitLocationName(
                          refined.name,
                          refined.address,
                          refined.street,
                          refined.city,
                        );
                        _locationNameController.text = isExplicitName
                            ? refined.name
                            : '';
                        _currentTimezoneId = refined.timezoneId;
                        _saveLocationForFutureParties = false;
                        _useFixedPartyCodeForLocation = false;
                        _useOneTimeEventCode = false;
                        _wasMapAdjusted = true;
                      });
                      if (refined.timezoneId == null) {
                        GooglePlacesService.getTimezoneIdForCoordinates(
                          refined.latitude,
                          refined.longitude,
                        ).then((timezoneId) {
                          if (mounted && timezoneId != null) {
                            setState(() => _currentTimezoneId = timezoneId);
                          }
                        });
                      }
                    } else if (mounted) {
                      // Abbruch: Suchbegriff im Feld lassen
                      setState(
                        () => _locationNameController.text = result.name,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: UIConstants.appOrange, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.map, color: UIConstants.appOrange),
                  tooltip: l10n.party_pick_on_map_tooltip,
                  onPressed: () async {
                    final result = await Navigator.push<LocationResult?>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationMapPickerPage(
                          initialLatitude: _selectedGooglePlace?.latitude,
                          initialLongitude: _selectedGooglePlace?.longitude,
                          initialLocationName: _selectedGooglePlace?.name,
                        ),
                      ),
                    );

                    if (result != null && mounted) {
                      setState(() {
                        _selectedGooglePlace = result;
                        // Namen-Reset: Nur expliziten POI-Namen übernehmen, sonst leeren
                        final isExplicitName = _isExplicitLocationName(
                          result.name,
                          result.address,
                          result.street,
                          result.city,
                        );
                        _locationNameController.text = isExplicitName
                            ? result.name
                            : '';
                        _currentTimezoneId = result.timezoneId;
                        _saveLocationForFutureParties = false;
                        _useFixedPartyCodeForLocation = false;
                        _useOneTimeEventCode = false;
                        _wasMapAdjusted = true;
                        debugLog(
                          '✅ Position von Karte ausgewählt: ${result.latitude}, ${result.longitude}',
                        );
                        debugLog(
                          '   Zeitzone: ${result.timezoneId ?? l10n.party_timezone_loading_short}',
                        );
                        if (result.timezoneId == null) {
                          debugLog('   ⚠️ Zeitzone wird nachgeladen...');
                          GooglePlacesService.getTimezoneIdForCoordinates(
                            result.latitude,
                            result.longitude,
                          ).then((timezoneId) {
                            if (mounted && timezoneId != null) {
                              setState(() {
                                _currentTimezoneId = timezoneId;
                                debugLog('   ✅ Zeitzone nachgeladen: $timezoneId');
                              });
                            }
                          });
                        }
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          // Zeige ausgewählten Google Place an
          if (_selectedGooglePlace != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: UIConstants.appOrange, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Builder(
                          builder: (context) {
                            final p = _selectedGooglePlace!;
                            final addr = p.address.trim();
                            final coords =
                                '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';
                            final hasRealAddress =
                                addr.isNotEmpty &&
                                (addr.contains(',') || addr.length >= 30);
                            final displayAddr = hasRealAddress
                                ? addr
                                : addr.isNotEmpty
                                ? '$addr · $coords'
                                : coords;
                            return Text(
                              displayAddr,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              softWrap: true,
                              textAlign: TextAlign.left,
                            );
                          },
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _selectedGooglePlace = null;
                          _locationNameController.clear();
                          _updateSystemTimezone();
                          _saveLocationForFutureParties = false;
                          _useFixedPartyCodeForLocation = false;
                          _useOneTimeEventCode = false;
                          _wasMapAdjusted = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          // Checkboxen für Location-Speicherung
          if (_selectedGooglePlace != null &&
              _partyType == 'public' &&
              _locationSelectionMode == 'search' &&
              _selectedLocationModel == null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                border: Border.all(color: UIConstants.appOrange, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    title: Text(
                      l10n.party_save_location_future,
                      style: const TextStyle(color: Colors.white),
                    ),
                    value: _saveLocationForFutureParties,
                    activeColor: UIConstants.appOrange,
                    checkColor: Colors.white,
                    onChanged: (value) {
                      setState(() {
                        _saveLocationForFutureParties = value ?? false;
                        if (!_saveLocationForFutureParties) {
                          _useFixedPartyCodeForLocation = false;
                        }
                      });
                    },
                  ),
                  if (_saveLocationForFutureParties)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 48.0),
                      child: CheckboxListTile(
                        title: Text(
                          l10n.party_fixed_code_same_venue,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        value: _useFixedPartyCodeForLocation,
                        activeColor: UIConstants.appOrange,
                        checkColor: Colors.white,
                        onChanged: (value) {
                          setState(() {
                            _useFixedPartyCodeForLocation = value ?? false;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
        // Zeige ausgewählte Location aus Dialog an
        if (_locationSelectionMode == 'dropdown' &&
            _selectedLocationModel != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                border: Border.all(color: UIConstants.appOrange, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedLocationModel!.locationName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedLocationModel!.address != null &&
                            _selectedLocationModel!.address!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _selectedLocationModel!.address!,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.party_timezone_prefix} ${_selectedLocationModel!.timezoneId}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                        if (_selectedLocationModel!.fixedPartyCode != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _useOneTimeEventCode
                                ? l10n.party_code_on_save
                                : l10n.party_fixed_code_display(
                                    _selectedLocationModel!.fixedPartyCode!,
                                  ),
                            style: const TextStyle(
                              color: UIConstants.appOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _selectedLocationId = null;
                        _selectedLocationModel = null;
                        _locationSelectionMode = _partyType == 'public'
                            ? 'search'
                            : 'current';
                        locationId = null;
                        _useOneTimeEventCode = false;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          // Code-Option für öffentliche Partys mit festem Code
          if (_partyType == 'public' &&
              _selectedLocationModel!.fixedPartyCode != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                border: Border.all(color: UIConstants.appOrange, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SwitchListTile(
                title: Text(
                  l10n.party_one_time_event_code,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _useOneTimeEventCode
                      ? l10n.party_one_time_code_range_hint
                      : l10n.party_fixed_code_in_use_hint(
                          _selectedLocationModel!.fixedPartyCode!,
                        ),
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                value: _useOneTimeEventCode,
                activeThumbColor: UIConstants.appOrange,
                onChanged: (value) {
                  setState(() {
                    _useOneTimeEventCode = value;
                  });
                },
              ),
            ),
          ],
        ],
        // Hinweistext
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            l10n.party_timezone_auto_explanation,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartTimeSection(BuildContext context, bool isRtl) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.start_label_new,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.party_date_label,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: _selectStartDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatDate(_startDate, context),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Transform.flip(
                              flipX: isRtl,
                              child: const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                key: _startTimePickerKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.party_time_label,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeDropdown<int>(
                          value: _startHour,
                          items: _getAvailableStartHours(),
                          label: l10n.select_hour,
                          enabled: _startDate != null,
                          itemLabel: (h) => '$h',
                          onChanged: (h) {
                            if (h == null) return;
                            setState(() {
                              _startHour = h;
                              final mins = _getAvailableStartMinutes(h);
                              _startMinute = mins.contains(_startMinute)
                                  ? _startMinute
                                  : (mins.isNotEmpty ? mins.first : null);
                              _endDate = null;
                              _endHour = null;
                              _endMinute = null;
                            });
                            _validatePartyTimes();
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildTimeDropdown<int>(
                          value: _startMinute,
                          items: _getAvailableStartMinutes(),
                          label: l10n.select_minute,
                          enabled: _startDate != null && _startHour != null,
                          itemLabel: (m) => m.toString().padLeft(2, '0'),
                          onChanged: (m) {
                            if (m == null) return;
                            setState(() {
                              _startMinute = m;
                              _endDate = null;
                              _endHour = null;
                              _endMinute = null;
                            });
                            _validatePartyTimes();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Dropdown für Stunde oder Minute (Schwarz/Orange)
  Widget _buildTimeDropdown<T>({
    required T? value,
    required List<T> items,
    required String label,
    required bool enabled,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = max(11.0, min(15.0, constraints.maxWidth * 0.38));
        final padH = max(4.0, min(10.0, constraints.maxWidth * 0.1));
        final textStyle = TextStyle(color: Colors.white, fontSize: fontSize);
        return Container(
          constraints: BoxConstraints(
            minWidth: max(48.0, min(120.0, fontSize * 3.2)),
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            border: Border.all(
              color: enabled ? UIConstants.appOrange : Colors.grey.shade700,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: 4),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: items.contains(value) ? value : null,
              isExpanded: true,
              isDense: true,
              dropdownColor: const Color(0xFF1F2937),
              icon: Icon(
                Icons.arrow_drop_down,
                size: max(20.0, fontSize * 1.25),
                color: enabled ? UIConstants.appOrange : Colors.grey.shade600,
              ),
              hint: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: max(10.0, fontSize - 1),
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              selectedItemBuilder: items.isEmpty
                  ? null
                  : (ctx) => items
                      .map(
                        (e) => Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(itemLabel(e), style: textStyle),
                          ),
                        ),
                      )
                      .toList(),
              items: items
                  .map(
                    (e) => DropdownMenuItem<T>(
                      value: e,
                      child: Text(itemLabel(e), style: textStyle),
                    ),
                  )
                  .toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEndTimeSection(BuildContext context, bool isRtl) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.end_label_new,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.party_date_label,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap:
                          (_startDate != null &&
                              _startHour != null &&
                              _startMinute != null)
                          ? _selectEndDate
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                (_startDate != null &&
                                    _startHour != null &&
                                    _startMinute != null)
                                ? Colors.grey
                                : Colors.grey.shade600,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color:
                                  (_startDate != null &&
                                      _startHour != null &&
                                      _startMinute != null)
                                  ? null
                                  : Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatDate(_endDate, context),
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      (_startDate != null &&
                                          _startHour != null &&
                                          _startMinute != null)
                                      ? null
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Transform.flip(
                              flipX: isRtl,
                              child: Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color:
                                    (_startDate != null &&
                                        _startHour != null &&
                                        _startMinute != null)
                                    ? null
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.party_time_label,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeDropdown<int>(
                          value: _endHour,
                          items: _getAvailableEndHours(),
                          label: l10n.select_hour,
                          enabled: _endDate != null,
                          itemLabel: (h) => '$h',
                          onChanged: (h) {
                            if (h == null) return;
                            setState(() {
                              _endHour = h;
                              final mins = _getAvailableEndMinutes(h);
                              _endMinute = mins.contains(_endMinute)
                                  ? _endMinute
                                  : (mins.isNotEmpty ? mins.first : null);
                            });
                            _validateAndCorrectEndTime();
                            _validatePartyTimes();
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildTimeDropdown<int>(
                          value: _endMinute,
                          items: _getAvailableEndMinutes(),
                          label: l10n.select_minute,
                          enabled: _endDate != null && _endHour != null,
                          itemLabel: (m) => m.toString().padLeft(2, '0'),
                          onChanged: (m) {
                            if (m == null) return;
                            setState(() => _endMinute = m);
                            _validateAndCorrectEndTime();
                            _validatePartyTimes();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        // Validierungsfehlermeldung unter End-Zeitfeldern
        if (_validationError != null) ...[
          const SizedBox(height: 8),
          Text(
            _validationError!,
            style: const TextStyle(fontSize: 12, color: UIConstants.appOrange),
          ),
        ],
      ],
    );
  }

    Widget _buildWishLimitsSection(BuildContext context) {
    final user = UserService().currentUser.value;
    final isFree = user != null && user.isFree;
    final effectiveGuestLimit = isFree ? 1 : _selectedGuestLimit;
    final effectiveUserLimit = isFree ? 1 : _selectedUserLimit;
    final loc = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          loc.party_wish_limits,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey<int>(effectiveGuestLimit ?? 1),
                initialValue: effectiveGuestLimit ?? 1,
                decoration: InputDecoration(
                  labelText: loc.party_guest_limit,
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.person_outline,
                    color: isFree ? Colors.grey : null,
                  ),
                  filled: isFree,
                  fillColor: isFree ? Colors.grey.shade800 : null,
                ),
                items: _guestLimitOptions.map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: isFree
                    ? null
                    : (int? newValue) {
                        setState(() {
                          _selectedGuestLimit = newValue;
                        });
                      },
                validator: (value) {
                  if (value == null) {
                    return loc.validation_limit_required;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey<int>(effectiveUserLimit ?? 1),
                initialValue: effectiveUserLimit ?? 1,
                decoration: InputDecoration(
                  labelText: loc.party_user_limit,
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.person,
                    color: isFree ? Colors.grey : null,
                  ),
                  filled: isFree,
                  fillColor: isFree ? Colors.grey.shade800 : null,
                ),
                items: _userLimitOptions.map((int value) {
                  return DropdownMenuItem<int>(
                    value: value,
                    child: Text(value.toString()),
                  );
                }).toList(),
                onChanged: isFree
                    ? null
                    : (int? newValue) {
                        setState(() {
                          _selectedUserLimit = newValue;
                        });
                      },
                validator: (value) {
                  if (value == null) {
                    return loc.validation_limit_required;
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        if (isFree) ...[
          const SizedBox(height: 6),
          Text(
            loc.free_limit_info,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      ],
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    final isValid = _isFormValid;
    return ElevatedButton(
      onPressed: (_isLoading || !isValid) ? null : _saveParty,
      style: ElevatedButton.styleFrom(
        backgroundColor: UIConstants.appOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        disabledBackgroundColor: Colors.grey.shade800,
        disabledForegroundColor: Colors.grey.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: _isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.party_saving_progress,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            )
          : Text(
              AppLocalizations.of(context)!.save_party_data,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
