import 'package:flutter/material.dart';
import 'dart:async';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// Countdown bis zum Ende der Nachlaufzeit (Wünsche ausblenden).
/// >60 s: minütliche Anzeige; ≤60 s: Sekunden-Countdown.
class PartyGraceCountdown extends StatefulWidget {
  const PartyGraceCountdown({
    super.key,
    required this.graceEndsAt,
  });

  final DateTime graceEndsAt;

  @override
  State<PartyGraceCountdown> createState() => _PartyGraceCountdownState();
}

class _PartyGraceCountdownState extends State<PartyGraceCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleTimer();
  }

  @override
  void didUpdateWidget(covariant PartyGraceCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.graceEndsAt != widget.graceEndsAt) {
      _scheduleTimer();
    }
  }

  void _scheduleTimer() {
    _timer?.cancel();
    final now = DateTime.now();
    final remaining = widget.graceEndsAt.difference(now).inSeconds;
    final interval = remaining <= 60 && remaining > 0
        ? const Duration(seconds: 1)
        : const Duration(seconds: 1);
    _timer = Timer.periodic(interval, (_) {
      if (!mounted) return;
      setState(() {});
      final sec = widget.graceEndsAt.difference(DateTime.now()).inSeconds;
      if (sec <= 0) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatRemaining(BuildContext context, DateTime now) {
    final l = AppLocalizations.of(context)!;
    final difference = widget.graceEndsAt.difference(now);
    final totalSeconds = difference.inSeconds;

    if (totalSeconds <= 0) {
      return l.party_status_less_than_minute;
    }
    if (totalSeconds <= 60) {
      return '${l.party_grace_countdown_wishes_still} ${totalSeconds}s';
    }

    final totalMinutes = (totalSeconds + 59) ~/ 60;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    final hourStr = hours == 1 ? l.party_hour : l.party_hours;
    final minuteStr = minutes == 1 ? l.party_minute : l.party_minutes;

    if (hours == 0) {
      return '${l.party_grace_countdown_wishes_still} $minutes $minuteStr';
    }
    if (minutes == 0) {
      return '${l.party_grace_countdown_wishes_still} $hours $hourStr';
    }
    return '${l.party_grace_countdown_wishes_still} $hours $hourStr $minutes $minuteStr';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (!now.isBefore(widget.graceEndsAt)) {
      return const SizedBox.shrink();
    }

    return Text(
      _formatRemaining(context, now),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: UIConstants.appOrange,
      ),
    );
  }
}
