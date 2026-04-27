import 'package:flutter/material.dart';
import 'dart:async';
import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// Separates Widget für die Echtzeit-Zeitanzeige einer Party
/// Verwendet Stream.periodic für flackerfreie Updates
class PartyRealtimeCountdown extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final int? startTimePosix; // UTC Unix-Timestamp in Sekunden
  final String status; // 'Bevorstehend' oder 'Läuft'

  const PartyRealtimeCountdown({
    super.key,
    required this.startDate,
    required this.endDate,
    this.startTimePosix,
    required this.status,
  });

  @override
  State<PartyRealtimeCountdown> createState() => _PartyRealtimeCountdownState();
}

class _PartyRealtimeCountdownState extends State<PartyRealtimeCountdown> {
  late Stream<DateTime> _timeStream;
  StreamController<DateTime>? _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = StreamController<DateTime>.broadcast();
    _controller!.add(DateTime.now());
    // Sekunden-Takt: für Sekunden-Countdown (≤60s) und sofortige Umschaltung bei Start
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!_controller!.isClosed) {
          _controller!.add(DateTime.now());
        } else {
          timer.cancel();
        }
      },
    );
    _timeStream = _controller!.stream;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller?.close();
    super.dispose();
  }

  /// Berechnet die verbleibende Zeit bis zum Start oder bis zum Ende
  /// Bei ≤60 Sekunden bis Start: Sekunden-Countdown (z. B. "Startet in 59s").
  String _calculateTimeRemaining(DateTime now, BuildContext context) {
    final l = AppLocalizations.of(context)!;

    if (now.isBefore(widget.startDate)) {
      final difference = widget.startDate.difference(now);
      final totalSeconds = difference.inSeconds;

      if (totalSeconds <= 0) {
        return l.party_status_starts_now;
      }
      if (totalSeconds <= 60) {
        final startsIn = l.party_starts_in;
        return '$startsIn ${totalSeconds}s';
      }
      final totalMinutes = (totalSeconds + 59) ~/ 60;
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      final hourStr =
          hours == 1 ? l.party_hour : l.party_hours;
      final minuteStr =
          minutes == 1 ? l.party_minute : l.party_minutes;
      if (hours == 0 && minutes == 0) {
        return l.party_status_starts_now;
      } else if (hours == 0) {
        return '${l.party_countdown_in} $minutes $minuteStr';
      } else if (minutes == 0) {
        return '${l.party_countdown_in} $hours $hourStr';
      } else {
        return '${l.party_countdown_in} $hours $hourStr $minutes $minuteStr';
      }
    } else if (now.isAfter(widget.startDate) ||
        now.isAtSameMomentAs(widget.startDate)) {
      if (now.isBefore(widget.endDate) ||
          now.isAtSameMomentAs(widget.endDate)) {
        final difference = widget.endDate.difference(now);
        final totalSeconds = difference.inSeconds;
        if (totalSeconds <= 0) {
          return l.party_status_less_than_minute;
        }
        if (totalSeconds <= 60) {
          final still = l.party_countdown_still;
          return '$still ${totalSeconds}s';
        }
        final totalMinutes = (totalSeconds + 59) ~/ 60;
        final hours = totalMinutes ~/ 60;
        final minutes = totalMinutes % 60;
        final hourStr =
            hours == 1 ? l.party_hour : l.party_hours;
        final minuteStr =
            minutes == 1 ? l.party_minute : l.party_minutes;
        if (hours == 0 && minutes == 0) {
          return l.party_status_less_than_minute;
        } else if (hours == 0) {
          return '${l.party_countdown_still} $minutes $minuteStr';
        } else if (minutes == 0) {
          return '${l.party_countdown_still} $hours $hourStr';
        } else {
          return '${l.party_countdown_still} $hours $hourStr $minutes $minuteStr';
        }
      }
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: _timeStream,
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        final countdownText = _calculateTimeRemaining(now, context);
        
        if (countdownText.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Text(
          countdownText,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: UIConstants.appOrange,
          ),
        );
      },
    );
  }
}
