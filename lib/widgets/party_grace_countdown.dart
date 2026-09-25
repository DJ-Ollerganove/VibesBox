import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

/// Countdown bis zum Ende der Nachlaufzeit.
/// Optional: orangefarbener Link „Nachlaufzeit beenden“ am Zeilenende.
class PartyGraceCountdown extends StatefulWidget {
  const PartyGraceCountdown({
    super.key,
    required this.graceEndsAt,
    this.onEndGracePeriod,
  });

  final DateTime graceEndsAt;
  final VoidCallback? onEndGracePeriod;

  @override
  State<PartyGraceCountdown> createState() => _PartyGraceCountdownState();
}

class _PartyGraceCountdownState extends State<PartyGraceCountdown> {
  Timer? _timer;
  late final TapGestureRecognizer _linkRecognizer;

  static const _baseStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: UIConstants.appOrange,
    height: 1.35,
  );

  @override
  void initState() {
    super.initState();
    _linkRecognizer = TapGestureRecognizer()..onTap = _handleLinkTap;
    _scheduleTimer();
  }

  @override
  void didUpdateWidget(covariant PartyGraceCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.graceEndsAt != widget.graceEndsAt) {
      _scheduleTimer();
    }
  }

  void _handleLinkTap() {
    widget.onEndGracePeriod?.call();
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
    _linkRecognizer.dispose();
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

    final remainingText = _formatRemaining(context, now);
    final onEnd = widget.onEndGracePeriod;

    if (onEnd == null) {
      return Text(remainingText, style: _baseStyle);
    }

    final l = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final linkLabel = l.grace_period_hide_wishes_now;

    return Text.rich(
      TextSpan(
        style: _baseStyle,
        children: [
          TextSpan(text: remainingText),
          const TextSpan(text: ' – '),
          TextSpan(
            text: linkLabel,
            style: _baseStyle.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: UIConstants.appOrange,
            ),
            recognizer: _linkRecognizer,
          ),
        ],
      ),
      textAlign: isRtl ? TextAlign.right : TextAlign.left,
    );
  }
}
