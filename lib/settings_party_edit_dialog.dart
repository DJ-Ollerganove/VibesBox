import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_auth/firebase_auth.dart';
import 'l10n/app_localizations.dart';
import 'utils/formatting_utils.dart';
import 'utils/ui_constants.dart';
import 'utils/party_validator.dart';
import 'config/app_config.dart';
import 'services/user_service.dart';
import 'helpers/security_helper.dart';
import 'models/location_result.dart';
import 'pages/location_edit_picker_page.dart';
import 'widgets/party_creation/party_time_dropdowns.dart';
import 'utils/debug_log.dart';

/// Dialog für die Bearbeitung einer Party
class SettingsPartyEditDialog {
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

    try {
      partyDoc = await FirebaseFirestore.instance
          .collection('parties')
          .doc(partyId)
          .get();

      if (partyDoc.exists) {
        final data = partyDoc.data() as Map<String, dynamic>?;
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

    if (guestLimit == null || userLimit == null) {
      try {
        // Nutze bereits geladenes Party-Dokument (falls vorhanden)
        if (partyDoc != null && partyDoc.exists) {
          final data = partyDoc.data() as Map<String, dynamic>?;
          guestLimit = data?['guest_limit_per_hour'] as int? ?? 2;
          userLimit = data?['user_limit_per_hour'] as int? ?? 5;
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

    // Free-DJ: Limits fest auf 1 (auch beim Bearbeiten – zurücksetzen und sperren)
    final editUser = UserService().currentUser.value;
    final isFreeEdit = editUser != null && editUser.isFree;
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

    // Bearbeitbare Location- und Zeitzonen-Daten (können per "Ort ändern" aktualisiert werden)
    final locName = partyLocationName?.trim();
    final locNameValid =
        locName != null &&
        locName.isNotEmpty &&
        locName != l10n.location_not_specified;
    String editLocationName = locNameValid
        ? partyLocationName!
        : l10n.location_not_specified;
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

              // Validierung: Endzeit > Startzeit (Korrektur in setDialogState)
              void correctEndTimeIfNeeded() {
                if (startDate == null ||
                    startHour == null ||
                    startMinute == null ||
                    endDate == null ||
                    endHour == null ||
                    endMinute == null)
                  return;
                final corrected = PartyTimeHelpers.correctEndIfBeforeStart(
                  startDate!,
                  startHour!,
                  startMinute!,
                  endDate!,
                  endHour!,
                  endMinute!,
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
                return PartyValidator.validate(
                  newStartDateTime,
                  newEndDateTime,
                  allParties: parties,
                  currentPartyId: currentPartyId,
                  isAdmin: isAdmin,
                  context: context,
                );
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
              final isValid =
                  validationError == null &&
                  startDate != null &&
                  startHour != null &&
                  startMinute != null &&
                  endDate != null &&
                  endHour != null &&
                  endMinute != null &&
                  selectedGuestLimit != null &&
                  selectedUserLimit != null;
              return Directionality(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: Dialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  backgroundColor: Colors.transparent,
                  child: Container(
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
                        // Titel-Zeile
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            l10n.edit_party,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
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
                                  // Party-Name (nur bearbeitbar wenn noch nicht begonnen)
                                  if (hasNotStarted) ...[
                                    TextFormField(
                                      controller: partyNameController,
                                      maxLength: 100,
                                      decoration: InputDecoration(
                                        labelText: l10n.party_name_label,
                                        border: const OutlineInputBorder(),
                                      ),
                                      enabled: hasNotStarted,
                                    ),
                                    const SizedBox(height: 16),
                                  ] else ...[
                                    Text(
                                      '${l10n.party_name_display} $currentPartyName',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
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
                                        Text(
                                          editLocationName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
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
                                                                  locNameValid
                                                                  ? editLocationName
                                                                  : null,
                                                            ),
                                                      ),
                                                    );
                                                if (result != null &&
                                                    context.mounted) {
                                                  setDialogState(() {
                                                    // Namen nur übernehmen wenn expliziter POI (nicht Adresse/Straße/Ort)
                                                    final n = result.name
                                                        .trim();
                                                    final a = result.address
                                                        .trim()
                                                        .toLowerCase();
                                                    final s =
                                                        (result.street ?? '')
                                                            .trim()
                                                            .toLowerCase();
                                                    final c =
                                                        (result.city ?? '')
                                                            .trim()
                                                            .toLowerCase();
                                                    final isExplicit =
                                                        n.isNotEmpty &&
                                                        n.toLowerCase() != a &&
                                                        (s.isEmpty ||
                                                            n.toLowerCase() !=
                                                                s) &&
                                                        (c.isEmpty ||
                                                            n.toLowerCase() !=
                                                                c);
                                                    editLocationName = isExplicit
                                                        ? result.name
                                                        : '';
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
                                            if (_partyHasPersistableLocation(
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
                                  const SizedBox(height: 16),
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
                                                              ? intl.DateFormat.yMd(
                                                                  Localizations.localeOf(
                                                                    context,
                                                                  ).toString(),
                                                                ).format(startDate!)
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
                                                final picked =
                                                    await showDatePicker(
                                                      context: context,
                                                      initialDate:
                                                          endDate ??
                                                          currentEndDate,
                                                      firstDate: hasNotStarted
                                                          ? (startDate ??
                                                                currentStartDate)
                                                          : currentStartDate,
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
                                                  correctEndTimeIfNeeded();
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
                                                            ? intl.DateFormat.yMd(
                                                                Localizations.localeOf(
                                                                  context,
                                                                ).toString(),
                                                              ).format(endDate!)
                                                            : l10n.party_not_selected,
                                                        style: const TextStyle(
                                                          fontSize: 14,
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
                                                    startDate,
                                                    startHour,
                                                    startMinute,
                                                    endDate,
                                                  ),
                                              availableMinutes:
                                                  PartyTimeHelpers.getAvailableEndMinutes(
                                                    startDate,
                                                    startHour,
                                                    startMinute,
                                                    endDate,
                                                    endHour,
                                                  ),
                                              enabled: endDate != null,
                                              labelHour: l10n.select_hour,
                                              labelMinute: l10n.select_minute,
                                              onChanged: (h, m) {
                                                setDialogState(() {
                                                  endHour = h;
                                                  endMinute = m;
                                                });
                                                correctEndTimeIfNeeded();
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
                                  // Wunsch-Limits (immer bearbeitbar)
                                  const SizedBox(height: 16),
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
                                            labelText: l10n.party_user_limit,
                                            border: const OutlineInputBorder(),
                                            prefixIcon: Icon(
                                              Icons.person,
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
                              ),
                            ),
                          ),
                        ),
                        // Buttons unten
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Colors.white70,
                                    width: 1,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  l10n.party_cancel,
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                key: const Key('party_save'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isValid
                                      ? Colors.green
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: isValid
                                    ? () async {
                                        DateTime newStartDateTime =
                                            currentStartDate;
                                        if (hasNotStarted) {
                                          if (startDate == null ||
                                              startHour == null ||
                                              startMinute == null) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
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
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
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
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
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
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
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
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
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

                                        try {
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
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
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
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
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
                                            locationNameToSave =
                                                (editLocationName
                                                        .trim()
                                                        .isEmpty ||
                                                    editLocationName ==
                                                        locNotSpecified)
                                                ? null
                                                : editLocationName.trim();
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
                                          final updateData = <String, dynamic>{
                                            'end_time_posix': newEndTimePosix,
                                            'end_date':
                                                Timestamp.fromMillisecondsSinceEpoch(
                                                  newEndTimePosix * 1000,
                                                ),
                                            'timezone_id': editTimezoneId,
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
                                            updateData['party_name'] =
                                                _sanitizeInput(
                                                  partyNameController.text
                                                      .trim(),
                                                );
                                            // Party-Typ wird nicht mehr geändert (deaktiviert)
                                            updateData['start_time_posix'] =
                                                newStartTimePosix; // Unix-Timestamp in UTC (Sekunden) - PRÄZISE für Cronjob
                                            updateData['start_date'] =
                                                Timestamp.fromMillisecondsSinceEpoch(
                                                  newStartTimePosix! * 1000,
                                                ); // Abgeleitet vom POSIX-Wert
                                          }

                                          await FirebaseFirestore.instance
                                              .collection('parties')
                                              .doc(partyId)
                                              .update(
                                                SecurityHelper.sanitizeMap(
                                                  updateData,
                                                ),
                                              );

                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  l10n.party_updated_success,
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${l10n.party_error_updating} $e',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    : null,
                                child: Text(
                                  l10n.party_save,
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
