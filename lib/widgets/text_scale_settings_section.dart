import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/text_scale_service.dart';
import '../utils/ui_constants.dart';
import 'settings_choice_row.dart';

/// Schriftgrößen-Karte (Slider) — gleiche Darstellung wie in den DJ-Einstellungen,
/// wiederverwendbar z. B. für Gast-Einstellungen.
class TextScaleSettingsSection extends StatefulWidget {
  const TextScaleSettingsSection({
    super.key,
    required this.textDirectionRtl,
  });

  final bool textDirectionRtl;

  @override
  State<TextScaleSettingsSection> createState() =>
      _TextScaleSettingsSectionState();
}

class _TextScaleSettingsSectionState extends State<TextScaleSettingsSection> {
  late int _stepIndex;

  int get _maxStep => TextScaleService.allowedSteps.length - 1;

  @override
  void initState() {
    super.initState();
    _stepIndex =
        TextScaleService.stepIndexFromFactor(TextScaleService.instance.factor);
    TextScaleService.instance.userFactor.addListener(_onFactorChanged);
  }

  void _onFactorChanged() {
    if (!mounted) return;
    final next = TextScaleService.stepIndexFromFactor(
      TextScaleService.instance.factor,
    );
    if (next != _stepIndex) {
      setState(() => _stepIndex = next);
    }
  }

  @override
  void dispose() {
    TextScaleService.instance.userFactor.removeListener(_onFactorChanged);
    super.dispose();
  }

  static String stepLabel(AppLocalizations l, int step) {
    final max = TextScaleService.allowedSteps.length - 1;
    switch (step.clamp(0, max)) {
      case 0:
        return l.settings_text_scale_smallest;
      case 1:
        return l.settings_text_scale_small;
      case 2:
        return l.settings_text_scale_normal;
      case 3:
        return l.settings_text_scale_large;
      default:
        return l.settings_text_scale_largest;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = widget.textDirectionRtl;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: isRtl
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              l.settings_text_scale_title,
              style: SettingsType.title.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SettingsCompactSlider(
              value: _stepIndex.toDouble().clamp(0, _maxStep.toDouble()),
              min: 0,
              max: _maxStep.toDouble(),
              divisions: _maxStep,
              label: stepLabel(l, _stepIndex),
              onChanged: (v) {
                final idx = v.round().clamp(0, _maxStep);
                setState(() => _stepIndex = idx);
                unawaited(
                  TextScaleService.instance.setFactor(
                    TextScaleService.factorFromStepIndex(idx),
                  ),
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i <= _maxStep; i++)
                  Expanded(
                    child: Text(
                      stepLabel(l, i),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SettingsType.scaleEnd.copyWith(
                        color: i == _stepIndex
                            ? UIConstants.appOrange
                            : SettingsType.scaleEnd.color,
                        fontWeight: i == _stepIndex
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l.translate('info_settings_text_scale_slider_body'),
              style: SettingsType.hint,
            ),
          ],
        ),
      ),
    );
  }
}
