import 'package:flutter/material.dart';

/// Titelleiste mit pulsierendem lila Glow-Effekt
class PulsatingTitleBar extends StatefulWidget {
  final IconData icon;
  final String title;

  const PulsatingTitleBar({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  State<PulsatingTitleBar> createState() => _PulsatingTitleBarState();
}

class _PulsatingTitleBarState extends State<PulsatingTitleBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialisiere AnimationController für Puls-Effekt
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.secondaryContainer,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9C27B0).withValues(alpha: _pulseAnimation.value * 0.5),
                blurRadius: 20 * _pulseAnimation.value,
                spreadRadius: 5 * _pulseAnimation.value,
              ),
            ],
          ),
          child: Row(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                widget.icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                  textAlign: isRtl ? TextAlign.right : null,
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
