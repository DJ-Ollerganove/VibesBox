import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';
import 'heartbeat_pulse_dot.dart';
import 'settings_info_icon_button.dart';
import 'package:vibesbox/l10n/text_direction_helper.dart';

/// Zentrales Header-Widget für alle Listen-Seiten
/// Garantiert einheitliches Design mit RTL-Support
/// Zeigt pulsierenden grünen Punkt bei aktivem Heartbeat
class CustomPageHeader extends StatefulWidget {
  final IconData icon;
  final String title;
  final Widget? trailing; // Optional: z.B. IconButton für History-Seite
  /// Info-i direkt hinter dem Titel (gleiche Stelle auf allen Seiten).
  final VoidCallback? onInfoPressed;
  /// Info, Trailing und Heartbeat unter dem Titel — Titel bleibt in einer Zeile.
  final bool actionsBelowTitle;

  const CustomPageHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.onInfoPressed,
    this.actionsBelowTitle = false,
  });

  @override
  State<CustomPageHeader> createState() => _CustomPageHeaderState();
}

class _CustomPageHeaderState extends State<CustomPageHeader> {
  @override
  Widget build(BuildContext context) {
    final isRtl = VbTextDirection.isRtl(context);
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
          padding: EdgeInsetsDirectional.only(
            start: 16,
            end: 16,
            top: 5,
            bottom: widget.actionsBelowTitle ? 0 : 5,
          ),
          child: widget.actionsBelowTitle
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _titleRow(context, isRtl, includeActions: false),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(bottom: 2),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _actionIcons(context, isRtl),
                      ),
                    ),
                  ],
                )
              : _titleRow(context, isRtl, includeActions: true),
        ),
      ],
    );
  }

  Widget _titleRow(
    BuildContext context,
    bool isRtl, {
    required bool includeActions,
  }) {
    return Row(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          widget.icon,
          size: 32,
          color: Colors.white,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
            maxLines: includeActions ? 2 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (includeActions) _actionIcons(context, isRtl),
      ],
    );
  }

  Widget _actionIcons(BuildContext context, bool isRtl) {
    return Row(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onInfoPressed != null) ...[
          const SizedBox(width: 4),
          SettingsInfoIconButton(
            tooltip: AppLocalizations.of(context)!.settings_help_tooltip,
            onPressed: widget.onInfoPressed!,
          ),
        ],
        if (widget.trailing != null) widget.trailing!,
        HeartbeatPulseDot(
          padding: EdgeInsetsDirectional.only(
            start: isRtl ? 0 : 8,
            end: isRtl ? 8 : 0,
          ),
        ),
      ],
    );
  }
}
