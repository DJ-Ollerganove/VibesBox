import 'package:flutter/material.dart';
import 'party_realtime_countdown.dart';

/// Kleines Widget nur für den Countdown-Text (z. B. "Startet in 59s").
/// Enthält den Sekunden-Timer lokal – nur dieses Label wird bei jedem Tick neu gezeichnet,
/// die restliche Seite (Liste, Karten, Buttons) bleibt unverändert.
class PartyCountdownLabel extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final int? startTimePosix;
  final String status;

  const PartyCountdownLabel({
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
