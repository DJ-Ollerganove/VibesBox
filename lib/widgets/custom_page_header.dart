import 'package:flutter/material.dart';
import '../utils/ui_constants.dart';
import 'heartbeat_pulse_dot.dart';

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

class _CustomPageHeaderState extends State<CustomPageHeader> {
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
              HeartbeatPulseDot(
                padding: EdgeInsetsDirectional.only(
                  start: isRtl ? 0 : 8,
                  end: isRtl ? 8 : 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

