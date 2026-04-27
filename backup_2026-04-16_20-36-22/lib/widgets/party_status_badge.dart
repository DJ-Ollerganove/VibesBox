import 'package:flutter/material.dart';
import 'party_realtime_countdown.dart';

/// Kleines Widget nur für die Status-Anzeige (z. B. "Startet in 45s" oder "Läuft noch: 2h").
/// Der Sekunden-Timer läuft ausschließlich in PartyRealtimeCountdown – nur diese Badge wird
/// bei jedem Tick neu gezeichnet. PartyVerwaltungPage und StreamBuilder bleiben stabil.
class PartyStatusBadge extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final int? startTimePosix;
  final String status;

  const PartyStatusBadge({
    super.key,
    required this.startDate,
    required this.endDate,
    this.startTimePosix,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return PartyRealtimeCountdown(
      startDate: startDate,
      endDate: endDate,
      startTimePosix: startTimePosix,
      status: status,
    );
  }
}
