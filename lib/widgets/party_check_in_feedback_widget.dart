import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/guest_floor_option.dart';
import '../utils/formatting_utils.dart';
import '../utils/ui_constants.dart';

/// Ergebnis der Party-Code-Validierung für Feedback-Anzeige.
enum PartyCheckInFeedbackType {
  /// Code unbekannt oder Party existiert nicht
  wrongCode,
  /// Party bereits beendet
  partyEnded,
  /// Party in einem Floor beendet — andere Räume noch aktiv
  floorEndedChooseOther,
  /// Mehrere aktive Räume — Gast muss Floor wählen
  selectFloor,
  /// Party hat noch nicht begonnen (mit Startzeit)
  partyNotStarted,
  /// Standby oder sonstiger Fehler
  invalidOrInactive,
}

/// Daten für das Party-Check-In-Feedback.
class PartyCheckInFeedback {
  final PartyCheckInFeedbackType type;
  final DateTime? startDateTime;
  final String? partyName;
  final String? djName;
  final String? endedFloorLabel;
  final List<GuestFloorOption>? otherFloorOptions;

  const PartyCheckInFeedback({
    required this.type,
    this.startDateTime,
    this.partyName,
    this.djName,
    this.endedFloorLabel,
    this.otherFloorOptions,
  });

  bool get isError =>
      type == PartyCheckInFeedbackType.wrongCode ||
      type == PartyCheckInFeedbackType.partyEnded ||
      type == PartyCheckInFeedbackType.invalidOrInactive;
  bool get isNotStarted => type == PartyCheckInFeedbackType.partyNotStarted;
  bool get isFloorRedirect =>
      type == PartyCheckInFeedbackType.floorEndedChooseOther;
}

/// Eigenes Widget für Party-Check-In-Feedback (PWA-Design).
/// Eigenständiger Block unter dem Eingabefeld. Schwarz, 3px Rahmen.
/// Rot bei Fehler/beendeter Party, Grün bei bevorstehender Party.
class PartyCheckInFeedbackWidget extends StatelessWidget {
  final PartyCheckInFeedback feedback;

  const PartyCheckInFeedbackWidget({
    super.key,
    required this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(locale.languageCode);
    final textDirection = isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr;

    final borderColor = feedback.isError ? Colors.red : Colors.green;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 3.0),
      ),
      child: Text(
        _getMessage(context, loc),
        textAlign: TextAlign.center,
        textDirection: textDirection,
        style: const TextStyle(
          color: UIConstants.colorWhite,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }

  String _getMessage(BuildContext context, AppLocalizations loc) {
    switch (feedback.type) {
      case PartyCheckInFeedbackType.wrongCode:
        return loc.party_code_unknown;
      case PartyCheckInFeedbackType.partyEnded:
        final party = feedback.partyName?.trim().isNotEmpty == true
            ? feedback.partyName!.trim()
            : loc.unnamed_party;
        final dj = feedback.djName?.trim().isNotEmpty == true
            ? feedback.djName!.trim()
            : 'DJ';
        return loc.partyEndedWithDj(party, dj);
      case PartyCheckInFeedbackType.floorEndedChooseOther:
        final floor = feedback.endedFloorLabel?.trim().isNotEmpty == true
            ? feedback.endedFloorLabel!.trim()
            : loc.guest_floor_main_area;
        return loc.guest_floor_ended_redirect_message(floor);
      case PartyCheckInFeedbackType.selectFloor:
        return loc.guest_floor_picker_choose;
      case PartyCheckInFeedbackType.invalidOrInactive:
        return loc.party_code_invalid_or_inactive;
      case PartyCheckInFeedbackType.partyNotStarted:
        if (feedback.startDateTime != null) {
          return _formatPartyStartAt(context, loc, feedback.startDateTime!);
        }
        return loc.party_code_not_started;
    }
  }

  String _formatPartyStartAt(
      BuildContext context, AppLocalizations loc, DateTime start) {
    final dateStr = _formatDate(context, start);
    final timeStr = _formatTime(context, start);
    final template =
        loc.party_start_at;
    return template
        .replaceAll('{date}', dateStr)
        .replaceAll('{time}', timeStr);
  }

  String _formatDate(BuildContext context, DateTime d) {
    return FormattingUtils.formatDateForLocale(d, context);
  }

  String _formatTime(BuildContext context, DateTime d) {
    return FormattingUtils.formatTime(d, context);
  }
}
