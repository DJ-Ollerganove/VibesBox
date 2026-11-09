import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scaffold_messenger.dart';
import '../l10n/app_localizations.dart';
import '../services/grace_period_settings_service.dart';
import '../utils/debug_log.dart';
import '../utils/firebase_error_message.dart';
import '../utils/ui_constants.dart';
import 'settings_choice_row.dart';

/// DJ-Einstellung: Nachlaufzeit für offene Wünsche nach Party-Ende (0–120 Min., Schritt 10).
class GracePeriodSettingsSection extends StatefulWidget {
  const GracePeriodSettingsSection({
    super.key,
    required this.textDirectionRtl,
  });

  final bool textDirectionRtl;

  @override
  State<GracePeriodSettingsSection> createState() =>
      _GracePeriodSettingsSectionState();
}

class _GracePeriodSettingsSectionState extends State<GracePeriodSettingsSection> {
  int _value = GracePeriodSettingsService.defaultGracePeriodMinutes;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await GracePeriodSettingsService.load();
    if (mounted) {
      setState(() {
        _value = v;
        _loading = false;
      });
    }
  }

  int _snapSlider(double raw) =>
      ((raw / GracePeriodSettingsService.stepGracePeriodMinutes).round() *
          GracePeriodSettingsService.stepGracePeriodMinutes);

  Future<void> _onChanged(int next) async {
    if (next == _value || _saving) return;
    setState(() {
      _value = next;
      _saving = true;
    });
    try {
      await GracePeriodSettingsService.save(next);
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(context, 
        SnackBar(
          content: Text(l.settingsGracePeriodSaved(next)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, st) {
      debugLog('❌ Nachlaufzeit speichern fehlgeschlagen: $e\n$st');
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(l.snackbar_error_details(formatFirebaseErrorDetail(e))),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment:
              isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              l.settings_grace_period_title,
              style: SettingsType.title.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  ),
                ),
              )
            else ...[
              Text(
                l.settingsGracePeriodMinutes(_value),
                style: SettingsType.title.copyWith(
                  color: UIConstants.appOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SettingsCompactSlider(
                value: _value.toDouble(),
                min: GracePeriodSettingsService.minGracePeriodMinutes
                    .toDouble(),
                max: GracePeriodSettingsService.maxGracePeriodMinutes
                    .toDouble(),
                divisions: GracePeriodSettingsService.maxGracePeriodMinutes ~/
                    GracePeriodSettingsService.stepGracePeriodMinutes,
                label: l.settingsGracePeriodMinutes(_value),
                onChanged: _saving
                    ? null
                    : (raw) {
                        final snapped = _snapSlider(raw);
                        if (snapped != _value) {
                          unawaited(_onChanged(snapped));
                        }
                      },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.settingsGracePeriodMinutes(0),
                    style: SettingsType.scaleEnd,
                  ),
                  Text(
                    l.settingsGracePeriodMinutes(
                      GracePeriodSettingsService.maxGracePeriodMinutes,
                    ),
                    style: SettingsType.scaleEnd,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l.translate('info_settings_grace_duration_body'),
                style: SettingsType.hint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
