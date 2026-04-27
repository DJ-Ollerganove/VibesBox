import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:intl/intl.dart';
import '../utils/debug_log.dart';

/// Helper für den Kalender-Export von Partys
class CalendarExportHelper {
  /// Exportiert eine Party in den Standard-Kalender des Geräts
  /// 
  /// [partyData] muss folgende Felder enthalten:
  /// - party_name: String
  /// - start_time_posix: int (Unix-Timestamp in Sekunden, UTC)
  /// - end_time_posix: int (Unix-Timestamp in Sekunden, UTC)
  /// - timezone_id: String (z.B. "Africa/Cairo")
  /// - latitude: double? (optional)
  /// - longitude: double? (optional)
  /// - location_name: String? (optional)
  static Future<void> exportParty(
    Map<String, dynamic> partyData,
    BuildContext context,
  ) async {
    try {
      // Initialisiere Timezone-Datenbank
      tz.initializeTimeZones();

      // Extrahiere Party-Daten
      final partyName = partyData['party_name'] as String? ?? 'Unbenannte Party';
      final startTimePosix = partyData['start_time_posix'] as int? ??
          partyData['startTimePosix'] as int? ??
          partyData['start_time_posix_seconds'] as int? ??
          partyData['startTimePosixSeconds'] as int?;
      final endTimePosix = partyData['end_time_posix'] as int? ??
          partyData['endTimePosix'] as int? ??
          partyData['end_time_posix_seconds'] as int? ??
          partyData['endTimePosixSeconds'] as int?;
      
      // Prüfe verschiedene Feldnamen für timezone_id
      dynamic timezoneIdRaw = partyData['timezone_id'] ?? 
                             partyData['timezoneId'] ?? 
                             partyData['time_zone_id'] ??
                             partyData['timezone'];
      
      String? timezoneId;
      if (timezoneIdRaw != null && timezoneIdRaw is String) {
        final cleaned = timezoneIdRaw.trim();
        if (cleaned.isNotEmpty && cleaned.toLowerCase() != 'null') {
          timezoneId = cleaned;
        }
      }
      
      final latitude = partyData['latitude'] as double?;
      final longitude = partyData['longitude'] as double?;
      final locationName = partyData['location_name'] as String?;

      // Validierung: Start- und Endzeit müssen vorhanden sein
      if (startTimePosix == null || startTimePosix <= 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fehler: Startzeit der Party konnte nicht ermittelt werden.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      if (endTimePosix == null || endTimePosix <= 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fehler: Endzeit der Party konnte nicht ermittelt werden.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // FLOATING TIME LOGIK: Berechne die Ortszeit der Party
      // Ziel: Der Termin soll im Kalender immer bei der exakten Ortszeit stehen (z.B. 20:00 Uhr)
      // egal welche Zeitzone das Handy hat
      
      DateTime startDateTimeFloating;
      DateTime endDateTimeFloating;
      String timeAtLocation = '';
      String timezoneDisplay = timezoneId ?? 'UTC';
      
      if (timezoneId != null && timezoneId.isNotEmpty) {
        try {
          final partyLocation = tz.getLocation(timezoneId);
          
          // Konvertiere UTC Unix-Timestamp zu TZDateTime in Party-Zeitzone
          final startTimeAtLocation = tz.TZDateTime.fromMillisecondsSinceEpoch(
            partyLocation,
            startTimePosix * 1000,
          );
          final endTimeAtLocation = tz.TZDateTime.fromMillisecondsSinceEpoch(
            partyLocation,
            endTimePosix * 1000,
          );
          
          // Erstelle DateTime-Objekte OHNE UTC-Flag (Floating Time)
          // Diese repräsentieren die exakte Ortszeit
          startDateTimeFloating = DateTime(
            startTimeAtLocation.year,
            startTimeAtLocation.month,
            startTimeAtLocation.day,
            startTimeAtLocation.hour,
            startTimeAtLocation.minute,
            startTimeAtLocation.second,
          );
          
          endDateTimeFloating = DateTime(
            endTimeAtLocation.year,
            endTimeAtLocation.month,
            endTimeAtLocation.day,
            endTimeAtLocation.hour,
            endTimeAtLocation.minute,
            endTimeAtLocation.second,
          );
          
          // Formatiere Zeit für Titel und Beschreibung
          timeAtLocation = DateFormat('HH:mm').format(startTimeAtLocation);
          
        } catch (e) {
          debugLog('⚠️ Fehler bei Zeitzonen-Konvertierung: $e');
          // Fallback: Nutze UTC-Zeit
          final startDateTimeUtc = DateTime.fromMillisecondsSinceEpoch(
            startTimePosix * 1000,
            isUtc: true,
          );
          final endDateTimeUtc = DateTime.fromMillisecondsSinceEpoch(
            endTimePosix * 1000,
            isUtc: true,
          );
          
          startDateTimeFloating = DateTime(
            startDateTimeUtc.year,
            startDateTimeUtc.month,
            startDateTimeUtc.day,
            startDateTimeUtc.hour,
            startDateTimeUtc.minute,
            startDateTimeUtc.second,
          );
          
          endDateTimeFloating = DateTime(
            endDateTimeUtc.year,
            endDateTimeUtc.month,
            endDateTimeUtc.day,
            endDateTimeUtc.hour,
            endDateTimeUtc.minute,
            endDateTimeUtc.second,
          );
          
          timeAtLocation = DateFormat('HH:mm').format(startDateTimeUtc);
          timezoneDisplay = 'UTC';
        }
      } else {
        // Fallback: Keine Zeitzone vorhanden, nutze UTC
        final startDateTimeUtc = DateTime.fromMillisecondsSinceEpoch(
          startTimePosix * 1000,
          isUtc: true,
        );
        final endDateTimeUtc = DateTime.fromMillisecondsSinceEpoch(
          endTimePosix * 1000,
          isUtc: true,
        );
        
        startDateTimeFloating = DateTime(
          startDateTimeUtc.year,
          startDateTimeUtc.month,
          startDateTimeUtc.day,
          startDateTimeUtc.hour,
          startDateTimeUtc.minute,
          startDateTimeUtc.second,
        );
        
        endDateTimeFloating = DateTime(
          endDateTimeUtc.year,
          endDateTimeUtc.month,
          endDateTimeUtc.day,
          endDateTimeUtc.hour,
          endDateTimeUtc.minute,
          endDateTimeUtc.second,
        );
        
        timeAtLocation = DateFormat('HH:mm').format(startDateTimeUtc);
        timezoneDisplay = 'UTC';
      }

      // Titel: Party: [Name] - [Stunde:Minute] Uhr OZ [Zeitzone]. Eintrag von VibesBox
      final title = 'Party: $partyName - $timeAtLocation Uhr OZ $timezoneDisplay. Eintrag von VibesBox';

      // Beschreibung zusammenstellen
      final descriptionParts = <String>[];
      
      // 🕒 Zeit vor Ort
      descriptionParts.add('🕒 Zeit vor Ort: $timeAtLocation Uhr ($timezoneDisplay)');
      
      // 📍 Navigation zur Party (Klickbarer Link)
      if (latitude != null && longitude != null && 
          latitude != 0.0 && longitude != 0.0) {
        final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
        descriptionParts.add('📍 Navigation zur Party:\n$mapsUrl');
      }
      
      final description = descriptionParts.join('\n\n');

      // Erstelle Event für Kalender mit Floating Time
      debugLog('📅 Erstelle Kalender-Event (Floating Time):');
      debugLog('   Titel: $title');
      debugLog('   Start (Floating): $startDateTimeFloating');
      debugLog('   Ende (Floating): $endDateTimeFloating');
      debugLog('   Location: ${locationName ?? "keine"}');
      
      final event = Event(
        title: title,
        description: description,
        location: locationName ?? '',
        startDate: startDateTimeFloating,
        endDate: endDateTimeFloating,
        allDay: false,
      );

      // Füge Event zum Kalender hinzu
      // Diese Methode öffnet den Standard-Kalender-Dialog, wo der User bestätigen kann
      debugLog('📅 Öffne Kalender-Dialog...');
      final result = await Add2Calendar.addEvent2Cal(event);
      
      debugLog('📅 Kalender-Export Ergebnis: $result');
      
      // Der Dialog sollte automatisch geöffnet werden
      // Auf Android und iOS öffnet add_2_calendar den Standard-Kalender-Dialog
      // Der User kann dann die Details prüfen und selbst speichern
      
      // Keine SnackBar, da der Kalender-Dialog bereits geöffnet ist
      // Der User muss selbst im Kalender-Dialog speichern
    } catch (e) {
      debugLog('❌ Fehler beim Kalender-Export: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Exportieren: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
