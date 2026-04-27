import 'package:flutter/material.dart';
import '../services/active_party_service.dart';
import '../utils/ui_constants.dart';

/// Zentrales Header-Widget für alle Listen-Seiten
/// Garantiert einheitliches Design mit RTL-Support
/// Zeigt pulsierenden grünen Punkt bei aktivem Heartbeat
class CustomPageHeader extends StatefulWidget {
  final IconData icon;
  final String title;
  final Widget? trailing; // Optional: z.B. IconButton für History-Seite

  const CustomPageHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  State<CustomPageHeader> createState() => _CustomPageHeaderState();
}

class _CustomPageHeaderState extends State<CustomPageHeader> with SingleTickerProviderStateMixin {
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
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Schwarze Trennlinie oben
        Divider(
          height: 1,
          color: UIConstants.appOrange.withValues(alpha: 0.35),
          thickness: 1,
        ),
        // Titel-Balken (flach, ohne Gradient)
        Container(
          width: double.infinity, // Volle Bildschirmbreite
          padding: const EdgeInsetsDirectional.only(
            start: 16,
            end: 16,
            top: 5,
            bottom: 5,
          ),
          // Kein decoration - transparent/schwarz Hintergrund
          child: Row(
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Icon - WEISS
              Icon(
                widget.icon,
                size: 32,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              // Titel - WEISS
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                ),
              ),
              // Optional: Trailing-Widget (z.B. IconButton für History) - VOR dem grünen Punkt
              if (widget.trailing != null) widget.trailing!,
              // Pulsierender Punkt nur sichtbar bei aktivem Heartbeat (ValueListenable → sofort aus bei Party-Ende)
              ValueListenableBuilder<bool>(
                valueListenable: ActivePartyService.heartbeatActiveNotifier,
                builder: (context, isHeartbeatActive, child) {
                  if (!isHeartbeatActive) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: isRtl ? 0 : 8,
                      end: isRtl ? 8 : 0,
                    ),
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}

