import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'l10n/app_localizations.dart';
import 'utils/formatting_utils.dart';
import 'utils/ui_constants.dart';
import 'widgets/common/pwa_widget_cell.dart';
import 'utils/calendar_export_helper.dart';
import 'widgets/party_status_badge.dart';
import 'utils/debug_log.dart';

/// Widget für eine einzelne Party-Karte
class SettingsPartyCard extends StatefulWidget {
  final String partyId;
  final String partyName;
  final DateTime startDate;
  final DateTime endDate;
  final String? partyCode;
  final String status;
  final Color statusColor;
  final bool hasNotStarted;
  final Stream<DateTime> timeStream;
  final String Function(DateTime date, BuildContext? context) formatDateTime;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onQrCode;
  final VoidCallback? onPause;
  final VoidCallback? onEnd;
  final bool? isPaused;
  final String? locationName;
  final String? locationStreet;
  final String? locationZip;
  final String? locationCity;
  final String? timezoneId;
  final int? startTimePosix;
  final int? endTimePosix;
  final double? latitude;
  final double? longitude;
  final bool hideActions; // Versteckt Bearbeiten/Löschen-Buttons
  final bool hideCalendarExport; // Versteckt Kalender-Export-Button
  final bool hideMapsLink; // Versteckt Maps-Link (nur Text anzeigen)
  final bool hideBorder; // Versteckt den orangen Rahmen (wenn Card bereits in PwaWidgetCell ist)
  /// Optional: Rahmenfarbe der PwaWidgetCell (z.B. partyYellow in Party-Verwaltung)
  final Color? borderColor;
  /// True = Karte deaktiviert (z. B. Free-DJ-Limit erreicht, zukünftige Party nicht nutzbar)
  final bool isDeactivated;

  const SettingsPartyCard({
    super.key,
    required this.partyId,
    required this.partyName,
    required this.startDate,
    required this.endDate,
    this.partyCode,
    required this.status,
    required this.statusColor,
    required this.hasNotStarted,
    required this.timeStream,
    required this.formatDateTime,
    required this.onEdit,
    this.onDelete,
    required this.onQrCode,
    this.onPause,
    this.onEnd,
    this.isPaused,
    this.locationName,
    this.locationStreet,
    this.locationZip,
    this.locationCity,
    this.timezoneId,
    this.startTimePosix,
    this.endTimePosix,
    this.latitude,
    this.longitude,
    this.hideActions = false,
    this.hideCalendarExport = false,
    this.hideMapsLink = false,
    this.hideBorder = false,
    this.borderColor,
    this.isDeactivated = false,
  });

  @override
  State<SettingsPartyCard> createState() => _SettingsPartyCardState();
}

class _SettingsPartyCardState extends State<SettingsPartyCard> {
  bool _timezoneInitialized = false;

  /// Zeige Location-Zeile bei echtem Ort (Name, Straße oder PLZ/Ort vorhanden).
  bool get _hasValidLocation {
    final name = widget.locationName?.trim();
    final street = widget.locationStreet?.trim();
    final zip = widget.locationZip?.trim();
    final city = widget.locationCity?.trim();
    if (name != null && name.isNotEmpty && name != 'Vom DJ nicht angegeben') return true;
    if (street != null && street.isNotEmpty) return true;
    return (zip != null && zip.isNotEmpty) || (city != null && city.isNotEmpty);
  }

  /// Prüft, ob der Name kein Duplikat von Straße oder Ort ist (zeigt ihn dann nicht separat).
  bool _isExplicitLocationName(String? name, String? street, String? city) {
    if (name == null || name.trim().isEmpty) return false;
    final n = name.trim().toLowerCase();
    final s = (street ?? '').trim().toLowerCase();
    final c = (city ?? '').trim().toLowerCase();
    if (s.isNotEmpty && n == s) return false;
    if (c.isNotEmpty && n == c) return false;
    return true;
  }

  /// Baut die Location-Anzeige als eine Zeile (z. B. "Musterstraße 1, 12345 Stadt").
  /// Name nur wenn expliziter POI (kein Duplikat von Straße/Ort). Kein künstlicher Umbruch mit \\n.
  /// [dimColor]: bei Standby-Karte für gedimmte Darstellung (z. B. white60).
  Widget _buildLocationText({Color? dimColor}) {
    final name = widget.locationName?.trim();
    final street = widget.locationStreet?.trim();
    final zip = widget.locationZip?.trim();
    final city = widget.locationCity?.trim();
    final showName = name != null && name.isNotEmpty && _isExplicitLocationName(name, street, city);
    final zipCityPart = [if (zip != null && zip.isNotEmpty) zip, if (city != null && city.isNotEmpty) city].join(' ').trim();
    final addressPart = [
      if (street != null && street.isNotEmpty) street,
      if (zipCityPart.isNotEmpty) zipCityPart,
    ].join(', ');
    final locationLine = showName && addressPart.isNotEmpty
        ? '$name · $addressPart'
        : showName
            ? name!
            : addressPart;
    if (locationLine.isEmpty) return const SizedBox.shrink();

    final color = dimColor ?? Colors.blue;
    final style = TextStyle(fontSize: 12, color: color);
    final styleUnderline = TextStyle(
      fontSize: 12,
      color: color,
      decoration: TextDecoration.underline,
      decorationColor: color,
    );
    if (widget.hideMapsLink) {
      return Text(
        locationLine,
        style: style,
        overflow: TextOverflow.ellipsis,
        maxLines: 3,
      );
    }
    return GestureDetector(
      onTap: () => _openGoogleMaps(),
      child: Text(
        locationLine,
        style: styleUnderline,
        overflow: TextOverflow.ellipsis,
        maxLines: 3,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeTimezone();
  }

  Future<void> _initializeTimezone() async {
    if (!_timezoneInitialized) {
      tz.initializeTimeZones();
      _timezoneInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prüfe über StreamBuilder, ob die Party beendet ist
    return StreamBuilder<DateTime>(
      stream: widget.timeStream,
      builder: (context, timeSnapshot) {
        final l10n = AppLocalizations.of(context)!;
        final now = timeSnapshot.data ?? DateTime.now();
        
        // Wenn die Party beendet ist, zeige nichts
        if (now.isAfter(widget.endDate)) {
          return const SizedBox.shrink();
        }
        
        // Bei deaktivierter Karte: alle Texte/Icons gedimmt (white60) für Lesbarkeit
        final dimColor = widget.isDeactivated ? Colors.white60 : null;
        // Definiere den Inhalt der Karte (ohne Rahmen)
        final cardContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
                // Header-Sektion: Party-Name links + Aktions-Buttons rechts (Bearbeiten/Löschen + QR-Code)
                Row(
                  children: [
                    // Links: Party-Name (nimmt restlichen Platz) - GRÜN / gedimmt bei Standby
                    Expanded(
                      child: Text(
                        widget.partyName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: dimColor ?? Colors.greenAccent,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    // Rechts: Aktions-Buttons (nur wenn nicht versteckt und nicht deaktiviert)
                    if (!widget.hideActions && !widget.isDeactivated) ...[
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pause/Play-Button (nur wenn Callback vorhanden)
                          if (widget.onPause != null)
                            IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              icon: Icon((widget.isPaused ?? false) ? Icons.play_arrow : Icons.pause),
                              color: UIConstants.appOrange,
                              onPressed: widget.onPause,
                              tooltip: (widget.isPaused ?? false)
                                  ? l10n.party_resume
                                  : l10n.party_pause,
                            ),
                          // Stop-Button (nur wenn Callback vorhanden)
                          if (widget.onEnd != null)
                            IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              icon: const Icon(Icons.stop),
                              color: Colors.red,
                              onPressed: widget.onEnd,
                              tooltip: l10n.party_end,
                            ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            icon: const Icon(Icons.edit),
                            color: Colors.white,
                            onPressed: widget.onEdit,
                            tooltip: l10n.party_edit,
                          ),
                          // Lösch-Button (nur wenn Callback vorhanden)
                          if (widget.onDelete != null)
                            IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              icon: const Icon(Icons.delete),
                              color: Colors.red,
                              onPressed: widget.onDelete,
                              tooltip: l10n.party_delete,
                            ),
                          const SizedBox(width: 4),
                          // QR-Code Icon (ganz rechts)
                          if (widget.partyCode != null)
                            IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              icon: const Icon(Icons.qr_code),
                              color: Colors.white,
                              onPressed: widget.onQrCode,
                              tooltip: l10n.show_qr_code,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 6),
                
                // Location-Anzeige nur bei echtem Ort (nicht Platzhalter, nicht leer)
                if (_hasValidLocation) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: dimColor ?? Colors.blue,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _buildLocationText(dimColor: dimColor),
                      ),
                    ],
                  ),
                ],

                // Absolute Zeiten: WEISS = Ortszeit der Party, ROT = Gerätezeit des DJs
                FutureBuilder<Map<String, String?>>(
                  future: _calculatePartyTimes(context),
                  builder: (context, timesSnapshot) {
                    if (!timesSnapshot.hasData) {
                      // Fallback: Zeige normale Formatierung
                      final startTimeFormatted =
                          _formatDateCompact(widget.startDate, context);
                      final endTimeFormatted =
                          _formatDateCompact(widget.endDate, context);
                      return RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 12, color: dimColor ?? Colors.white),
                          children: [
                            TextSpan(text: startTimeFormatted),
                            const TextSpan(text: ' - '),
                            TextSpan(text: endTimeFormatted),
                          ],
                        ),
                      );
                    }
                    
                    final times = timesSnapshot.data!;
                    final startPartyTime = times['startPartyTime'] ?? '';
                    final startDeviceTime = times['startDeviceTime'];
                    final endPartyTime = times['endPartyTime'] ?? '';
                    final endDeviceTime = times['endDeviceTime'];
                    
                    return RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: dimColor ?? Colors.white,
                        ),
                        children: [
                          // Startzeit WEISS (Ortszeit der Party)
                          TextSpan(text: startPartyTime),
                          // Startzeit ROT (Gerätezeit des DJs) - nur wenn unterschiedlich
                          if (startDeviceTime != null && startDeviceTime.isNotEmpty)
                            TextSpan(
                              text: ' ($startDeviceTime)',
                              style: TextStyle(color: dimColor ?? Colors.red),
                            ),
                          // Trenner
                          const TextSpan(text: ' - '),
                          // Endzeit WEISS (Ortszeit der Party)
                          TextSpan(text: endPartyTime),
                          // Endzeit ROT (Gerätezeit des DJs) - nur wenn unterschiedlich
                          if (endDeviceTime != null && endDeviceTime.isNotEmpty)
                            TextSpan(
                              text: ' ($endDeviceTime)',
                              style: TextStyle(color: dimColor ?? Colors.red),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                // Kalender-Export Button (nur wenn nicht versteckt und nicht deaktiviert)
                if (!widget.hideCalendarExport && !widget.isDeactivated) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      // Erstelle Map mit Party-Daten für den Helper
                      final partyData = <String, dynamic>{
                        'party_name': widget.partyName,
                        'start_time_posix': widget.startTimePosix,
                        'end_time_posix': widget.endTimePosix,
                        'timezone_id': widget.timezoneId,
                        'latitude': widget.latitude,
                        'longitude': widget.longitude,
                        'location_name': widget.locationName,
                      };
                      CalendarExportHelper.exportParty(partyData, context);
                    },
                    icon: Icon(Icons.calendar_today, size: 16, color: dimColor ?? Colors.blue),
                    label: Text(
                      l10n.party_calendar_export,
                      style: TextStyle(fontSize: 12, color: dimColor ?? Colors.blue),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                // Nur dieses Badge tickt pro Sekunde; Liste und Karte bleiben stabil
                PartyStatusBadge(
                  startDate: widget.startDate,
                  endDate: widget.endDate,
                  startTimePosix: widget.startTimePosix,
                  status: widget.status,
                ),
              ],
            );
        
        // Deaktivierte Karte: voll deckend, scharf, grey[900]-Hintergrund, Standby-Badge, ClipRRect gegen Scroll-Artefakte
        final content = widget.isDeactivated
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  cardContent,
                  // Standby-Badge oben rechts
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'STANDBY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : cardContent;
        // Karten-Container: bei Standby grey[900] + Rahmen, sonst PwaWidgetCell
        Widget card = Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: widget.isDeactivated
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.borderColor ?? UIConstants.appOrange,
                        width: 2,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: content,
                    ),
                  )
                : (widget.hideBorder
                    ? content
                    : PwaWidgetCell(
                        borderColor: widget.borderColor,
                        child: content,
                      )),
          ),
        );
        if (widget.isDeactivated) {
          card = InkWell(
            onTap: () => _showStandbyInfoDialog(context),
            borderRadius: BorderRadius.circular(12),
            child: card,
          );
        }
        return card;
      },
    );
  }

  void _showStandbyInfoDialog(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          l.party_standby_info_title,
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Text(
            l.party_standby_info_text,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l.close,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  /// Berechnet die Party-Zeiten: Ortszeit (WEISS) und Gerätezeit (ROT)
  /// Gibt Map zurück mit: startPartyTime, startDeviceTime, endPartyTime, endDeviceTime
  Future<Map<String, String?>> _calculatePartyTimes(BuildContext context) async {
    String partyLine(DateTime d) {
      if (!context.mounted) {
        return FormattingUtils.formatCompactDateTimeWithoutContext(d);
      }
      return _formatDateCompact(d, context);
    }

    String deviceTimeLine(DateTime d) {
      if (!context.mounted) {
        return FormattingUtils.formatShortTimeWithoutContext(d);
      }
      return FormattingUtils.formatTime(d, context);
    }

    try {
      if (!_timezoneInitialized) {
        await _initializeTimezone();
      }

      // Fallback-Werte
      String startPartyTime = partyLine(widget.startDate);
      String endPartyTime = partyLine(widget.endDate);
      String? startDeviceTime;
      String? endDeviceTime;
      
      // Prüfe ob wir genug Daten haben für präzise Berechnung
      if (widget.startTimePosix != null && 
          widget.endTimePosix != null &&
          widget.timezoneId != null && 
          widget.timezoneId!.isNotEmpty &&
          widget.startTimePosix! > 0 &&
          widget.endTimePosix! > 0) {
        
        try {
          // WEISSE SCHRIFT: Ortszeit der Party (basierend auf timezone_id)
          final partyLocation = tz.getLocation(widget.timezoneId!);
          
          // Startzeit in Party-Zeitzone
          final startPartyTZ = tz.TZDateTime.fromMillisecondsSinceEpoch(
            partyLocation, 
            widget.startTimePosix! * 1000
          );
          // Konvertiere TZDateTime zu DateTime für Formatierung
          startPartyTime = partyLine(DateTime(
            startPartyTZ.year,
            startPartyTZ.month,
            startPartyTZ.day,
            startPartyTZ.hour,
            startPartyTZ.minute,
          ));
          
          // Endzeit in Party-Zeitzone
          final endPartyTZ = tz.TZDateTime.fromMillisecondsSinceEpoch(
            partyLocation, 
            widget.endTimePosix! * 1000
          );
          // Konvertiere TZDateTime zu DateTime für Formatierung
          endPartyTime = partyLine(DateTime(
            endPartyTZ.year,
            endPartyTZ.month,
            endPartyTZ.day,
            endPartyTZ.hour,
            endPartyTZ.minute,
          ));
          
          // ROTE SCHRIFT: Gerätezeit des DJs (mit .toLocal())
          final startUtcDateTime = DateTime.fromMillisecondsSinceEpoch(
            widget.startTimePosix! * 1000, 
            isUtc: true
          );
          final startLocalDateTime = startUtcDateTime.toLocal();
          
          final endUtcDateTime = DateTime.fromMillisecondsSinceEpoch(
            widget.endTimePosix! * 1000, 
            isUtc: true
          );
          final endLocalDateTime = endUtcDateTime.toLocal();
          
          // Berechne Offsets für Vergleich
          final startPartyOffset = startPartyTZ.timeZoneOffset.inMilliseconds;
          final startDeviceOffset = startLocalDateTime.timeZoneOffset.inMilliseconds;
          final endPartyOffset = endPartyTZ.timeZoneOffset.inMilliseconds;
          final endDeviceOffset = endLocalDateTime.timeZoneOffset.inMilliseconds;
          
          // Zeige Gerätezeit nur wenn Offset unterschiedlich ist
          if (startPartyOffset != startDeviceOffset) {
            startDeviceTime = deviceTimeLine(startLocalDateTime);
          }

          if (endPartyOffset != endDeviceOffset) {
            endDeviceTime = deviceTimeLine(endLocalDateTime);
          }
          
        } catch (e) {
          debugLog('⚠️ Fehler bei Party-Zeit-Berechnung: $e');
          // Fallback auf normale Formatierung
        }
      }
      
      return {
        'startPartyTime': startPartyTime,
        'startDeviceTime': startDeviceTime,
        'endPartyTime': endPartyTime,
        'endDeviceTime': endDeviceTime,
      };
    } catch (e) {
      debugLog('❌ Fehler in _calculatePartyTimes: $e');
      // Fallback
      return {
        'startPartyTime': partyLine(widget.startDate),
        'startDeviceTime': null,
        'endPartyTime': partyLine(widget.endDate),
        'endDeviceTime': null,
      };
    }
  }

  /// Gibt nur die formatierte lokale Zeit zurück (HH:mm), wenn Zeitzonen unterschiedlich sind
  /// Gibt null zurück wenn Zeitzonen gleich sind
  Future<String?> _getLocalTimeFormatted(int startTimePosix, String timezoneId) async {
    try {
      // Null-Sicherheit: Prüfe ob Daten vorhanden sind
      if (startTimePosix <= 0 || timezoneId.isEmpty) {
        return null;
      }

      if (!_timezoneInitialized) {
        await _initializeTimezone();
      }

      // Berechne UTC DateTime aus startTimePosix
      final utcDateTime = DateTime.fromMillisecondsSinceEpoch(startTimePosix * 1000, isUtc: true);
      
      // Berechne Party-Offset unter Verwendung der timezoneId
      int partyOffsetMillis;
      try {
        final partyLocation = tz.getLocation(timezoneId);
        final partyTZDateTime = tz.TZDateTime.fromMillisecondsSinceEpoch(partyLocation, startTimePosix * 1000);
        final partyOffset = partyTZDateTime.timeZoneOffset;
        partyOffsetMillis = partyOffset.inMilliseconds;
      } catch (e) {
        debugLog('⚠️ Fehler beim Abrufen der Party-Zeitzone "$timezoneId": $e');
        partyOffsetMillis = 0;
      }
      
      // Berechne Geräte-Offset
      final localTime = utcDateTime.toLocal();
      final deviceOffset = localTime.timeZoneOffset;
      final deviceOffsetMillis = deviceOffset.inMilliseconds;
      
      // Prüfe ob Offsets gleich sind
      if (partyOffsetMillis == deviceOffsetMillis) {
        return null; // Offsets sind gleich - keine Anzeige
      }
      
      // Offsets sind unterschiedlich - formatiere lokale Zeit
      final localFormatted = DateFormat('HH:mm').format(localTime);
      return localFormatted;
      
    } catch (e) {
      debugLog('⚠️ Fehler bei Zeitanzeige: $e');
      return null;
    }
  }

  /// Berechnet die lokale Zeit nur wenn sie sich von der Party-Zeitzone unterscheidet
  /// Gibt null zurück wenn Zeitzonen gleich sind
  /// DEPRECATED: Wird nicht mehr verwendet, aber für Kompatibilität behalten
  @Deprecated('Use _getLocalTimeFormatted instead')
  Future<String?> _calculateLocalTimeIfDifferent(int startTimePosix, String timezoneId) async {
    try {
      // Null-Sicherheit: Prüfe ob Daten vorhanden sind
      if (startTimePosix <= 0 || timezoneId.isEmpty) {
        return null;
      }

      if (!_timezoneInitialized) {
        await _initializeTimezone();
      }

      // Ermittle lokale Zeitzone des Geräts
      final systemTZName = DateTime.now().timeZoneName;
      final systemTZOffset = DateTime.now().timeZoneOffset;
      final offsetHours = systemTZOffset.inHours;
      final offsetMinutes = systemTZOffset.inMinutes % 60;
      
      // Ermittle IANA-Name für lokale Zeitzone
      // VERBOT: Kein 'UTC' in der Anzeige - immer Mapping verwenden
      String localTZName;
      
      // PRIORITÄT 1: Nutze tz.local.name wenn verfügbar und gültig
      try {
        final localTZ = tz.local;
        final tzLocalName = localTZ.name;
        if (tzLocalName.isNotEmpty && 
            tzLocalName != 'Local' && 
            tzLocalName.toLowerCase() != 'utc') {
          localTZName = tzLocalName;
          debugLog('   ✅ Nutze tz.local.name: "$localTZName"');
        } else {
          throw Exception('tz.local.name invalid or UTC');
        }
      } catch (e) {
        debugLog('   ⚠️ tz.local.name nicht verfügbar, nutze Mapping: $e');
        
        // PRIORITÄT 2: System-Mapping basierend auf Offset und System-Name
        // Hartes Mapping für CET/GMT+1/etc. → Europe/Berlin
        if (systemTZName.contains('CET') || 
            systemTZName.contains('CEST') || 
            systemTZName.contains('GMT+1') ||
            systemTZName.contains('GMT+2') ||
            systemTZName == 'MEZ' ||
            systemTZName == 'MESZ' ||
            offsetHours == 1 || 
            offsetHours == 2) {
          localTZName = 'Europe/Berlin';
          debugLog('   ✅ Mapping zu: Europe/Berlin (Offset: ${offsetHours}h)');
        } else if (offsetHours == 0 && (systemTZName.contains('GMT') || systemTZName.contains('UTC'))) {
          localTZName = 'Europe/London';
          debugLog('   ✅ Mapping zu: Europe/London (GMT/UTC, Offset: 0h)');
        } else if (offsetHours == 0) {
          localTZName = 'Europe/London';
          debugLog('   ✅ Mapping zu: Europe/London (Offset: 0h)');
        } else if (offsetHours == -5) {
          localTZName = 'America/New_York';
          debugLog('   ✅ Mapping zu: America/New_York (Offset: -5h)');
        } else if (offsetHours == -8) {
          localTZName = 'America/Los_Angeles';
          debugLog('   ✅ Mapping zu: America/Los_Angeles (Offset: -8h)');
        } else if (offsetHours == 9) {
          localTZName = 'Asia/Tokyo';
          debugLog('   ✅ Mapping zu: Asia/Tokyo (Offset: +9h)');
        } else if (offsetHours == 3) {
          localTZName = 'Europe/Moscow';
          debugLog('   ✅ Mapping zu: Europe/Moscow (Offset: +3h)');
        } else {
          // PRIORITÄT 3: Nutze System-Name direkt (wenn nicht GMT/UTC/null)
          if (systemTZName.isNotEmpty && 
              !systemTZName.startsWith('GMT') && 
              !systemTZName.startsWith('UTC') &&
              systemTZName.toLowerCase() != 'null' &&
              systemTZName != 'Local') {
            localTZName = systemTZName;
            debugLog('   ✅ Nutze System-Name direkt: "$systemTZName"');
          } else {
            // PRIORITÄT 4: Generiere Offset-String statt UTC
            // VERBOT: Kein "UTC" wenn Offset vorhanden
            if (offsetHours != 0 || offsetMinutes != 0) {
              localTZName = 'UTC${offsetHours >= 0 ? '+' : ''}$offsetHours${offsetMinutes != 0 ? ':$offsetMinutes' : ''}';
              debugLog('   ⚠️ Generiere Offset-String: "$localTZName" (kein Mapping gefunden)');
            } else {
              // Nur wenn wirklich UTC (Offset 0)
              localTZName = 'UTC';
              debugLog('   ⚠️ UTC verwendet (Offset 0h)');
            }
          }
        }
      }
      
      // FINAL CHECK: Stelle sicher, dass nie "UTC" angezeigt wird wenn Offset vorhanden
      if (localTZName == 'UTC' && (offsetHours != 0 || offsetMinutes != 0)) {
        // Fallback: Nutze Offset-String
        localTZName = 'UTC${offsetHours >= 0 ? '+' : ''}$offsetHours${offsetMinutes != 0 ? ':$offsetMinutes' : ''}';
        debugLog('   ⚠️ VERBOT verhindert: UTC → Offset-String: "$localTZName"');
      }
      
      // Berechne UTC DateTime aus startTimePosix
      final utcDateTime = DateTime.fromMillisecondsSinceEpoch(startTimePosix * 1000, isUtc: true);
      
      // Berechne Party-Offset unter Verwendung der timezoneId
      int partyOffsetMillis;
      try {
        final partyLocation = tz.getLocation(timezoneId);
        final partyTZDateTime = tz.TZDateTime.fromMillisecondsSinceEpoch(partyLocation, startTimePosix * 1000);
        // Berechne Offset: Differenz zwischen UTC und Party-Zeit
        final partyOffset = partyTZDateTime.timeZoneOffset;
        partyOffsetMillis = partyOffset.inMilliseconds;
      } catch (e) {
        // Fallback: Wenn Zeitzone nicht gefunden wird, nutze UTC (Offset 0)
        debugLog('⚠️ Fehler beim Abrufen der Party-Zeitzone "$timezoneId": $e');
        partyOffsetMillis = 0;
      }
      
      // Berechne Geräte-Offset
      final localTime = utcDateTime.toLocal();
      final deviceOffset = localTime.timeZoneOffset;
      final deviceOffsetMillis = deviceOffset.inMilliseconds;
      
      // DEBUG: Zeige Offset-Vergleich
      debugLog('🔍 DEBUG: Offset-Vergleich für Party: $timezoneId');
      debugLog('   Party-Offset: $partyOffsetMillis ms (${partyOffsetMillis ~/ 1000 ~/ 60} Minuten)');
      debugLog('   Geräte-Offset: $deviceOffsetMillis ms (${deviceOffsetMillis ~/ 1000 ~/ 60} Minuten)');
      debugLog('   Offsets gleich: ${partyOffsetMillis == deviceOffsetMillis}');
      
      // Prüfe ob Offsets gleich sind
      if (partyOffsetMillis == deviceOffsetMillis) {
        // Offsets sind gleich - keine Anzeige
        debugLog('   ✅ Zeitzonen haben gleichen Offset - keine Anzeige');
        return null;
      }
      
      // Offsets sind unterschiedlich - berechne und zeige lokale Zeit
      debugLog('   ✅ Zeitzonen haben unterschiedliche Offsets - zeige "Meine Zeit"');
      final localFormatted = DateFormat('HH:mm').format(localTime);
      
      return '🏠 Meine Zeit: $localFormatted ($localTZName)';
      
    } catch (e) {
      // Bei Fehler: Keine Anzeige statt Absturz
      debugLog('⚠️ Fehler bei Zeitanzeige: $e');
      return null;
    }
  }

  /// Berechnet die Dual-Time-Anzeige (lokale Zeit vs Event-Zeit) - DEPRECATED
  /// Wird nicht mehr verwendet, aber für Debug-Zwecke behalten
  @Deprecated('Use _calculateLocalTimeIfDifferent instead')
  Future<Map<String, String>> _calculateDualTimes(int startTimePosix, String timezoneId) async {
    debugLog('═══════════════════════════════════════════════════════');
    debugLog('🔍 SCHRITT 0: Start Zeitzonen-Analyse');
    debugLog('═══════════════════════════════════════════════════════');
    
    try {
      // Prüfe Initialisierung
      debugLog('📋 SCHRITT 0.1: Prüfe Timezone-Initialisierung');
      debugLog('   _timezoneInitialized: $_timezoneInitialized');
      
      if (!_timezoneInitialized) {
        debugLog('   ⚠️ Nicht initialisiert, rufe _initializeTimezone() auf...');
        await _initializeTimezone();
        debugLog('   ✅ Initialisierung abgeschlossen');
      } else {
        debugLog('   ✅ Bereits initialisiert');
      }

      // startTimePosix ist in Sekunden (Unix-Timestamp)
      // Konvertiere zu UTC DateTime
      final utcDateTime = DateTime.fromMillisecondsSinceEpoch(startTimePosix * 1000, isUtc: true);

      // Lokale Zeit (Smartphone-Zeitzone) - konvertiere UTC zu lokaler Zeit
      final localTime = utcDateTime.toLocal();
      
      debugLog('📋 SCHRITT 1: System-Abfrage (DateTime.now())');
      debugLog('═══════════════════════════════════════════════════════');
      
      // SCHRITT 1: System-Abfrage
      final systemTZName = DateTime.now().timeZoneName;
      final systemTZOffset = DateTime.now().timeZoneOffset;
      final offsetHours = systemTZOffset.inHours;
      final offsetMinutes = systemTZOffset.inMinutes % 60;
      
      debugLog('   DateTime.now().timeZoneName: "$systemTZName"');
      debugLog('   DateTime.now().timeZoneOffset: ${offsetHours}h ${offsetMinutes}m');
      debugLog('   Offset in Stunden: $offsetHours');
      debugLog('   Offset in Minuten: ${systemTZOffset.inMinutes}');
      
      // Prüfe ob GMT+1 oder CET erkannt wurde - HARTES MAPPING
      bool needsHardMapping = false;
      if (systemTZName.contains('GMT') || 
          systemTZName.contains('CET') || 
          systemTZName.contains('CEST') ||
          systemTZName == 'MEZ' ||
          systemTZName == 'MESZ') {
        needsHardMapping = true;
        debugLog('   ⚠️ System liefert GMT/CET/CEST/MEZ/MESZ - wird hart auf Europe/Berlin gemappt!');
      }
      
      // VERBOT: Kein UTC wenn Offset vorhanden
      if (offsetHours != 0 || offsetMinutes != 0) {
        debugLog('   ✅ Offset erkannt (${offsetHours}h ${offsetMinutes}m) - UTC wird NICHT verwendet!');
      }
      
      debugLog('📋 SCHRITT 2: Package-Status (tz.local.name)');
      debugLog('═══════════════════════════════════════════════════════');
      
      // SCHRITT 2: Package-Status
      String? tzLocalNameResult;
      Exception? tzLocalError;
      
      try {
        final localTZ = tz.local;
        tzLocalNameResult = localTZ.name;
        debugLog('   ✅ tz.local.name erfolgreich: "$tzLocalNameResult"');
        debugLog('   Typ: ${tzLocalNameResult.runtimeType}');
        debugLog('   Länge: ${tzLocalNameResult.length}');
      } catch (e) {
        tzLocalError = e is Exception ? e : Exception(e.toString());
        debugLog('   ❌ tz.local.name FEHLER: $tzLocalError');
        debugLog('   StackTrace: ${StackTrace.current}');
      }
      
      // Prüfe ob initializeTimeZones erfolgreich war
      debugLog('📋 SCHRITT 2.1: Prüfe initializeTimeZones Status');
      try {
        // Versuche eine bekannte Zeitzone abzurufen um zu prüfen ob DB geladen ist
        final testLocation = tz.getLocation('Europe/Berlin');
        debugLog('   ✅ Timezone-Datenbank ist geladen (Test: Europe/Berlin erfolgreich)');
      } catch (e) {
        debugLog('   ❌ Timezone-Datenbank FEHLER: $e');
        debugLog('   ⚠️ initializeTimeZones() wurde möglicherweise nicht erfolgreich ausgeführt!');
      }
      
      debugLog('📋 SCHRITT 3: Zeitzonen-Namen-Findung');
      debugLog('═══════════════════════════════════════════════════════');
      
      // SCHRITT 3: Zeitzonen-Namen-Findung
      // KEINE hartcodierte UTC-Initialisierung - nutze direkt System-Mapping
      String localTZName;
      bool nameFound = false;
      
      // PRIORITÄT 1: Hartes Mapping für CET/GMT+1/etc. (wenn Google APIs fehlschlagen)
      if (needsHardMapping && (offsetHours == 1 || offsetHours == 2)) {
        localTZName = 'Europe/Berlin';
        nameFound = true;
        debugLog('   ✅ HARTES MAPPING: "$systemTZName" → Europe/Berlin (Offset ${offsetHours}h)');
      }
      // PRIORITÄT 2: tz.local.name (wenn verfügbar)
      else if (tzLocalNameResult != null && 
          tzLocalNameResult.isNotEmpty && 
          tzLocalNameResult != 'Local') {
        localTZName = tzLocalNameResult;
        nameFound = true;
        debugLog('   ✅ Name gefunden via tz.local.name: "$localTZName"');
      } 
      // PRIORITÄT 3: System-Mapping basierend auf Offset
      else {
        debugLog('   ⚠️ tz.local.name lieferte keinen gültigen Wert, nutze System-Mapping');
        debugLog('   🔄 Starte Offset-basiertes Mapping...');
        
        if (offsetHours == 1 && offsetMinutes == 0) {
          localTZName = 'Europe/Berlin';
          nameFound = true;
          debugLog('   ✅ Mapping zu: Europe/Berlin (MEZ, Offset +1h)');
        } else if (offsetHours == 2 && offsetMinutes == 0) {
          localTZName = 'Europe/Berlin';
          nameFound = true;
          debugLog('   ✅ Mapping zu: Europe/Berlin (MESZ, Offset +2h)');
        } else if (offsetHours == 0 && offsetMinutes == 0) {
          localTZName = 'Europe/London';
          nameFound = true;
          debugLog('   ✅ Mapping zu: Europe/London (GMT, Offset 0h)');
        } else if (offsetHours == -5 && offsetMinutes == 0) {
          localTZName = 'America/New_York';
          nameFound = true;
          debugLog('   ✅ Mapping zu: America/New_York (Offset -5h)');
        } else if (offsetHours == -8 && offsetMinutes == 0) {
          localTZName = 'America/Los_Angeles';
          nameFound = true;
          debugLog('   ✅ Mapping zu: America/Los_Angeles (Offset -8h)');
        } else if (offsetHours == 9 && offsetMinutes == 0) {
          localTZName = 'Asia/Tokyo';
          nameFound = true;
          debugLog('   ✅ Mapping zu: Asia/Tokyo (Offset +9h)');
        } else if (offsetHours == 3 && offsetMinutes == 0) {
          localTZName = 'Europe/Moscow';
          nameFound = true;
          debugLog('   ✅ Mapping zu: Europe/Moscow (Offset +3h)');
        } else {
          // PRIORITÄT 4: System-Zeitzonen-Name direkt verwenden (wenn nicht GMT/UTC)
          debugLog('   🔄 Kein bekanntes Offset-Mapping, prüfe System-Name...');
          
          if (systemTZName.isNotEmpty && 
              !systemTZName.startsWith('GMT') && 
              !systemTZName.startsWith('UTC') &&
              systemTZName.toLowerCase() != 'null' &&
              systemTZName != 'Local') {
            localTZName = systemTZName;
            nameFound = true;
            debugLog('   ✅ Nutze System-Zeitzonen-Namen direkt: "$systemTZName"');
          } else {
            // VERBOT: KEIN UTC wenn Offset vorhanden - generiere Offset-String
            if (offsetHours != 0 || offsetMinutes != 0) {
              debugLog('   ⚠️ SCHRITT 4: Kein Mapping gefunden, aber Offset vorhanden!');
              debugLog('   ⚠️ VERBOT: UTC wird NICHT verwendet (Offset: ${offsetHours}h ${offsetMinutes}m)');
              localTZName = 'UTC${offsetHours >= 0 ? '+' : ''}$offsetHours${offsetMinutes != 0 ? ':$offsetMinutes' : ''}';
              nameFound = true;
              debugLog('   ✅ Generierter Offset-String: "$localTZName"');
            } else {
              // Nur wenn wirklich UTC (Offset 0)
              localTZName = 'UTC';
              nameFound = true;
              debugLog('   ✅ UTC verwendet (Offset 0h)');
            }
          }
        }
      }
      
      if (!nameFound) {
        throw Exception('Konnte keinen Zeitzonen-Namen finden');
      }
      
      debugLog('📋 SCHRITT 5: Finale Werte');
      debugLog('═══════════════════════════════════════════════════════');
      debugLog('   📍 Finaler Zeitzonen-Name: "$localTZName"');
      debugLog('   Lokale Zeit: ${DateFormat('HH:mm').format(localTime)}');
      debugLog('═══════════════════════════════════════════════════════');
      
      final localFormatted = DateFormat('HH:mm').format(localTime);
      final localDisplay = '🏠 Meine Zeit: $localFormatted ($localTZName)';

      // Event-Zeit (Party-Zeitzone)
      String eventDisplay = '';
      if (timezoneId.isNotEmpty && timezoneId != 'UTC') {
        try {
          final eventLocation = tz.getLocation(timezoneId);
          final eventTime = tz.TZDateTime.fromMillisecondsSinceEpoch(eventLocation, startTimePosix * 1000);
          final eventFormatted = DateFormat('HH:mm').format(eventTime);
          eventDisplay = '🌍 Vor Ort: $eventFormatted ($timezoneId)';
        } catch (e) {
          // Fallback: Wenn Zeitzone nicht gefunden wird, nutze UTC
          final utcFormatted = DateFormat('HH:mm').format(utcDateTime);
          eventDisplay = '🌍 Vor Ort: $utcFormatted (UTC)';
        }
      } else {
        // Falls timezone_id fehlt oder UTC ist, zeige UTC explizit an
        final utcFormatted = DateFormat('HH:mm').format(utcDateTime);
        eventDisplay = '🌍 Vor Ort: $utcFormatted (UTC)';
      }

      return {
        'local': localDisplay,
        'event': eventDisplay,
      };
    } catch (e, stackTrace) {
      // Fallback bei Fehler mit detailliertem Logging
      debugLog('═══════════════════════════════════════════════════════');
      debugLog('❌ FEHLER in _calculateDualTimes:');
      debugLog('   Fehler: $e');
      debugLog('   StackTrace: $stackTrace');
      debugLog('═══════════════════════════════════════════════════════');
      
      final fallbackTime = DateTime.fromMillisecondsSinceEpoch(startTimePosix * 1000, isUtc: true).toLocal();
      final fallbackFormatted = DateFormat('HH:mm').format(fallbackTime);
      final fallbackTZName = DateTime.now().timeZoneName;
      
      // KEIN hartcodiertes UTC mehr - nutze System-Name
      final fallbackTZDisplay = (fallbackTZName.isNotEmpty && 
                                 !fallbackTZName.startsWith('GMT') && 
                                 !fallbackTZName.startsWith('UTC')) 
                                 ? fallbackTZName 
                                 : 'UTC${DateTime.now().timeZoneOffset.inHours >= 0 ? '+' : ''}${DateTime.now().timeZoneOffset.inHours}';
      
      return {
        'local': '🏠 Meine Zeit: $fallbackFormatted ($fallbackTZDisplay)',
        'event': '🌍 Vor Ort: $fallbackFormatted (UTC)',
      };
    }
  }

  /// Eine Zeile: Datum + Uhrzeit passend zur App-Sprache (Party-Ortszeit).
  String _formatDateCompact(DateTime date, BuildContext context) {
    final datePart = FormattingUtils.formatDateForLocale(date, context);
    final timePart = FormattingUtils.formatTime(date, context);
    return '$datePart $timePart';
  }

  /// Konvertiert Firestore-num oder double sicher zu double? (für Maps-URLs)
  static double? _toDoubleOrNull(dynamic value) =>
      value == null ? null : (value is num ? value.toDouble() : null);

  /// Öffnet die Standard-Karten-App des Systems (egal welche App das ist)
  Future<void> _openGoogleMaps() async {
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    try {
      // Koordinaten sicher als double auswerten (Firestore liefert ggf. num)
      final lat = _toDoubleOrNull(widget.latitude);
      final lng = _toDoubleOrNull(widget.longitude);
      // Prüfe ob Koordinaten vorhanden und gültig sind
      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        // Versuche zuerst geo: URI Schema (funktioniert auf beiden Plattformen mit Standard-App)
        final geoUrl = 'geo:$lat,$lng?q=$lat,$lng';
        final geoUri = Uri.parse(geoUrl);
        
        final geoLaunched = await launchUrl(
          geoUri,
          mode: LaunchMode.externalApplication,
        );
        
        if (geoLaunched) {
          return; // Erfolgreich geöffnet
        }
        
        // Fallback: Plattform-spezifische Standard-URLs
        String fallbackUrl;
        if (Platform.isIOS) {
          // iOS: maps:// öffnet die Standard-Karten-App (kann Apple Maps oder Google Maps sein)
          fallbackUrl = 'maps://?q=$lat,$lng';
        } else {
          // Android: Google Maps Web-Link als Fallback
          fallbackUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
        }
        
        final fallbackUri = Uri.parse(fallbackUrl);
        final fallbackLaunched = await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
        
        if (!fallbackLaunched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.maps_app_unavailable),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else if (widget.locationName != null && widget.locationName!.isNotEmpty) {
        // Fallback: Suche mit Location-Name
        final encodedName = Uri.encodeComponent(widget.locationName!);
        
        // Versuche zuerst geo: mit Suchbegriff (funktioniert auf Android)
        final geoUrl = 'geo:0,0?q=$encodedName';
        final geoUri = Uri.parse(geoUrl);
        
        final geoLaunched = await launchUrl(
          geoUri,
          mode: LaunchMode.externalApplication,
        );
        
        if (geoLaunched) {
          return; // Erfolgreich geöffnet
        }
        
        // Fallback: Plattform-spezifische Such-URLs
        String fallbackUrl;
        if (Platform.isIOS) {
          // iOS: maps:// mit Suchbegriff
          fallbackUrl = 'maps://?q=$encodedName';
        } else {
          // Android: Google Maps Web-Link
          fallbackUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedName';
        }
        
        final fallbackUri = Uri.parse(fallbackUrl);
        final fallbackLaunched = await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
        
        if (!fallbackLaunched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.maps_app_unavailable),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Keine Daten vorhanden
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.maps_no_location_data),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.maps_open_error} $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
