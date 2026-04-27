import 'package:flutter/material.dart';

import '../services/active_party_service.dart';

/// Grüner pulsierender Punkt bei aktivem Party-Heartbeat ([ActivePartyService.heartbeatActiveNotifier]).
/// Wiederverwendung in [CustomPageHeader], VibesBox-Tabs usw.
class HeartbeatPulseDot extends StatefulWidget {
  const HeartbeatPulseDot({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  State<HeartbeatPulseDot> createState() => _HeartbeatPulseDotState();
}

class _HeartbeatPulseDotState extends State<HeartbeatPulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ActivePartyService.heartbeatActiveNotifier,
      builder: (context, isHeartbeatActive, child) {
        if (!isHeartbeatActive) return const SizedBox.shrink();
        return Padding(
          padding: widget.padding ?? EdgeInsets.zero,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _pulseAnimation.value,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
