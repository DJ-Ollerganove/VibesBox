import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'l10n/app_localizations.dart';
import 'utils/formatting_utils.dart';
import 'utils/ui_constants.dart';
import 'utils/party_validator.dart';
import 'config/app_config.dart';
import 'config/apple_review_test_dj.dart';
import 'services/user_service.dart';
import 'helpers/security_helper.dart';
import 'models/location_result.dart';
import 'pages/location_edit_picker_page.dart';
import 'widgets/party_creation/party_time_dropdowns.dart';
import 'utils/pre_wish_helper.dart';
import 'services/pre_wish_limit_service.dart';
import 'widgets/party_pre_wish_settings_field.dart';
import 'widgets/vibesbox_info_dialog.dart';
import 'utils/debug_log.dart';
import 'constants/venue_constants.dart';
import 'models/location_model.dart';
import 'models/venue_model.dart';
import 'models/floor_occupancy_info.dart';
import 'models/venue_overlap_party_info.dart';
import 'services/public_location_service.dart';
import 'services/venue_service.dart';
import 'services/venue_party_conflict_service.dart';
import 'utils/floor_key_utils.dart';
import 'utils/venue_party_fields.dart';
import 'utils/party_ownership_helper.dart';
import 'utils/party_location_export_helper.dart';
import 'widgets/party_creation/party_wizard_step_kind.dart';
import 'widgets/party_creation/party_floor_name_dialog.dart';
import 'widgets/party_creation/public_venue_floor_field.dart';
import 'widgets/floor_swap_dialogs.dart';
import 'app_scaffold_messenger.dart';
import 'services/app_diagnostic_log_service.dart';
import 'services/party_secure_service.dart';

enum _EditPublicFloorChoice { noFloor, selectFloor }

/// Dialog für die Bearbeitung einer Party
class SettingsPartyEditDialog {
  static void _showRegisteredAppGuestInfo(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showVibesBoxInfoDialog(
      context,
      title: l.party_registered_app_guest_info_title,
      body: l.party_registered_app_guest_info_body,
    );
  }

  static Future<bool?> _showEditVenueOverlapDialog(
    BuildContext context,
    List<VenueOverlapPartyInfo> parties,
  ) async {
    if (!context.mounted || parties.isEmpty) return null;
    final l = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: UIConstants.djShellPageBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: UIConstants.appOrange, width: 2),
        ),
        title: Text(
          l.party_venue_overlap_dialog_title,
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l.party_venue_overlap_dialog_intro,
                style: TextStyle(color: Colors.grey.shade300),
              ),
              const SizedBox(height: 12),
              ...parties.map((p) {
                final startStr =
                    DateFormat.yMMMd(locale).add_Hm().format(p.start);
                final endStr = DateFormat.Hm(locale).format(p.end);
                final dj = p.djDisplayName?.trim().isNotEmpty == true
                    ? p.djDisplayName!.trim()
                    : l.party_dj_fallback;
                final partyLabel = p.partyName.trim().isNotEmpty
                    ? p.partyName.trim()
                    : l.unnamed_party;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    l.party_venue_overlap_party_line(
                      partyLabel,
                      dj,
                      startStr,
                      endStr,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              Text(
                l.party_venue_overlap_join_floor_question,
                style: TextStyle(color: Colors.grey.shade300),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.no),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: UIConstants.appOrange,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.yes),
          ),
        ],
      ),
    );
  }

  static Widget _buildMatchedPublicLocationBanner(
    BuildContext context,
    LocationModel loc,
  ) {
    final l = AppLocalizations.of(context)!;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwn = currentUid != null && loc.createdBy == currentUid;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          border: Border.all(color: UIConstants.appOrange, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, color: UIConstants.appOrange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOwn
                        ? l.party_public_location_matched_own_title
                        : l.party_public_location_matched_title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              loc.locationName,
              style: const TextStyle(color: Colors.white),
            ),
            if (loc.fixedPartyCode != null) ...[
              const SizedBox(height: 4),
              Text(
                l.party_fixed_code_display(loc.fixedPartyCode!),
                style: const TextStyle(
                  color: UIConstants.appOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            if (!isOwn) ...[
              const SizedBox(height: 4),
              Text(
                l.party_public_location_matched_body,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Zeigt den Bearbeitungs-Dialog für eine Party
  ///
  /// [allParties] - Optional: Liste aller Partys des DJs für Überschneidungs-Check
  ///                Falls null, wird die Liste automatisch aus Firestore geladen
  static Future<void> show(
    BuildContext context,
    String partyId,
    String currentPartyName,
    DateTime currentStartDate,
    DateTime currentEndDate,
    String? currentPartyType,
    String Function(DateTime date, BuildContext? context) formatDateTime, {
    int? currentGuestLimit,
    int? currentUserLimit,
    List<QueryDocumentSnapshot>?
    allParties, // Vorbereitung für Überschneidungs-Check
  }) async {
    final l10n = AppLocalizations.of(context)!;
    // Lade Party-Daten für Zeitzonen-Informationen, Limits und Location
    String? partyTimezoneId;
    double? partyLatitude;
    double? partyLongitude;
    String? partyLocationName;
    String? partyLocationAddress;
    String? partyLocationZip;
    String? partyLocationCity;
    String? partyLocationStreet;
    DocumentSnapshot? partyDoc;

    String? editPartyCode;
    try {
      partyDoc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .get();

      if (partyDoc.exists) {
        final data = partyDoc.data() as Map<String, dynamic>?;
        editPartyCode = data?['party_code'] as String?;
        // Prüfe verschiedene Feldnamen für timezone_id
        dynamic timezoneIdRaw =
            data?['timezone_id'] ??
            data?['timezoneId'] ??
            data?['time_zone_id'] ??
            data?['timezone'];

        if (timezoneIdRaw != null && timezoneIdRaw is String) {
          final cleaned = timezoneIdRaw.trim();
          if (cleaned.isNotEmpty && cleaned.toLowerCase() != 'null') {
            partyTimezoneId = cleaned;
          }
        }

        partyLatitude = (data?['latitude'] as num?)?.toDouble();
        partyLongitude = (data?['longitude'] as num?)?.toDouble();
        partyLocationName = data?['location_name'] as String?;
        partyLocationAddress = data?['location_address'] as String?;
        partyLocationZip = (data?['location_zip'] as String?)?.trim();
        partyLocationCity = (data?['location_city'] as String?)?.trim();
        partyLocationStreet = (data?['location_street'] as String?)?.trim();

        debugLog('📋 Party-Daten geladen für Edit-Dialog:');
        debugLog('   timezone_id: $partyTimezoneId');
        debugLog('   latitude: $partyLatitude');
        debugLog('   longitude: $partyLongitude');
        debugLog('   location_name: $partyLocationName');
      }
    } catch (e) {
      debugLog('⚠️ Fehler beim Laden der Party-Daten: $e');
    }

    // DYNAMISCHE ZEITZONEN-PRIORISIERUNG:
    // A: Wenn Location/Latitude/Longitude vorhanden → nutze die ermittelte timezoneId
    // B: Wenn keine Location → nutze zwingend die aktuelle Zeitzone des DJ-Geräts als Fallback
    if (partyTimezoneId == null || partyTimezoneId.isEmpty) {
      // Prüfe ob Location vorhanden ist
      if (partyLatitude != null &&
          partyLongitude != null &&
          partyLatitude != 0.0 &&
          partyLongitude != 0.0) {
        // Location vorhanden, aber keine timezoneId → sollte nicht passieren, aber Fallback
        debugLog(
          '⚠️ Location vorhanden, aber keine timezone_id - versuche Geräte-Zeitzone',
        );
        partyTimezoneId = _getDeviceTimezoneId();
      } else {
        // KEINE Location → nutze zwingend Geräte-Zeitzone
        partyTimezoneId = _getDeviceTimezoneId();
        debugLog(
          '✅ Keine Location gewählt - nutze Geräte-Zeitzone: $partyTimezoneId',
        );
      }
    }

    // Wenn Limits nicht übergeben wurden, lade sie aus Firestore (nutze bereits geladenes Dokument)
    int? guestLimit = currentGuestLimit;
    int? userLimit = currentUserLimit;
    bool allowPreWishes = false;
    bool initialAllowPreWishes = false;
    int preWishLimitPerGuest = 0;

    if (guestLimit == null || userLimit == null) {
      try {
        // Nutze bereits geladenes Party-Dokument (falls vorhanden)
        if (partyDoc != null && partyDoc.exists) {
          final data = partyDoc.data() as Map<String, dynamic>?;
          guestLimit = data?['guest_limit_per_hour'] as int? ?? 2;
          userLimit = data?['user_limit_per_hour'] as int? ?? 5;
          allowPreWishes = data?['allow_pre_wishes'] == true;
          initialAllowPreWishes = allowPreWishes;
          preWishLimitPerGuest =
              PreWishLimitService.parseLimitFromParty(data);
        } else {
          guestLimit = guestLimit ?? 2;
          userLimit = userLimit ?? 5;
        }
      } catch (e) {
        debugLog('Fehler beim Laden der Limits: $e');
        guestLimit = guestLimit ?? 2;
        userLimit = userLimit ?? 5;
      }
    }
    if (partyDoc != null && partyDoc.exists) {
      final data = partyDoc.data() as Map<String, dynamic>?;
      allowPreWishes = data?['allow_pre_wishes'] == true;
      initialAllowPreWishes = allowPreWishes;
      preWishLimitPerGuest = PreWishLimitService.parseLimitFromParty(data);
    }

    String? editVenueId;
    var initialEditFloorKey = VenueConstants.defaultFloorKey;
    VenueModel? editVenueModel;
    var editOccupiedFloorKeys = <String>{};
    var editFloorOccupancy = <String, FloorOccupancyInfo>{};
    final effectivePartyType = currentPartyType ?? 'private';
    if (partyDoc != null && partyDoc.exists) {
      final data = partyDoc.data() as Map<String, dynamic>? ?? {};
      editVenueId = VenuePartyFields.readVenueId(data);
      initialEditFloorKey = VenuePartyFields.effectiveFloorKeyFromParty(data);
    }
    if (effectivePartyType == 'public' &&
        editVenueId != null &&
        editVenueId.isNotEmpty) {
      try {
        editVenueModel = await VenueService().getVenueById(editVenueId);
        editOccupiedFloorKeys =
            await VenuePartyConflictService().occupiedFloorKeys(
          venueId: editVenueId,
          start: currentStartDate,
          end: currentEndDate,
          excludePartyId: partyId,
        );
        editFloorOccupancy =
            await VenuePartyConflictService().occupancyByFloorKey(
          venueId: editVenueId,
          start: currentStartDate,
          end: currentEndDate,
          excludePartyId: partyId,
        );
      } catch (e) {
        debugLog('⚠️ Venue/Floor für Bearbeiten: $e');
      }
    }
    String? editSelectedFloorKey =
        FloorKeyUtils.isDefaultFloorKey(initialEditFloorKey)
            ? null
            : initialEditFloorKey;
    var editPublicFloorChoice =
        FloorKeyUtils.isDefaultFloorKey(initialEditFloorKey)
            ? _EditPublicFloorChoice.noFloor
            : _EditPublicFloorChoice.selectFloor;
    var editVenueContextLoading = false;
    var editWizardStep = 0;
    var editIsSaving = false;
    LocationModel? editMatchedPublicLocation;
    List<VenueOverlapPartyInfo> editOverlappingParties = [];
    bool? editVenueOverlapJoinAccepted;
    String? editOverlapPromptKey;
    final publicLocationService = PublicLocationService();

    // Free-DJ: Limits fest auf 1 — Apple-Review-Test-DJ: wie Pro wählbar
    final editUser = UserService().currentUser.value;
    final isFreeEdit = editUser != null &&
        editUser.isFree &&
        !AppleReviewTestDj.usesProStyleWishLimits(editUser);
    if (isFreeEdit) {
      guestLimit = 1;
      userLimit = 1;
    }

    final partyNameController = TextEditingController(text: currentPartyName);
    int? selectedGuestLimit = guestLimit;
    int? selectedUserLimit = userLimit;
    DateTime? startDate = currentStartDate;
    int? startHour = currentStartDate.hour;
    int? startMinute =
        PartyTimeHelpers.kFiveMinuteSteps.contains(currentStartDate.minute)
        ? currentStartDate.minute
        : PartyTimeHelpers.roundToNext5Minutes(currentStartDate.minute);
    DateTime? endDate = currentEndDate;
    int? endHour = currentEndDate.hour;
    int? endMinute =
        PartyTimeHelpers.kFiveMinuteSteps.contains(currentEndDate.minute)
        ? currentEndDate.minute
        : PartyTimeHelpers.roundToNext5Minutes(currentEndDate.minute);
    String? partyType = currentPartyType ?? 'private';
    final hasNotStarted = PartyValidator.hasNotStarted(currentStartDate);
    final isPartyRunning = PartyValidator.isPartyRunning(
      currentStartDate,
      currentEndDate,
    );

    if (isPartyRunning) {
      final minEnd = PartyTimeHelpers.computeMinEndDateTime(
        currentStartDate,
        enforceNotInPast: true,
      );
      final initialEnd = DateTime(
        currentEndDate.year,
        currentEndDate.month,
        currentEndDate.day,
        endHour!,
        endMinute!,
      );
      if (initialEnd.isBefore(minEnd)) {
        endDate = DateTime(minEnd.year, minEnd.month, minEnd.day);
        endHour = minEnd.hour;
        endMinute = minEnd.minute;
      }
    }

    // Bearbeitbare Location- und Zeitzonen-Daten (können per "Ort ändern" aktualisiert werden)
    final rawLocName = partyLocationName?.trim();
    final locNameExplicit = rawLocName != null &&
        rawLocName.isNotEmpty &&
        rawLocName != l10n.location_not_specified &&
        PartyLocationExportHelper.isExplicitLocationName(
          rawLocName,
          street: partyLocationStreet,
          city: partyLocationCity,
          address: partyLocationAddress,
        );
    String editLocationName = locNameExplicit ? rawLocName! : '';
    String editLocationAddress = partyLocationAddress?.trim() ?? '';
    String? editLocationZip = partyLocationZip?.isNotEmpty == true
        ? partyLocationZip
        : null;
    String? editLocationCity = partyLocationCity?.isNotEmpty == true
        ? partyLocationCity
        : null;
    String? editLocationStreet = partyLocationStreet?.isNotEmpty == true
        ? partyLocationStreet
        : null;
    double? editLatitude = partyLatitude;
    double? editLongitude = partyLongitude;
    String editTimezoneId = partyTimezoneId ?? 'UTC';

    // Erstelle Listen für Dropdown-Optionen
    final List<int> guestLimitOptions = List.generate(
      11,
      (index) => index,
    ); // 0-10
    final List<int> userLimitOptions = List.generate(
      26,
      (index) => index,
    ); // 0-25

    // Lade allParties aus Firestore, falls null
    List<QueryDocumentSnapshot>? partiesList = allParties;
    if (partiesList == null) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final partiesSnapshot = await FirebaseFirestore.instance
              .collection('parties')
              .where('created_by', isEqualTo: user.uid)
              .get();
          partiesList = partiesSnapshot.docs;
        } else {
          partiesList = [];
        }
      } catch (e) {
        debugLog('⚠️ Fehler beim Laden der Partys für Überschneidungs-Check: $e');
        partiesList = [];
      }
    }

    final editScrollController = ScrollController();
    try {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          final isRtl = [
            'ar',
            'he',
            'fa',
            'ur',
          ].contains(Localizations.localeOf(context).languageCode);
          return StatefulBuilder(
            builder: (context, setDialogState) {
              // Ermittle Admin-Status (Firestore-Rolle)
              final user = FirebaseAuth.instance.currentUser;
              final isAdmin = AppConfig.isAdminRole(
                UserService().currentUser.value,
              );
              final isPro = UserService().currentUser.value?.isPro == true;
              final allowExtendedDuration =
                  AppleReviewTestDj.matchesUser(UserService().currentUser.value);
              final partyMaxDuration = PartyValidator.maxDurationFor(
                isAdmin: isAdmin,
                isPro: isPro,
                allowExtendedDuration: allowExtendedDuration,
              );

              // Validierung: Endzeit > Startzeit (Korrektur in setDialogState)
              void correctEndTimeIfNeeded() {
                if (endDate == null || endHour == null || endMinute == null) {
                  return;
                }

                final effectiveStartDate = isPartyRunning
                    ? DateTime(
                        currentStartDate.year,
                        currentStartDate.month,
                        currentStartDate.day,
                      )
                    : startDate;
                final effectiveStartHour =
                    isPartyRunning ? currentStartDate.hour : startHour;
                final effectiveStartMinute =
                    isPartyRunning ? currentStartDate.minute : startMinute;

                if (effectiveStartDate == null ||
                    effectiveStartHour == null ||
                    effectiveStartMinute == null) {
                  return;
                }

                var workingEndDate = endDate!;
                var workingEndHour = endHour!;
                var workingEndMinute = endMinute!;

                if (isPartyRunning) {
                  final minEnd = PartyTimeHelpers.computeMinEndDateTime(
                    DateTime(
                      effectiveStartDate.year,
                      effectiveStartDate.month,
                      effectiveStartDate.day,
                      effectiveStartHour,
                      effectiveStartMinute,
                    ),
                    enforceNotInPast: true,
                  );
                  final correctedMin = PartyTimeHelpers.correctEndIfBeforeMin(
                    workingEndDate,
                    workingEndHour,
                    workingEndMinute,
                    minEnd,
                  );
                  workingEndDate = correctedMin.endDate;
                  workingEndHour = correctedMin.endHour;
                  workingEndMinute = correctedMin.endMinute;
                }

                final corrected = PartyTimeHelpers.correctEndIfBeforeStart(
                  effectiveStartDate,
                  effectiveStartHour,
                  effectiveStartMinute,
                  workingEndDate,
                  workingEndHour,
                  workingEndMinute,
                );
                if (corrected.endDate != endDate ||
                    corrected.endHour != endHour ||
                    corrected.endMinute != endMinute) {
                  setDialogState(() {
                    endDate = corrected.endDate;
                    endHour = corrected.endHour;
                    endMinute = corrected.endMinute;
                  });
                }
              }

              final activeEditSteps =
                  partyWizardStepsForType(partyType ?? 'private');
              final editWizardStepCount = activeEditSteps.length;

              bool editHasCoordinates() {
                final lat = editLatitude;
                final lng = editLongitude;
                return lat != null &&
                    lng != null &&
                    lat != 0.0 &&
                    lng != 0.0;
              }

              DateTime? editPlannedStartDateTime() {
                if (isPartyRunning) return currentStartDate;
                if (startDate == null ||
                    startHour == null ||
                    startMinute == null) {
                  return null;
                }
                return DateTime(
                  startDate!.year,
                  startDate!.month,
                  startDate!.day,
                  startHour!,
                  startMinute!,
                );
              }

              DateTime? editPlannedEndDateTime() {
                if (endDate == null ||
                    endHour == null ||
                    endMinute == null) {
                  return null;
                }
                return DateTime(
                  endDate!.year,
                  endDate!.month,
                  endDate!.day,
                  endHour!,
                  endMinute!,
                );
              }

              bool showEditFloorField() =>
                  partyType == 'public' && editHasCoordinates();

              bool editIsPartyNameStepValid() {
                return partyNameController.text.trim().length >= 3;
              }

              /// Ort beim Bearbeiten optional — „Weiter“ immer erlaubt.
              bool editCanAdvanceFromLocationStep() => true;

              bool editDefaultFloorAvailable() =>
                  !editOccupiedFloorKeys.contains(
                    VenueConstants.defaultFloorKey,
                  );

              bool editPublicLocationFloorStepValid() {
                if (!editHasCoordinates()) {
                  return true;
                }
                if (editVenueContextLoading) return false;
                if (editOverlappingParties.isNotEmpty &&
                    editVenueOverlapJoinAccepted != true) {
                  return false;
                }
                if (editOverlappingParties.isNotEmpty &&
                    editVenueOverlapJoinAccepted == true) {
                  if (editPublicFloorChoice !=
                      _EditPublicFloorChoice.selectFloor) {
                    return false;
                  }
                }
                if (editPublicFloorChoice == _EditPublicFloorChoice.noFloor) {
                  return editDefaultFloorAvailable();
                }
                if (editSelectedFloorKey == null ||
                    editSelectedFloorKey!.isEmpty) {
                  return false;
                }
                if (!editDefaultFloorAvailable() &&
                    FloorKeyUtils.isDefaultFloorKey(editSelectedFloorKey)) {
                  return false;
                }
                if (editOccupiedFloorKeys.contains(editSelectedFloorKey)) {
                  return false;
                }
                return true;
              }

              Future<void> refreshEditVenueContext() async {
                if (partyType != 'public' || !editHasCoordinates()) {
                  setDialogState(() {
                    editVenueId = null;
                    editVenueModel = null;
                    editMatchedPublicLocation = null;
                    editOverlappingParties = [];
                    editOccupiedFloorKeys = {};
                    editFloorOccupancy = {};
                    editVenueOverlapJoinAccepted = null;
                    editOverlapPromptKey = null;
                    editVenueContextLoading = false;
                  });
                  return;
                }
                final start = editPlannedStartDateTime();
                final end = editPlannedEndDateTime();
                if (start == null || end == null) return;

                setDialogState(() => editVenueContextLoading = true);
                try {
                  final publicLocation =
                      await publicLocationService.findMatchingPublicLocation(
                    latitude: editLatitude!,
                    longitude: editLongitude!,
                  );

                  final createdBy =
                      FirebaseAuth.instance.currentUser?.uid ?? '';
                  final rawName = editLocationName.trim();
                  final displayName =
                      rawName.isNotEmpty &&
                              rawName != l10n.location_not_specified
                          ? rawName
                          : l10n.unnamed_location;
                  final venue = await VenueService().resolveOrCreateVenue(
                    name: displayName,
                    address: editLocationAddress.trim().isNotEmpty
                        ? editLocationAddress.trim()
                        : null,
                    latitude: editLatitude!,
                    longitude: editLongitude!,
                    timezoneId: editTimezoneId,
                    createdBy: createdBy,
                  );
                  final occupied =
                      await VenuePartyConflictService().occupiedFloorKeys(
                    venueId: venue.id,
                    start: start,
                    end: end,
                    excludePartyId: partyId,
                  );
                  final occupancy =
                      await VenuePartyConflictService().occupancyByFloorKey(
                    venueId: venue.id,
                    start: start,
                    end: end,
                    excludePartyId: partyId,
                  );
                  final overlappingInfos =
                      await VenuePartyConflictService()
                          .findOverlappingPartyInfos(
                    venueId: venue.id,
                    start: start,
                    end: end,
                    excludePartyId: partyId,
                  );
                  final overlap = overlappingInfos.isNotEmpty;
                  final promptKey =
                      '${venue.id}_${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}';
                  final shouldPromptOverlap =
                      overlap && promptKey != editOverlapPromptKey;

                  if (!context.mounted) return;
                  setDialogState(() {
                    editMatchedPublicLocation = publicLocation;
                    editVenueId = venue.id;
                    editVenueModel = venue;
                    editOccupiedFloorKeys = occupied;
                    editFloorOccupancy = occupancy;
                    editOverlappingParties = overlappingInfos;
                    if (editPublicFloorChoice ==
                        _EditPublicFloorChoice.selectFloor) {
                      if (editSelectedFloorKey == null ||
                          editSelectedFloorKey!.isEmpty) {
                        final firstFree = venue.floors
                            .where(
                              (f) =>
                                  f.key != VenueConstants.defaultFloorKey &&
                                  !occupied.contains(f.key),
                            )
                            .map((f) => f.key)
                            .firstOrNull;
                        editSelectedFloorKey = firstFree;
                      } else if (venue.floorByKey(editSelectedFloorKey!) ==
                              null &&
                          !FloorKeyUtils.isDefaultFloorKey(
                            editSelectedFloorKey!,
                          )) {
                        editSelectedFloorKey = null;
                      }
                    }
                    if (overlap) {
                      if (shouldPromptOverlap) {
                        editVenueOverlapJoinAccepted = null;
                        editOverlapPromptKey = promptKey;
                      }
                    } else {
                      editVenueOverlapJoinAccepted = null;
                      editOverlapPromptKey = null;
                    }
                    editVenueContextLoading = false;
                  });

                  if (shouldPromptOverlap && context.mounted) {
                    final accepted = await _showEditVenueOverlapDialog(
                      context,
                      overlappingInfos,
                    );
                    if (!context.mounted) return;
                    setDialogState(() {
                      editVenueOverlapJoinAccepted = accepted == true;
                    });
                    if (accepted == false && context.mounted) {
                      showVibesSnackBar(context, 
                        SnackBar(
                          content: Text(l10n.party_venue_overlap_decline_hint),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  debugLog('⚠️ Venue-Kontext Bearbeiten: $e');
                  if (context.mounted) {
                    setDialogState(() => editVenueContextLoading = false);
                  }
                }
              }

              String? _validatePartyTimes(
                DateTime? startDt,
                int? startH,
                int? startM,
                DateTime? endDt,
                int? endH,
                int? endM,
                List<QueryDocumentSnapshot>? parties,
                String currentPartyId,
              ) {
                if (startDt == null ||
                    startH == null ||
                    startM == null ||
                    endDt == null ||
                    endH == null ||
                    endM == null) {
                  return null;
                }
                final newStartDateTime = DateTime(
                  startDt.year,
                  startDt.month,
                  startDt.day,
                  startH,
                  startM,
                );
                final newEndDateTime = DateTime(
                  endDt.year,
                  endDt.month,
                  endDt.day,
                  endH,
                  endM,
                );
                if (isPartyRunning) {
                  final minEnd = PartyTimeHelpers.computeMinEndDateTime(
                    currentStartDate,
                    enforceNotInPast: true,
                  );
                  if (newEndDateTime.isBefore(minEnd)) {
                    return AppLocalizations.of(context)!.party_validation_end_in_past;
                  }
                }
                return PartyValidator.validate(
                  newStartDateTime,
                  newEndDateTime,
                  allParties: parties,
                  currentPartyId: currentPartyId,
                  isAdmin: isAdmin,
                  isPro: isPro,
                  allowExtendedDuration: allowExtendedDuration,
                  context: context,
                );
              }

              bool editIsStartStepValid() {
                if (isPartyRunning) return true;
                if (startDate == null ||
                    startHour == null ||
                    startMinute == null) {
                  return false;
                }
                final start = editPlannedStartDateTime();
                if (start == null) return false;
                return !start.isBefore(
                  DateTime.now().add(const Duration(minutes: 5)),
                );
              }

              bool editIsEndStepValid() {
                if (endDate == null ||
                    endHour == null ||
                    endMinute == null) {
                  return false;
                }
                if (!isPartyRunning && !editIsStartStepValid()) {
                  return false;
                }
                return _validatePartyTimes(
                      startDate,
                      startHour,
                      startMinute,
                      endDate,
                      endHour,
                      endMinute,
                      partiesList,
                      partyId,
                    ) ==
                    null;
              }

              bool editIsLimitsStepValid() =>
                  selectedGuestLimit != null && selectedUserLimit != null;

              bool editCanProceedFromStep(int step) {
                if (step < 0 || step >= activeEditSteps.length) return false;
                switch (activeEditSteps[step]) {
                  case PartyWizardStepKind.eventType:
                    return true;
                  case PartyWizardStepKind.partyName:
                    return editIsPartyNameStepValid();
                  case PartyWizardStepKind.location:
                    return editCanAdvanceFromLocationStep();
                  case PartyWizardStepKind.floor:
                    return editPublicLocationFloorStepValid();
                  case PartyWizardStepKind.partyCode:
                    return true;
                  case PartyWizardStepKind.locationWithFloor:
                    return editPublicLocationFloorStepValid();
                  case PartyWizardStepKind.startTime:
                    return editIsStartStepValid();
                  case PartyWizardStepKind.endTime:
                    return editIsEndStepValid();
                  case PartyWizardStepKind.wishLimits:
                    return editIsLimitsStepValid();
                  case PartyWizardStepKind.preWishes:
                    return true;
                }
              }

              void editGoBack() {
                if (editWizardStep <= 0) return;
                setDialogState(() => editWizardStep--);
              }

              void editGoNext() {
                if (!editCanProceedFromStep(editWizardStep)) return;
                if (editWizardStep >= editWizardStepCount - 1) return;
                final next = editWizardStep + 1;
                setDialogState(() => editWizardStep = next);
                if (activeEditSteps[next] == PartyWizardStepKind.floor ||
                    activeEditSteps[next] == PartyWizardStepKind.location ||
                    activeEditSteps[next] ==
                        PartyWizardStepKind.locationWithFloor) {
                  unawaited(refreshEditVenueContext());
                }
              }

              Future<void> editAfterDateTimeChanged() async {
                correctEndTimeIfNeeded();
                if (partyType == 'public' && editHasCoordinates()) {
                  await refreshEditVenueContext();
                }
              }

              final validationError = _validatePartyTimes(
                startDate,
                startHour,
                startMinute,
                endDate,
                endHour,
                endMinute,
                partiesList,
                partyId,
              );
              final effectiveStartForEndLimits = DateTime(
                (isPartyRunning ? currentStartDate : (startDate ?? currentStartDate))
                    .year,
                (isPartyRunning ? currentStartDate : (startDate ?? currentStartDate))
                    .month,
                (isPartyRunning ? currentStartDate : (startDate ?? currentStartDate))
                    .day,
                isPartyRunning
                    ? currentStartDate.hour
                    : (startHour ?? currentStartDate.hour),
                isPartyRunning
                    ? currentStartDate.minute
                    : (startMinute ?? currentStartDate.minute),
              );
              final minEndDateTime = isPartyRunning
                  ? PartyTimeHelpers.computeMinEndDateTime(
                      effectiveStartForEndLimits,
                      enforceNotInPast: true,
                    )
                  : null;
              final currentEditStepKind = activeEditSteps[editWizardStep.clamp(
                0,
                activeEditSteps.length - 1,
              )];
              final isEditLastStep = editWizardStep >= editWizardStepCount - 1;
              final editCanProceed =
                  editCanProceedFromStep(editWizardStep);
              return Directionality(
                textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
                child: Dialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  backgroundColor: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 340),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(
                        color: UIConstants.partyYellow,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.edit_party,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      l10n.party_wizard_step_indicator(
                                        editWizardStep + 1,
                                        editWizardStepCount,
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        // Scrollbarer Inhalt
                        Flexible(
                          child: SingleChildScrollView(
                            controller: editScrollController,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (currentEditStepKind ==
                                      PartyWizardStepKind.partyName) ...[
                                    TextFormField(
                                      controller: partyNameController,
                                      maxLength: 100,
                                      decoration: InputDecoration(
                                        labelText: l10n.party_name_label,
                                        border: const OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  if (currentEditStepKind ==
                                      PartyWizardStepKind.eventType) ...[
                                  // Party-Typ (immer nur informativ, nicht bearbeitbar)
                                  Text(
                                    l10n.party_type_label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    partyType == 'public'
                                        ? l10n.party_type_public
                                        : l10n.party_type_private,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ],
                                  if (currentEditStepKind ==
                                          PartyWizardStepKind.location ||
                                      currentEditStepKind ==
                                          PartyWizardStepKind.floor ||
                                      currentEditStepKind ==
                                          PartyWizardStepKind
                                              .locationWithFloor) ...[
                                  // Location: aktuelle Adresse + "Ort ändern"
                                  Text(
                                    l10n.party_location_label,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade900,
                                      border: Border.all(
                                        color: Colors.grey.shade700,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TextFormField(
                                          initialValue: editLocationName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                          maxLength: 120,
                                          decoration: InputDecoration(
                                            labelText: l10n.location_name_label,
                                            hintText: l10n.location_name_hint,
                                            labelStyle: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 12,
                                            ),
                                            hintStyle: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onChanged: (v) {
                                            editLocationName = v;
                                          },
                                        ),
                                        if (editLocationAddress.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            editLocationAddress,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade400,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        if ((editLocationZip ?? '')
                                                .isNotEmpty ||
                                            (editLocationCity ?? '')
                                                .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            [
                                              if (editLocationZip != null &&
                                                  editLocationZip!.isNotEmpty)
                                                editLocationZip!,
                                              if (editLocationCity != null &&
                                                  editLocationCity!.isNotEmpty)
                                                editLocationCity!,
                                            ].join(' '),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () async {
                                                final result =
                                                    await Navigator.push<
                                                      LocationResult?
                                                    >(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            LocationEditPickerPage(
                                                              initialLatitude:
                                                                  editLatitude,
                                                              initialLongitude:
                                                                  editLongitude,
                                                              initialLocationName:
                                                                  editLocationName
                                                                      .trim()
                                                                      .isNotEmpty
                                                                  ? editLocationName
                                                                  : null,
                                                            ),
                                                      ),
                                                    );
                                                if (result != null &&
                                                    context.mounted) {
                                                  setDialogState(() {
                                                    final n = result.name.trim();
                                                    final isExplicit =
                                                        PartyLocationExportHelper
                                                            .isExplicitLocationName(
                                                      n.isEmpty ? null : n,
                                                      street: result.street,
                                                      city: result.city,
                                                      address: result.address,
                                                    );
                                                    editLocationName = isExplicit
                                                        ? result.name
                                                        : editLocationName;
                                                    editLocationAddress =
                                                        result.address;
                                                    editLocationZip =
                                                        result.postalCode;
                                                    editLocationCity =
                                                        result.city;
                                                    editLocationStreet =
                                                        result.street;
                                                    editLatitude =
                                                        result.latitude;
                                                    editLongitude =
                                                        result.longitude;
                                                    editTimezoneId =
                                                        result.timezoneId ??
                                                        editTimezoneId;
                                                  });
                                                  unawaited(
                                                    refreshEditVenueContext(),
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.edit_location,
                                                size: 18,
                                              ),
                                              label: Text(
                                                l10n.change_location,
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    UIConstants.appOrange,
                                                side: const BorderSide(
                                                  color: UIConstants.partyYellow,
                                                ),
                                              ),
                                            ),
                                            if (partyType != 'public' &&
                                                _partyHasPersistableLocation(
                                              editLocationName:
                                                  editLocationName,
                                              editLocationAddress:
                                                  editLocationAddress,
                                              editLocationZip: editLocationZip,
                                              editLocationCity:
                                                  editLocationCity,
                                              editLocationStreet:
                                                  editLocationStreet,
                                              editLatitude: editLatitude,
                                              editLongitude: editLongitude,
                                              locationNotSpecifiedLabel:
                                                  l10n.location_not_specified,
                                            ))
                                              TextButton.icon(
                                                onPressed: () {
                                                  setDialogState(() {
                                                    editLocationName = l10n
                                                        .location_not_specified;
                                                    editLocationAddress = '';
                                                    editLocationZip = null;
                                                    editLocationCity = null;
                                                    editLocationStreet = null;
                                                    editLatitude = null;
                                                    editLongitude = null;
                                                    editTimezoneId =
                                                        _getDeviceTimezoneId();
                                                  });
                                                  unawaited(
                                                    refreshEditVenueContext(),
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.location_off_outlined,
                                                  size: 18,
                                                ),
                                                label: Text(
                                                  l10n.clear_party_location,
                                                ),
                                                style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      Colors.grey.shade400,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (partyType == 'public' &&
                                      editMatchedPublicLocation != null)
                                    _buildMatchedPublicLocationBanner(
                                      context,
                                      editMatchedPublicLocation!,
                                    ),
                                  if (partyType == 'public' &&
                                      !editHasCoordinates() &&
                                      (currentEditStepKind ==
                                              PartyWizardStepKind.location ||
                                          currentEditStepKind ==
                                              PartyWizardStepKind.floor))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        l10n.party_public_location_coords_required,
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  if (partyType == 'public' &&
                                      currentEditStepKind ==
                                          PartyWizardStepKind.location) ...[
                                    const SizedBox(height: 16),
                                    if (editPartyCode != null &&
                                        editPartyCode!.trim().isNotEmpty)
                                      Align(
                                        alignment: AlignmentDirectional.centerStart,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade900,
                                            border: Border.all(
                                              color: UIConstants.appOrange,
                                              width: 2,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              l10n.party_fixed_code_display(
                                                editPartyCode!.trim(),
                                              ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        l10n.party_code_on_save,
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                  ],
                                  if (partyType == 'public' &&
                                      (currentEditStepKind ==
                                              PartyWizardStepKind.floor ||
                                          currentEditStepKind ==
                                              PartyWizardStepKind
                                                  .locationWithFloor) &&
                                      !editHasCoordinates())
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        l10n.party_public_location_coords_required,
                                        style: const TextStyle(
                                          color: Colors.orange,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  if ((currentEditStepKind ==
                                              PartyWizardStepKind.floor ||
                                          currentEditStepKind ==
                                              PartyWizardStepKind
                                                  .locationWithFloor) &&
                                      showEditFloorField()) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      l10n.party_floor_label,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    RadioListTile<_EditPublicFloorChoice>(
                                      value: _EditPublicFloorChoice.noFloor,
                                      groupValue: editPublicFloorChoice,
                                      onChanged: (editOverlappingParties
                                                      .isNotEmpty &&
                                                  editVenueOverlapJoinAccepted ==
                                                      true) ||
                                              !editDefaultFloorAvailable()
                                          ? null
                                          : (v) {
                                              if (v == null) return;
                                              setDialogState(() {
                                                editPublicFloorChoice = v;
                                                editSelectedFloorKey = null;
                                              });
                                            },
                                      activeColor: UIConstants.appOrange,
                                      title: Text(
                                        l10n.party_floor_mode_none,
                                        style: TextStyle(
                                          color: editDefaultFloorAvailable()
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                      subtitle: !editDefaultFloorAvailable()
                                          ? Text(
                                              l10n.party_floor_select_hint,
                                              style: TextStyle(
                                                color: Colors.orange.shade200,
                                                fontSize: 12,
                                              ),
                                            )
                                          : null,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    RadioListTile<_EditPublicFloorChoice>(
                                      value: _EditPublicFloorChoice.selectFloor,
                                      groupValue: editPublicFloorChoice,
                                      onChanged: (v) {
                                        if (v == null) return;
                                        setDialogState(() {
                                          editPublicFloorChoice = v;
                                        });
                                      },
                                      activeColor: UIConstants.appOrange,
                                      title: Text(
                                        l10n.party_floor_mode_select,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    if (editPublicFloorChoice ==
                                        _EditPublicFloorChoice.selectFloor) ...[
                                      const SizedBox(height: 8),
                                      PublicVenueFloorField(
                                        floors: editVenueModel?.floors ??
                                            const [],
                                        selectedFloorKey: editSelectedFloorKey,
                                        defaultFloorAvailable:
                                            editDefaultFloorAvailable(),
                                        occupiedFloorKeys:
                                            editOccupiedFloorKeys,
                                        floorOccupancy: editFloorOccupancy,
                                        hasVenueOverlap:
                                            editOverlappingParties.isNotEmpty,
                                        isLoading: editVenueContextLoading,
                                        floorsOnlyInDropdown: true,
                                        showOccupiedInDropdown: false,
                                        onFloorSelected: (key) {
                                          setDialogState(() {
                                            editSelectedFloorKey = key;
                                          });
                                        },
                                        onOccupiedFloorTap:
                                            (key, info) async {
                                          if (editVenueId == null) return;
                                          final occStart =
                                              editPlannedStartDateTime() ??
                                                  currentStartDate;
                                          final occEnd =
                                              editPlannedEndDateTime() ??
                                                  currentEndDate;
                                          await showFloorSwapRequestDialog(
                                            context: context,
                                            venueId: editVenueId!,
                                            fromPartyId: partyId,
                                            fromFloorKey: editSelectedFloorKey ??
                                                initialEditFloorKey,
                                            targetFloorKey: key,
                                            targetOccupancy: info,
                                            venueFloors:
                                                editVenueModel?.floors ??
                                                    const [],
                                          );
                                          editOccupiedFloorKeys =
                                              await VenuePartyConflictService()
                                                  .occupiedFloorKeys(
                                            venueId: editVenueId!,
                                            start: occStart,
                                            end: occEnd,
                                            excludePartyId: partyId,
                                          );
                                          editFloorOccupancy =
                                              await VenuePartyConflictService()
                                                  .occupancyByFloorKey(
                                            venueId: editVenueId!,
                                            start: occStart,
                                            end: occEnd,
                                            excludePartyId: partyId,
                                          );
                                          setDialogState(() {});
                                        },
                                        onAddFloor: () async {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          await Future<void>.delayed(
                                            const Duration(milliseconds: 50),
                                          );
                                          final label =
                                              await PartyFloorNameDialog.show(
                                            context,
                                          );
                                          if (label == null || label.isEmpty) {
                                            return;
                                          }
                                          try {
                                            final updated =
                                                await VenueService().addFloor(
                                              venueId: editVenueId!,
                                              floorLabel: label,
                                              createdBy:
                                                  FirebaseAuth.instance
                                                          .currentUser?.uid ??
                                                      '',
                                            );
                                            setDialogState(() {
                                              editVenueModel = updated;
                                              editSelectedFloorKey =
                                                  FloorKeyUtils.slugFromLabel(
                                                label,
                                              );
                                              editPublicFloorChoice =
                                                  _EditPublicFloorChoice
                                                      .selectFloor;
                                            });
                                          } catch (e) {
                                            debugLog('⚠️ Floor anlegen: $e');
                                          }
                                        },
                                      ),
                                    ],
                                    if (editOverlappingParties.isNotEmpty &&
                                        editVenueOverlapJoinAccepted == false)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          l10n.party_venue_overlap_decline_hint,
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    if (editOverlappingParties.isNotEmpty &&
                                        editVenueOverlapJoinAccepted == null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          l10n
                                              .party_venue_overlap_join_floor_question,
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                  ],
                                  if (currentEditStepKind ==
                                      PartyWizardStepKind.startTime)
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 100,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                  // Start-Datum und Start-Uhrzeit (nur bearbeitbar wenn Party noch nicht begonnen)
                                  if (hasNotStarted) ...[
                                    Text(
                                      l10n.party_start_label,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l10n.party_date_label,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              InkWell(
                                                onTap: isPartyRunning
                                                    ? null
                                                    : () async {
                                                        final picked = await showDatePicker(
                                                          context: context,
                                                          initialDate:
                                                              startDate ??
                                                              currentStartDate,
                                                          firstDate: DateTime.now()
                                                              .subtract(
                                                                const Duration(
                                                                  days: 365,
                                                                ),
                                                              ),
                                                          lastDate:
                                                              DateTime.now().add(
                                                                const Duration(
                                                                  days: 365,
                                                                ),
                                                              ),
                                                        );
                                                        if (picked != null) {
                                                          setDialogState(() {
                                                            startDate = picked;
                                                          });
                                                          unawaited(
                                                            editAfterDateTimeChanged(),
                                                          );
                                                        }
                                                      },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 12,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: isPartyRunning
                                                          ? Colors.grey
                                                                .withValues(
                                                                  alpha: 0.5,
                                                                )
                                                          : Colors.grey,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          startDate != null
                                                              ? FormattingUtils.formatDateForLocale(
                                                                  startDate!,
                                                                  context,
                                                                )
                                                              : l10n.party_not_selected,
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color:
                                                                isPartyRunning
                                                                ? Colors.grey
                                                                : Colors.white,
                                                          ),
                                                        ),
                                                      ),
                                                      Transform.flip(
                                                        flipX: isRtl,
                                                        child: Icon(
                                                          Icons
                                                              .arrow_forward_ios,
                                                          size: 14,
                                                          color: isPartyRunning
                                                              ? Colors.grey
                                                                    .withValues(
                                                                      alpha:
                                                                          0.5,
                                                                    )
                                                              : Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l10n.party_time_label,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              isPartyRunning
                                                  ? Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF1F2937,
                                                        ),
                                                        border: Border.all(
                                                          color: Colors
                                                              .grey
                                                              .shade700,
                                                          width: 1.5,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        startHour != null &&
                                                                startMinute !=
                                                                    null
                                                            ? FormattingUtils.formatTime(
                                                                DateTime(
                                                                  (startDate ??
                                                                          currentStartDate)
                                                                      .year,
                                                                  (startDate ??
                                                                          currentStartDate)
                                                                      .month,
                                                                  (startDate ??
                                                                          currentStartDate)
                                                                      .day,
                                                                  startHour!,
                                                                  startMinute!,
                                                                ),
                                                                context,
                                                              )
                                                            : l10n.party_not_selected,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: Colors
                                                              .grey
                                                              .shade400,
                                                        ),
                                                      ),
                                                    )
                                                  : PartyTimeDropdownRow(
                                                      valueHour: startHour,
                                                      valueMinute: startMinute,
                                                      availableHours:
                                                          PartyTimeHelpers.getAvailableStartHours(
                                                            startDate,
                                                          ),
                                                      availableMinutes:
                                                          PartyTimeHelpers.getAvailableStartMinutes(
                                                            startDate,
                                                            startHour,
                                                          ),
                                                      enabled: !isPartyRunning,
                                                      labelHour: l10n.select_hour,
                                                      labelMinute:
                                                          l10n.select_minute,
                                                      onChanged: (h, m) {
                                                        final mins =
                                                            PartyTimeHelpers.getAvailableStartMinutes(
                                                              startDate,
                                                              h,
                                                            );
                                                        setDialogState(() {
                                                          startHour = h;
                                                          startMinute =
                                                              mins.contains(m)
                                                              ? m
                                                              : (mins.isNotEmpty
                                                                    ? mins.first
                                                                    : 0);
                                                          endDate = null;
                                                          endHour = null;
                                                          endMinute = null;
                                                        });
                                                        unawaited(
                                                          editAfterDateTimeChanged(),
                                                        );
                                                      },
                                                    ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                  ] else ...[
                                    Text(
                                      '${l10n.party_start_label} ${formatDateTime(currentStartDate, context)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                        ],
                                      ),
                                    ),
                                  if (currentEditStepKind ==
                                      PartyWizardStepKind.endTime)
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minHeight: 100,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                  // End-Datum und End-Uhrzeit (immer bearbeitbar)
                                  Text(
                                    l10n.party_end_label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.party_date_label,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            InkWell(
                                              onTap: () async {
                                                final startDay = DateTime(
                                                  currentStartDate.year,
                                                  currentStartDate.month,
                                                  currentStartDate.day,
                                                );
                                                final earliestEndDay =
                                                    minEndDateTime != null
                                                    ? DateTime(
                                                        minEndDateTime.year,
                                                        minEndDateTime.month,
                                                        minEndDateTime.day,
                                                      )
                                                    : startDay;
                                                final firstDate = hasNotStarted
                                                    ? (startDate ??
                                                          currentStartDate)
                                                    : (earliestEndDay.isAfter(
                                                            startDay,
                                                          )
                                                          ? earliestEndDay
                                                          : startDay);
                                                final picked =
                                                    await showDatePicker(
                                                      context: context,
                                                      initialDate:
                                                          endDate ??
                                                          currentEndDate,
                                                      firstDate: firstDate,
                                                      lastDate: DateTime.now()
                                                          .add(
                                                            const Duration(
                                                              days: 365,
                                                            ),
                                                          ),
                                                    );
                                                if (picked != null) {
                                                  setDialogState(() {
                                                    endDate = picked;
                                                  });
                                                  unawaited(
                                                    editAfterDateTimeChanged(),
                                                  );
                                                }
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: Colors.grey,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        endDate != null
                                                            ? FormattingUtils.formatDateForLocale(
                                                                endDate!,
                                                                context,
                                                              )
                                                            : l10n.party_not_selected,
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Colors.white,
                                                        ),
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
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              l10n.party_time_label,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            PartyTimeDropdownRow(
                                              valueHour: endHour,
                                              valueMinute: endMinute,
                                              availableHours:
                                                  PartyTimeHelpers.getAvailableEndHours(
                                                    startDate ??
                                                        currentStartDate,
                                                    isPartyRunning
                                                        ? currentStartDate.hour
                                                        : startHour,
                                                    isPartyRunning
                                                        ? currentStartDate.minute
                                                        : startMinute,
                                                    endDate,
                                                    minEndDateTime:
                                                        minEndDateTime,
                                                    maxDuration:
                                                        partyMaxDuration,
                                                  ),
                                              availableMinutes:
                                                  PartyTimeHelpers.getAvailableEndMinutes(
                                                    startDate ??
                                                        currentStartDate,
                                                    isPartyRunning
                                                        ? currentStartDate.hour
                                                        : startHour,
                                                    isPartyRunning
                                                        ? currentStartDate.minute
                                                        : startMinute,
                                                    endDate,
                                                    endHour,
                                                    minEndDateTime:
                                                        minEndDateTime,
                                                    maxDuration:
                                                        partyMaxDuration,
                                                  ),
                                              enabled: endDate != null,
                                              labelHour: l10n.select_hour,
                                              labelMinute: l10n.select_minute,
                                              onChanged: (h, m) {
                                                setDialogState(() {
                                                  endHour = h;
                                                  endMinute = m;
                                                });
                                                unawaited(
                                                  editAfterDateTimeChanged(),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Validierungsfehlermeldung unter End-Zeitfeldern
                                  if (validationError != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      validationError!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: UIConstants.appOrange,
                                      ),
                                    ),
                                  ],
                                        ],
                                      ),
                                    ),
                                  if (currentEditStepKind ==
                                      PartyWizardStepKind.wishLimits) ...[
                                  // Wunsch-Limits (immer bearbeitbar)
                                  Text(
                                    l10n.party_wish_limits,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          key: ValueKey<String>(
                                            'gl_${isFreeEdit}_${selectedGuestLimit ?? 0}',
                                          ),
                                          initialValue: isFreeEdit
                                              ? 1
                                              : selectedGuestLimit,
                                          decoration: InputDecoration(
                                            labelText: l10n.party_guest_limit,
                                            border: const OutlineInputBorder(),
                                            prefixIcon: Icon(
                                              Icons.person_outline,
                                              size: 20,
                                              color: isFreeEdit
                                                  ? Colors.grey
                                                  : null,
                                            ),
                                            isDense: true,
                                            filled: isFreeEdit,
                                            fillColor: isFreeEdit
                                                ? Colors.grey.shade800
                                                : null,
                                          ),
                                          items: guestLimitOptions.map((
                                            int value,
                                          ) {
                                            return DropdownMenuItem<int>(
                                              value: value,
                                              child: Text(value.toString()),
                                            );
                                          }).toList(),
                                          onChanged: isFreeEdit
                                              ? null
                                              : (int? newValue) {
                                                  setDialogState(() {
                                                    selectedGuestLimit =
                                                        newValue;
                                                  });
                                                },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          key: ValueKey<String>(
                                            'ul_${isFreeEdit}_${selectedUserLimit ?? 0}',
                                          ),
                                          initialValue: isFreeEdit
                                              ? 1
                                              : selectedUserLimit,
                                          decoration: InputDecoration(
                                            labelText:
                                                l10n.party_registered_app_guest,
                                            border: const OutlineInputBorder(),
                                            prefixIcon: Icon(
                                              Icons.person,
                                              size: 20,
                                              color: isFreeEdit
                                                  ? Colors.grey
                                                  : null,
                                            ),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                Icons.info_outline,
                                                color: Colors.grey.shade400,
                                                size: 20,
                                              ),
                                              tooltip: l10n
                                                  .party_registered_app_guest_info_title,
                                              onPressed: () =>
                                                  _showRegisteredAppGuestInfo(
                                                    context,
                                                  ),
                                            ),
                                            isDense: true,
                                            filled: isFreeEdit,
                                            fillColor: isFreeEdit
                                                ? Colors.grey.shade800
                                                : null,
                                          ),
                                          items: userLimitOptions.map((
                                            int value,
                                          ) {
                                            return DropdownMenuItem<int>(
                                              value: value,
                                              child: Text(value.toString()),
                                            );
                                          }).toList(),
                                          onChanged: isFreeEdit
                                              ? null
                                              : (int? newValue) {
                                                  setDialogState(() {
                                                    selectedUserLimit =
                                                        newValue;
                                                  });
                                                },
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isFreeEdit) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      l10n.free_limit_info,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                  ],
                                  if (currentEditStepKind ==
                                      PartyWizardStepKind.preWishes) ...[
                                  const SizedBox(height: 8),
                                  PartyPreWishSettingsField(
                                    allowPreWishes: allowPreWishes,
                                    limitPerGuest: preWishLimitPerGuest,
                                    settingsEditable:
                                        PreWishHelper.canConfigurePreWishesSettings(
                                      editPlannedStartDateTime() ??
                                          currentStartDate,
                                    ),
                                    allowDisablePreWishes: false,
                                    onAllowChanged: (v) {
                                      if (!v &&
                                          (initialAllowPreWishes ||
                                              allowPreWishes)) {
                                        return;
                                      }
                                      setDialogState(() {
                                        allowPreWishes = v;
                                      });
                                    },
                                    onLimitChanged: (n) {
                                      setDialogState(() {
                                        preWishLimitPerGuest = n;
                                      });
                                    },
                                  ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              if (editWizardStep > 0)
                                OutlinedButton(
                                  onPressed: editIsSaving ? null : editGoBack,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Colors.white70,
                                      width: 1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    l10n.back,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                )
                              else
                                OutlinedButton(
                                  onPressed: editIsSaving
                                      ? null
                                      : () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Colors.white70,
                                      width: 1,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    l10n.party_cancel,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              FilledButton(
                                key: const Key('party_save'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: editCanProceed
                                      ? UIConstants.appOrange
                                      : Colors.grey.shade800,
                                  foregroundColor: editCanProceed
                                      ? Colors.black
                                      : Colors.grey.shade600,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: (editIsSaving || !editCanProceed)
                                    ? null
                                    : (isEditLastStep
                                          ? () async {
                                        DateTime newStartDateTime =
                                            currentStartDate;
                                        if (hasNotStarted) {
                                          if (startDate == null ||
                                              startHour == null ||
                                              startMinute == null) {
                                            showVibesSnackBar(context, 
                                              SnackBar(
                                                content: Text(
                                                  l10n
                                                      .party_validation_start_required,
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            return;
                                          }
                                          newStartDateTime = DateTime(
                                            startDate!.year,
                                            startDate!.month,
                                            startDate!.day,
                                            startHour!,
                                            startMinute!,
                                          );
                                        }

                                        if (endDate == null ||
                                            endHour == null ||
                                            endMinute == null) {
                                          showVibesSnackBar(context, 
                                            SnackBar(
                                              content: Text(
                                                l10n.party_validation_end_required,
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        final newEndDateTime = DateTime(
                                          endDate!.year,
                                          endDate!.month,
                                          endDate!.day,
                                          endHour!,
                                          endMinute!,
                                        );

                                        if (newEndDateTime.isBefore(
                                          newStartDateTime,
                                        )) {
                                          showVibesSnackBar(context, 
                                            SnackBar(
                                              content: Text(
                                                l10n
                                                    .party_validation_end_before_start,
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        // Validierung der Limits
                                        if (selectedGuestLimit == null) {
                                          showVibesSnackBar(context, 
                                            SnackBar(
                                              content: Text(
                                                l10n
                                                    .party_validation_guest_limit_required,
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        if (selectedUserLimit == null) {
                                          showVibesSnackBar(context, 
                                            SnackBar(
                                              content: Text(
                                                l10n
                                                    .party_validation_user_limit_required,
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        if (partyNameController.text
                                                .trim()
                                                .length <
                                            3) {
                                          showVibesSnackBar(context, 
                                            SnackBar(
                                              content: Text(
                                                l10n.party_name_min_length,
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }

                                        if (partyType == 'public') {
                                          if (editHasCoordinates() &&
                                              editOverlappingParties
                                                      .isNotEmpty &&
                                              editVenueOverlapJoinAccepted !=
                                                  true) {
                                            showVibesSnackBar(context, 
                                              SnackBar(
                                                content: Text(
                                                  l10n
                                                      .party_venue_overlap_decline_hint,
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            return;
                                          }
                                          if (editHasCoordinates() &&
                                              !editPublicLocationFloorStepValid()) {
                                            showVibesSnackBar(context, 
                                              SnackBar(
                                                content: Text(
                                                  editVenueContextLoading
                                                      ? l10n
                                                          .party_floor_select_hint
                                                      : l10n
                                                          .party_floor_select_hint,
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                            return;
                                          }
                                        }

                                        setDialogState(() => editIsSaving = true);

                                        try {
                                          final authUser =
                                              FirebaseAuth.instance.currentUser;
                                          final freshPartySnap =
                                              await FirebaseFirestore.instance
                                                  .collection('parties')
                                                  .doc(partyId)
                                                  .get();
                                          if (!freshPartySnap.exists) {
                                            if (context.mounted) {
                                              showVibesSnackBar(context, 
                                                SnackBar(
                                                  content: Text(
                                                    l10n.party_error,
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                            return;
                                          }
                                          final freshPartyData =
                                              freshPartySnap.data();
                                          if (!PartyOwnershipHelper.canManageParty(
                                            freshPartyData,
                                            authUser?.uid,
                                            currentUser: UserService()
                                                .currentUser
                                                .value,
                                          )) {
                                            if (context.mounted) {
                                              showVibesSnackBar(context, 
                                                SnackBar(
                                                  content: Text(
                                                    l10n.delete_party_only_own,
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                            return;
                                          }

                                          // STRICTE VERGANGENHEITS-VALIDIERUNG: UTC-Basis
                                          // Wandle gewählte Zeit unter Verwendung der ermittelten timezoneId in UTC um
                                          // Vergleiche diesen UTC-Wert mit DateTime.now().toUtc()

                                          int? newStartTimePosix;
                                          int? newEndTimePosix;

                                          // Konvertiere End-Zeit zu UTC Unix-Timestamp basierend auf timezone_id
                                          newEndTimePosix =
                                              await _convertLocalTimeToUnixTimestamp(
                                                newEndDateTime,
                                                editTimezoneId,
                                                editLatitude,
                                                editLongitude,
                                              );

                                          // Konvertiere Start-Zeit nur wenn Party noch nicht gestartet
                                          if (hasNotStarted) {
                                            newStartTimePosix =
                                                await _convertLocalTimeToUnixTimestamp(
                                                  newStartDateTime,
                                                  editTimezoneId,
                                                  editLatitude,
                                                  editLongitude,
                                                );
                                          }

                                          // STRICTE UTC-VALIDIERUNG: Vergleiche UTC-Werte
                                          final nowUtcUnixSeconds =
                                              DateTime.now()
                                                  .toUtc()
                                                  .millisecondsSinceEpoch ~/
                                              1000;

                                          // Validiere End-Zeit: UTC-Wert muss größer als jetzt sein
                                          if (newEndTimePosix <=
                                              nowUtcUnixSeconds) {
                                            if (context.mounted) {
                                              showVibesSnackBar(context, 
                                                SnackBar(
                                                  content: Text(
                                                    l10n.party_validation_end_in_past,
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                            return;
                                          }

                                          // Validiere Start-Zeit (nur wenn Party noch nicht gestartet)
                                          if (hasNotStarted &&
                                              newStartTimePosix != null &&
                                              newStartTimePosix <=
                                                  nowUtcUnixSeconds) {
                                            if (context.mounted) {
                                              showVibesSnackBar(context, 
                                                SnackBar(
                                                  content: Text(
                                                    l10n
                                                        .party_validation_start_in_past,
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                            return;
                                          }

                                          debugLog(
                                            '✅ Unix-Timestamps berechnet (präzise UTC):',
                                          );
                                          if (hasNotStarted) {
                                            debugLog(
                                              '   Start (UTC): $newStartTimePosix',
                                            );
                                          }
                                          debugLog(
                                            '   End (UTC): $newEndTimePosix',
                                          );
                                          debugLog(
                                            '   Jetzt (UTC): $nowUtcUnixSeconds',
                                          );
                                          debugLog('   Zeitzone: $editTimezoneId');

                                          // SYNCHRONES Speichern: Beide Datenformate gleichzeitig aktualisieren
                                          // DATEN-INTEGRITÄT: Speichere die verwendete timezoneId und alle Location-Felder
                                          // Keine Platzhalter in DB: l10n-Placeholder oder leer → null
                                          final locNotSpecified =
                                              l10n.location_not_specified;
                                          final hasPersistableLocation =
                                              _partyHasPersistableLocation(
                                                editLocationName:
                                                    editLocationName,
                                                editLocationAddress:
                                                    editLocationAddress,
                                                editLocationZip:
                                                    editLocationZip,
                                                editLocationCity:
                                                    editLocationCity,
                                                editLocationStreet:
                                                    editLocationStreet,
                                                editLatitude: editLatitude,
                                                editLongitude: editLongitude,
                                                locationNotSpecifiedLabel:
                                                    locNotSpecified,
                                              );
                                          final String? locationNameToSave;
                                          final String? locationAddressToSave;
                                          if (hasPersistableLocation) {
                                            final trimmedName =
                                                editLocationName.trim();
                                            locationNameToSave =
                                                trimmedName.isEmpty
                                                ? null
                                                : trimmedName;
                                            locationAddressToSave =
                                                (editLocationAddress
                                                    .trim()
                                                    .isEmpty)
                                                ? null
                                                : editLocationAddress.trim();
                                          } else {
                                            locationNameToSave = null;
                                            locationAddressToSave = null;
                                          }
                                          final plannedStartForPreWishes =
                                              editPlannedStartDateTime() ??
                                                  currentStartDate;
                                          final canEditPreWishSettings =
                                              PreWishHelper
                                                  .canConfigurePreWishesSettings(
                                                plannedStartForPreWishes,
                                              );
                                          final updateData = <String, dynamic>{
                                            'party_name': _sanitizeInput(
                                              partyNameController.text.trim(),
                                            ),
                                            'end_time_posix': newEndTimePosix,
                                            'end_date':
                                                Timestamp.fromMillisecondsSinceEpoch(
                                                  newEndTimePosix * 1000,
                                                ),
                                            'timezone_id': editTimezoneId,
                                            if (canEditPreWishSettings) ...{
                                              'allow_pre_wishes':
                                                  initialAllowPreWishes
                                                      ? true
                                                      : allowPreWishes,
                                              'pre_wish_limit_per_guest':
                                                  PreWishLimitService
                                                      .clampForSave(
                                                preWishLimitPerGuest,
                                                allowPreWishes:
                                                    initialAllowPreWishes
                                                        ? true
                                                        : allowPreWishes,
                                              ),
                                            },
                                            'guest_limit_per_hour': isFreeEdit
                                                ? 1
                                                : selectedGuestLimit,
                                            'user_limit_per_hour': isFreeEdit
                                                ? 1
                                                : selectedUserLimit,
                                            // Location-Felder (null statt Platzhalter)
                                            'location_name': locationNameToSave,
                                            'location_address':
                                                locationAddressToSave,
                                          };
                                          if (hasPersistableLocation) {
                                            if (editLocationZip != null &&
                                                editLocationZip!
                                                    .trim()
                                                    .isNotEmpty) {
                                              updateData['location_zip'] =
                                                  SecurityHelper.sanitize(
                                                    editLocationZip!.trim(),
                                                    maxLength: 20,
                                                  );
                                            }
                                            if (editLocationCity != null &&
                                                editLocationCity!
                                                    .trim()
                                                    .isNotEmpty) {
                                              updateData['location_city'] =
                                                  SecurityHelper.sanitize(
                                                    editLocationCity!.trim(),
                                                    maxLength: 80,
                                                  );
                                            }
                                            if (editLocationStreet != null &&
                                                editLocationStreet!
                                                    .trim()
                                                    .isNotEmpty) {
                                              updateData['location_street'] =
                                                  SecurityHelper.sanitize(
                                                    editLocationStreet!.trim(),
                                                    maxLength: 120,
                                                  );
                                            }
                                            if (editLatitude != null &&
                                                editLatitude != 0.0) {
                                              updateData['latitude'] =
                                                  editLatitude;
                                            }
                                            if (editLongitude != null &&
                                                editLongitude != 0.0) {
                                              updateData['longitude'] =
                                                  editLongitude;
                                            }
                                          } else {
                                            updateData['location_zip'] = null;
                                            updateData['location_city'] = null;
                                            updateData['location_street'] =
                                                null;
                                            updateData['latitude'] = null;
                                            updateData['longitude'] = null;
                                          }

                                          if (hasNotStarted) {
                                            // Party-Typ wird nicht mehr geändert (deaktiviert)
                                            updateData['start_time_posix'] =
                                                newStartTimePosix; // Unix-Timestamp in UTC (Sekunden) - PRÄZISE für Cronjob
                                            updateData['start_date'] =
                                                Timestamp.fromMillisecondsSinceEpoch(
                                                  newStartTimePosix! * 1000,
                                                ); // Abgeleitet vom POSIX-Wert
                                          }

                                          Map<String, dynamic>? publicVenuePayload;

                                          if (partyType == 'public' &&
                                              editHasCoordinates()) {
                                            if (editOccupiedFloorKeys.contains(
                                                  editSelectedFloorKey,
                                                ) &&
                                                editSelectedFloorKey !=
                                                    initialEditFloorKey) {
                                              if (context.mounted) {
                                                showVibesSnackBar(context, 
                                                  SnackBar(
                                                    content: Text(
                                                      l10n
                                                          .party_floor_swap_after_save_hint,
                                                    ),
                                                  ),
                                                );
                                              }
                                              return;
                                            }
                                            final matchedVenue =
                                                await VenueService()
                                                    .findMatchingVenue(
                                              latitude: editLatitude!,
                                              longitude: editLongitude!,
                                            );
                                            final venueIdForOverlap =
                                                matchedVenue?.id ??
                                                    VenuePartyFields
                                                        .readVenueId(
                                                      freshPartyData ?? {},
                                                    ) ??
                                                    '';
                                            final isCoVenueDj =
                                                venueIdForOverlap.isNotEmpty
                                                    ? await VenuePartyConflictService()
                                                        .hasVenueOverlap(
                                                        venueId:
                                                            venueIdForOverlap,
                                                        start:
                                                            newStartDateTime,
                                                        end: newEndDateTime,
                                                        excludePartyId:
                                                            partyId,
                                                      )
                                                    : false;
                                            String? floorLabel;
                                            final explicitFloor =
                                                editPublicFloorChoice ==
                                                    _EditPublicFloorChoice
                                                        .selectFloor;
                                            final floorKeyForSave =
                                                explicitFloor
                                                    ? editSelectedFloorKey
                                                    : null;
                                            if (floorKeyForSave != null &&
                                                matchedVenue != null &&
                                                !FloorKeyUtils
                                                    .isDefaultFloorKey(
                                                  floorKeyForSave,
                                                )) {
                                              floorLabel = matchedVenue
                                                  .floorByKey(
                                                    floorKeyForSave,
                                                  )
                                                  ?.label;
                                            }
                                            final rawVenueName =
                                                editLocationName.trim();
                                            final venueDisplayName =
                                                rawVenueName.isNotEmpty &&
                                                        rawVenueName !=
                                                            locNotSpecified
                                                    ? rawVenueName
                                                    : l10n.unnamed_location;
                                            publicVenuePayload = {
                                              'name': venueDisplayName,
                                              if (locationAddressToSave !=
                                                      null &&
                                                  locationAddressToSave
                                                      .isNotEmpty)
                                                'address':
                                                    locationAddressToSave,
                                              'latitude': editLatitude,
                                              'longitude': editLongitude,
                                              'timezoneId': editTimezoneId,
                                              'isCoVenueDj': isCoVenueDj,
                                              if (!explicitFloor)
                                                'noFloor': true
                                              else if (floorKeyForSave !=
                                                      null &&
                                                  floorKeyForSave.isNotEmpty)
                                                'floorKey': floorKeyForSave,
                                              if (floorLabel != null &&
                                                  floorLabel.isNotEmpty)
                                                'floorLabel': floorLabel,
                                            };
                                          }

                                          final sanitizedUpdate =
                                              SecurityHelper.sanitizeMap(
                                            updateData,
                                          );
                                          await PartySecureService.instance
                                              .updateParty(
                                            partyId: partyId,
                                            patch: sanitizedUpdate,
                                            publicVenue: publicVenuePayload,
                                          );

                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            showVibesSnackBar(context, 
                                              SnackBar(
                                                content: Text(
                                                  l10n.party_updated_success,
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e, st) {
                                          AppDiagnosticLogService.instance
                                              .recordPartySaveFailure(
                                            step: 'party-update',
                                            error: e,
                                            stackTrace: st,
                                            context: {
                                              'party_id': partyId,
                                              'party_type': partyType ?? '—',
                                            },
                                          );
                                          if (context.mounted) {
                                            showVibesSnackBar(context, 
                                              SnackBar(
                                                content: Text(
                                                  '${l10n.party_error_updating} $e',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        } finally {
                                          if (context.mounted) {
                                            setDialogState(
                                              () => editIsSaving = false,
                                            );
                                          }
                                        }
                                      }
                                          : editGoNext),
                                child: editIsSaving && isEditLastStep
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        isEditLastStep
                                            ? l10n.party_save
                                            : l10n.party_wizard_next,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      editScrollController.dispose();
    }
  }

  /// True, wenn mindestens ein Standortfeld in Firestore geschrieben werden soll.
  static bool _partyHasPersistableLocation({
    required String editLocationName,
    required String editLocationAddress,
    required String? editLocationZip,
    required String? editLocationCity,
    required String? editLocationStreet,
    required double? editLatitude,
    required double? editLongitude,
    required String locationNotSpecifiedLabel,
  }) {
    final name = editLocationName.trim();
    if (name.isNotEmpty && name != locationNotSpecifiedLabel) {
      return true;
    }
    if (editLocationAddress.trim().isNotEmpty) {
      return true;
    }
    if ((editLocationZip ?? '').trim().isNotEmpty) {
      return true;
    }
    if ((editLocationCity ?? '').trim().isNotEmpty) {
      return true;
    }
    if ((editLocationStreet ?? '').trim().isNotEmpty) {
      return true;
    }
    final lat = editLatitude;
    final lng = editLongitude;
    if (lat != null &&
        lng != null &&
        lat != 0.0 &&
        lng != 0.0) {
      return true;
    }
    return false;
  }

  /// Sanitized Input für Party-Namen
  static String _sanitizeInput(String input) {
    return SecurityHelper.sanitize(input, maxLength: 100);
  }

  /// Ermittelt die IANA-Zeitzone des DJ-Geräts
  /// Priorität: tz.local.name → Offset-basiertes Mapping → UTC
  static String _getDeviceTimezoneId() {
    try {
      // PRIORITÄT 1: Nutze timezone Package wenn verfügbar
      try {
        final localTZ = tz.local;
        final tzLocalName = localTZ.name;
        if (tzLocalName.isNotEmpty &&
            tzLocalName != 'Local' &&
            tzLocalName.toLowerCase() != 'utc') {
          debugLog('✅ Geräte-Zeitzone via tz.local.name: $tzLocalName');
          return tzLocalName;
        }
      } catch (e) {
        debugLog('⚠️ tz.local.name nicht verfügbar, nutze Mapping: $e');
      }

      // PRIORITÄT 2: Offset-basiertes Mapping
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final offsetHours = offset.inHours;
      final timeZoneName = now.timeZoneName;

      // Mapping basierend auf Offset und Zeitzonen-Name
      if (timeZoneName.contains('CET') ||
          timeZoneName.contains('CEST') ||
          timeZoneName == 'MEZ' ||
          timeZoneName == 'MESZ') {
        debugLog('✅ Geräte-Zeitzone via Name-Mapping: Europe/Berlin');
        return 'Europe/Berlin';
      } else if (offsetHours == 1 || offsetHours == 2) {
        // CET/CEST (Deutschland, Mitteleuropa)
        debugLog(
          '✅ Geräte-Zeitzone via Offset-Mapping: Europe/Berlin (Offset: ${offsetHours}h)',
        );
        return 'Europe/Berlin';
      } else if (offsetHours == 0) {
        debugLog('✅ Geräte-Zeitzone via Offset-Mapping: UTC');
        return 'UTC';
      } else {
        // Fallback: Versuche weitere häufige Zeitzonen basierend auf Offset
        // Dies ist vereinfacht - für Produktion sollte eine vollständige Mapping-Tabelle verwendet werden
        debugLog('⚠️ Unbekannter Offset ($offsetHours h) - Fallback auf UTC');
        return 'UTC';
      }
    } catch (e) {
      debugLog('❌ Fehler beim Ermitteln der Geräte-Zeitzone: $e');
      return 'UTC';
    }
  }

  /// Berechnet die aktuelle Zeit in der Party-Zeitzone für Vergangenheits-Validierung
  /// Gibt ein DateTime-Objekt zurück, das die aktuelle Zeit in der Party-Zeitzone repräsentiert
  static Future<DateTime> _getCurrentTimeInTimezone(
    String timezoneId,
    double? latitude,
    double? longitude,
  ) async {
    try {
      final nowUtc = DateTime.now().toUtc();
      final nowUnixSeconds = nowUtc.millisecondsSinceEpoch ~/ 1000;

      // Wenn wir Koordinaten haben, nutze Google Time Zone API für präzisen Offset
      if (latitude != null &&
          longitude != null &&
          latitude != 0.0 &&
          longitude != 0.0) {
        try {
          final apiKey = AppConfig.googleMapsApiKey;
          final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/timezone/json'
            '?location=$latitude,$longitude'
            '&timestamp=$nowUnixSeconds'
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

              // Addiere Offset zu UTC-Zeit um lokale Party-Zeit zu bekommen
              final partyLocalTime = nowUtc.add(Duration(seconds: totalOffset));

              debugLog(
                '   ✅ Aktuelle Zeit in Party-Zeitzone berechnet: ${partyLocalTime.year}-${partyLocalTime.month.toString().padLeft(2, '0')}-${partyLocalTime.day.toString().padLeft(2, '0')} ${partyLocalTime.hour.toString().padLeft(2, '0')}:${partyLocalTime.minute.toString().padLeft(2, '0')} (Offset: ${totalOffset}s = ${totalOffset ~/ 3600}h)',
              );
              return partyLocalTime;
            }
          }
        } catch (e) {
          debugLog(
            '⚠️ Google Time Zone API Fehler bei Validierung, verwende Fallback: $e',
          );
        }
      }

      // Fallback: Verwende System-Zeitzone (nicht perfekt, aber funktional)
      // Dies wird verwendet wenn keine Koordinaten vorhanden sind
      final fallbackTime = DateTime.now(); // System-Zeitzone
      debugLog(
        '   ⚠️ Fallback für Validierung (System-Zeitzone): ${fallbackTime.year}-${fallbackTime.month.toString().padLeft(2, '0')}-${fallbackTime.day.toString().padLeft(2, '0')} ${fallbackTime.hour.toString().padLeft(2, '0')}:${fallbackTime.minute.toString().padLeft(2, '0')}',
      );
      return fallbackTime;
    } catch (e) {
      debugLog('❌ Fehler bei Berechnung der aktuellen Zeit in Party-Zeitzone: $e');
      // Letzter Fallback: System-Zeit
      return DateTime.now();
    }
  }

  /// Konvertiert lokale Zeit zu UTC Unix-Timestamp (in Sekunden seit Epoch)
  /// Nutzt Google Time Zone API für präzise Offset-Berechnung
  /// WICHTIG: Diese Funktion ist kritisch für den Cronjob - muss absolut präzise sein
  static Future<int> _convertLocalTimeToUnixTimestamp(
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
      debugLog('❌ Fehler bei Zeitzonen-Konvertierung: $e');
      // Letzter Fallback: Direkte UTC-Konvertierung
      final utcDateTime = localDateTime.toUtc();
      return utcDateTime.millisecondsSinceEpoch ~/ 1000;
    }
  }
}
