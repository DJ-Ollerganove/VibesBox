import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// Ergebnis der Party-Code-Validierung für Feedback-Anzeige.
enum PartyCheckInFeedbackType {
  /// Code unbekannt oder Party existiert nicht
  wrongCode,
  /// Party bereits beendet
  partyEnded,
  /// Party hat noch nicht begonnen (mit Startzeit)
  partyNotStarted,
  /// Standby oder sonstiger Fehler
  invalidOrInactive,
}

/// Daten für das Party-Check-In-Feedback.
class PartyCheckInFeedback {
  final PartyCheckInFeedbackType type;
  final DateTime? startDateTime;

  const PartyCheckInFeedback({
    required this.type,
    this.startDateTime,
  });

  bool get isError =>
      type == PartyCheckInFeedbackType.wrongCode ||
      type == PartyCheckInFeedbackType.partyEnded ||
      type == PartyCheckInFeedbackType.invalidOrInactive;
  bool get isNotStarted => type == PartyCheckInFeedbackType.partyNotStarted;
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
        return loc.party_code_ended;
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
    final locale = Localizations.localeOf(context);
    return DateFormat.yMd(locale.toString()).format(d);
  }

  String _formatTime(BuildContext context, DateTime d) {
    final locale = Localizations.localeOf(context);
    return DateFormat.Hm(locale.toString()).format(d);
  }
}
