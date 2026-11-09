import 'package:flutter/material.dart';

import '../utils/ui_constants.dart';

/// Info-Texte enden oft mit Doppelpunkt. In der Zeile stört der.
String settingsPlainLabel(String raw) =>
    raw.replaceFirst(RegExp(r':\s*$'), '').trim();

/// Schrift wie die Wunschzeile (Titel 16, Erklärung kleiner).
/// Skaliert mit der gewählten App-Schrift, weil Flutter die fontSize
/// über den TextScaler legt.
class SettingsType {
  static const double titleSize = 16;
  static const double hintSize = 13;
  static const double baseMark = 18;

  static double markSize(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return baseMark * scale;
  }

  static const TextStyle title = TextStyle(
    color: Colors.white,
    fontSize: titleSize,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static const TextStyle hint = TextStyle(
    color: Color(0xFFC4C4C4),
    fontSize: hintSize,
    height: 1.3,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle scaleEnd = TextStyle(
    color: Color(0xFFC4C4C4),
    fontSize: hintSize,
    height: 1.2,
  );
}

/// Oranger Haken vor einer Ja/Nein-Zeile. Erklärung steht darunter.
class SettingsChoiceRow extends StatelessWidget {
  const SettingsChoiceRow({
    super.key,
    required this.value,
    required this.title,
    this.hint,
    this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final String title;
  final String? hint;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && onChanged != null;
    final mark = SettingsType.markSize(context);
    final color = canTap ? UIConstants.appOrange : Colors.white38;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: canTap ? () => onChanged!(!value) : null,
        borderRadius: BorderRadius.circular(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: SizedBox(
                width: mark,
                height: mark,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: color, width: 1.6),
                  ),
                  child: value
                      ? Icon(Icons.check, size: mark * 0.78, color: color)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.start,
                    style: SettingsType.title.copyWith(
                      color: canTap ? Colors.white : Colors.white38,
                    ),
                  ),
                  if (hint != null && hint!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      hint!,
                      textAlign: TextAlign.start,
                      style: SettingsType.hint.copyWith(
                        color: canTap
                            ? SettingsType.hint.color
                            : Colors.white30,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Schieberegler in der Größe des Hakens.
class SettingsCompactSlider extends StatelessWidget {
  const SettingsCompactSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.label,
    this.onChanged,
    this.onChangeEnd,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final mark = SettingsType.markSize(context);
    final enabled = onChanged != null;
    final active = enabled ? UIConstants.appOrange : Colors.white38;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: (mark * 0.18).clamp(2.5, 4.5),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: mark / 2),
        overlayShape: RoundSliderOverlayShape(overlayRadius: mark * 0.85),
        activeTrackColor: active,
        inactiveTrackColor: Colors.white24,
        thumbColor: active,
        overlayColor: UIConstants.appOrange.withValues(alpha: 0.16),
        valueIndicatorColor: UIConstants.appOrange,
        showValueIndicator: ShowValueIndicator.onlyForDiscrete,
      ),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: label,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}
