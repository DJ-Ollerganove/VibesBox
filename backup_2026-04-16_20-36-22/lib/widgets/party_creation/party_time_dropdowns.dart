import 'package:flutter/material.dart';
import '../../utils/ui_constants.dart';

/// Gemeinsame Zeitlogik und UI für Party-Erstellung und Party-Bearbeitung.
/// 12:51-Fix: Frühestmögliche Startzeit = jetzt + 5 Min, aufgerundet auf 5-Minuten-Intervall;
/// bei Aufrunden auf 60 Min darf die aktuelle Stunde nicht wählbar sein.
class PartyTimeHelpers {
  PartyTimeHelpers._();

  static const List<int> kFiveMinuteSteps = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  static int roundToNext5Minutes(int minute) {
    if (minute <= 0) return 0;
    return ((minute + 4) ~/ 5) * 5;
  }

  /// Frühestmögliche Startzeit (heute): jetzt + 5 Min, aufgerundet auf 5-Min-Intervall.
  /// Bei roundedMinute >= 60: earliestHour = buffered.hour + 1, earliestMinute = 0.
  static ({int hour, int minute}) getEarliestStartHourMinute() {
    final now = DateTime.now();
    final buffered = now.add(const Duration(minutes: 5));
    int roundedMinute = roundToNext5Minutes(buffered.minute);
    int hour = buffered.hour;
    int minute = roundedMinute;
    if (roundedMinute >= 60) {
      hour = buffered.hour + 1;
      minute = 0;
    }
    if (hour >= 24) hour = 0;
    return (hour: hour, minute: minute);
  }

  /// Verfügbare Startstunden (12:51-Fix berücksichtigt wenn [startDate] heute ist).
  static List<int> getAvailableStartHours(DateTime? startDate) {
    if (startDate == null) return [];
    final now = DateTime.now();
    if (startDate.year == now.year &&
        startDate.month == now.month &&
        startDate.day == now.day) {
      final earliest = getEarliestStartHourMinute();
      if (earliest.hour >= 24) return [];
      return List.generate(24 - earliest.hour, (i) => earliest.hour + i);
    }
    return List.generate(24, (i) => i);
  }

  /// Verfügbare Startminuten; bei frühestmöglicher Stunde nur Werte >= earliestMinute.
  static List<int> getAvailableStartMinutes(DateTime? startDate, int? hour) {
    if (startDate == null || hour == null) return [];
    final now = DateTime.now();
    if (startDate.year == now.year &&
        startDate.month == now.month &&
        startDate.day == now.day) {
      final earliest = getEarliestStartHourMinute();
      if (hour == earliest.hour) {
        return kFiveMinuteSteps.where((m) => m >= earliest.minute).toList();
      }
    }
    return List<int>.from(kFiveMinuteSteps);
  }

  /// Verfügbare Endstunden ab Startzeit, max. Start + 23:55.
  static List<int> getAvailableEndHours(
    DateTime? startDate,
    int? startHour,
    int? startMinute,
    DateTime? endDate,
  ) {
    if (startDate == null || startHour == null || startMinute == null || endDate == null) {
      return [];
    }
    final startDateTime = DateTime(startDate.year, startDate.month, startDate.day, startHour, startMinute);
    final maxEnd = startDateTime.add(const Duration(hours: 23, minutes: 55));
    if (endDate.year == startDate.year && endDate.month == startDate.month && endDate.day == startDate.day) {
      final minHour = startHour;
      int maxHour;
      if (maxEnd.year == startDate.year && maxEnd.month == startDate.month && maxEnd.day == startDate.day) {
        maxHour = maxEnd.hour;
      } else {
        maxHour = 23;
      }
      return List.generate(maxHour - minHour + 1, (i) => minHour + i);
    }
    int maxHour;
    if (endDate.year == maxEnd.year && endDate.month == maxEnd.month && endDate.day == maxEnd.day) {
      maxHour = maxEnd.hour;
    } else {
      maxHour = 23;
    }
    return List.generate(maxHour + 1, (i) => i);
  }

  /// Verfügbare Endminuten (5-Minuten-Takt, abhängig von Start und max. 23:55).
  static List<int> getAvailableEndMinutes(
    DateTime? startDate,
    int? startHour,
    int? startMinute,
    DateTime? endDate,
    int? endHour,
  ) {
    if (startDate == null || startHour == null || startMinute == null || endDate == null || endHour == null) {
      return [];
    }
    final startDateTime = DateTime(startDate.year, startDate.month, startDate.day, startHour, startMinute);
    final maxEnd = startDateTime.add(const Duration(hours: 23, minutes: 55));
    if (endDate.year == startDate.year &&
        endDate.month == startDate.month &&
        endDate.day == startDate.day &&
        endHour == startHour) {
      final filtered = kFiveMinuteSteps.where((m) => m > startMinute).toList();
      return filtered.isEmpty ? [0] : filtered;
    }
    if (endDate.year == maxEnd.year &&
        endDate.month == maxEnd.month &&
        endDate.day == maxEnd.day &&
        endHour == maxEnd.hour) {
      final filtered = kFiveMinuteSteps.where((m) => m <= maxEnd.minute).toList();
      return filtered.isEmpty ? [0] : filtered;
    }
    return List<int>.from(kFiveMinuteSteps);
  }

  /// Korrigiert Endzeit auf Startzeit + 1 Stunde, falls End <= Start.
  static ({DateTime endDate, int endHour, int endMinute}) correctEndIfBeforeStart(
    DateTime startDate,
    int startHour,
    int startMinute,
    DateTime endDate,
    int endHour,
    int endMinute,
  ) {
    final start = DateTime(startDate.year, startDate.month, startDate.day, startHour, startMinute);
    final end = DateTime(endDate.year, endDate.month, endDate.day, endHour, endMinute);
    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      final corrected = start.add(const Duration(hours: 1));
      return (
        endDate: DateTime(corrected.year, corrected.month, corrected.day),
        endHour: corrected.hour,
        endMinute: corrected.minute,
      );
    }
    return (endDate: endDate, endHour: endHour, endMinute: endMinute);
  }
}

/// Zwei Dropdowns (Stunde | Minute) im Schwarz/Orange-Design.
/// Stunde nur als Zahl (z. B. 13), Minute im 5-Minuten-Takt (00, 05, …, 55).
class PartyTimeDropdownRow extends StatelessWidget {
  final int? valueHour;
  final int? valueMinute;
  final List<int> availableHours;
  final List<int> availableMinutes;
  final bool enabled;
  final String labelHour;
  final String labelMinute;
  final void Function(int hour, int minute) onChanged;

  const PartyTimeDropdownRow({
    super.key,
    required this.valueHour,
    required this.valueMinute,
    required this.availableHours,
    required this.availableMinutes,
    required this.enabled,
    this.labelHour = 'Stunde',
    this.labelMinute = 'Min.',
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildDropdown<int>(
            value: availableHours.contains(valueHour) ? valueHour : null,
            items: availableHours,
            label: labelHour,
            enabled: enabled,
            itemLabel: (h) => '$h',
            onChanged: (h) {
              if (h == null) return;
              final mins = availableMinutes;
              final newMin = mins.contains(valueMinute) ? valueMinute! : (mins.isNotEmpty ? mins.first : 0);
              onChanged(h, newMin);
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildDropdown<int>(
            value: availableMinutes.contains(valueMinute) ? valueMinute : null,
            items: availableMinutes,
            label: labelMinute,
            enabled: enabled,
            itemLabel: (m) => m.toString().padLeft(2, '0'),
            onChanged: (m) {
              if (m == null || valueHour == null) return;
              onChanged(valueHour!, m);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required List<T> items,
    required String label,
    required bool enabled,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        border: Border.all(
          color: enabled ? UIConstants.appOrange : Colors.grey.shade700,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          isDense: true,
          dropdownColor: const Color(0xFF1F2937),
          icon: Icon(Icons.arrow_drop_down, color: enabled ? UIConstants.appOrange : Colors.grey.shade600),
          hint: Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
          items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(itemLabel(e), style: const TextStyle(color: Colors.white, fontSize: 14)))).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
