import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/dj_pro_session_service.dart';
import '../services/pro_feature_guard.dart';
import '../services/song_recommendation_settings_service.dart';
import 'free_feature_locked.dart';
import 'settings_choice_row.dart';

/// Kleines DJ-Widget: Vorschlags-KI ein/aus plus Musikraum und Bekanntheit.
class SongRecommendationSettingsCard extends StatefulWidget {
  const SongRecommendationSettingsCard({super.key});

  @override
  State<SongRecommendationSettingsCard> createState() =>
      _SongRecommendationSettingsCardState();
}

class _SongRecommendationSettingsCardState
    extends State<SongRecommendationSettingsCard> {
  late SongRecommendationSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = SongRecommendationSettings.defaults;
    SongRecommendationSettingsService.instance.notifier.addListener(
      _syncFromNotifier,
    );
    _load();
  }

  @override
  void dispose() {
    SongRecommendationSettingsService.instance.notifier.removeListener(
      _syncFromNotifier,
    );
    super.dispose();
  }

  void _syncFromNotifier() {
    if (!mounted) return;
    final next = SongRecommendationSettingsService.instance.notifier.value;
    if (next == _settings) return;
    setState(() => _settings = next);
  }

  Future<void> _load() async {
    final loaded =
        await SongRecommendationSettingsService.instance.ensureLoaded();
    if (!mounted) return;
    setState(() => _settings = loaded);
  }

  Future<void> _apply(SongRecommendationSettings next) async {
    if (next == _settings) return;
    setState(() => _settings = next);
    await SongRecommendationSettingsService.instance.save(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ValueListenableBuilder<SessionProStatus?>(
      valueListenable: DjProSessionService.instance.sessionProStatus,
      builder: (context, _, __) {
        final isPro = ProFeatureGuard.canUseProExclusiveNow();
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.settings_song_rec_title,
                        style: SettingsType.title.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!isPro)
                      ProUnlockInfoIcon(
                        title: l.free_feature_song_rec_title,
                        description: l.free_feature_song_rec_description,
                      ),
                  ],
                ),
                SettingsChoiceRow(
                  value: isPro && _settings.enabled,
                  enabled: isPro,
                  title: (isPro && _settings.enabled)
                      ? l.translate('settings_song_rec_on')
                      : l.translate('settings_song_rec_off'),
                  hint: isPro
                      ? l.translate('info_settings_song_rec_enabled_body')
                      : l.free_feature_song_rec_description,
                  onChanged: isPro
                      ? (v) => _apply(_settings.copyWith(enabled: v))
                      : null,
                ),
                if (isPro && _settings.enabled) ...[
                  const SizedBox(height: 10),
                  SongRecommendationQueryChips(
                    settings: _settings,
                    onChanged: _apply,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Musikraum / Bekanntheit — Einstellungen und Vorschlags-Overlay.
class SongRecommendationQueryChips extends StatelessWidget {
  const SongRecommendationQueryChips({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final SongRecommendationSettings settings;
  final ValueChanged<SongRecommendationSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          settingsPlainLabel(l.translate('info_settings_song_rec_scope')),
          style: SettingsType.title,
        ),
        const SizedBox(height: 2),
        Text(
          l.translate('info_settings_song_rec_scope_body'),
          style: SettingsType.hint,
        ),
        SettingsChoiceRow(
          value: settings.scope == SongRecScope.strict,
          title: l.settings_song_rec_scope_strict,
          onChanged: (_) {
            if (settings.scope == SongRecScope.strict) return;
            onChanged(settings.copyWith(scope: SongRecScope.strict));
          },
        ),
        SettingsChoiceRow(
          value: settings.scope == SongRecScope.similar,
          title: l.settings_song_rec_scope_similar,
          onChanged: (_) {
            if (settings.scope == SongRecScope.similar) return;
            onChanged(settings.copyWith(scope: SongRecScope.similar));
          },
        ),
        SettingsChoiceRow(
          value: settings.scope == SongRecScope.bold,
          title: l.settings_song_rec_scope_bold,
          onChanged: (_) {
            if (settings.scope == SongRecScope.bold) return;
            onChanged(settings.copyWith(scope: SongRecScope.bold));
          },
        ),
        Text(
          settingsPlainLabel(l.translate('info_settings_song_rec_familiarity')),
          style: SettingsType.title,
        ),
        const SizedBox(height: 2),
        Text(
          l.translate('info_settings_song_rec_familiarity_body'),
          style: SettingsType.hint,
        ),
        SettingsChoiceRow(
          value: settings.familiarity == SongRecFamiliarity.hits,
          title: l.settings_song_rec_familiarity_hits,
          onChanged: (_) {
            if (settings.familiarity == SongRecFamiliarity.hits) return;
            onChanged(settings.copyWith(familiarity: SongRecFamiliarity.hits));
          },
        ),
        SettingsChoiceRow(
          value: settings.familiarity == SongRecFamiliarity.mix,
          title: l.settings_song_rec_familiarity_mix,
          onChanged: (_) {
            if (settings.familiarity == SongRecFamiliarity.mix) return;
            onChanged(settings.copyWith(familiarity: SongRecFamiliarity.mix));
          },
        ),
        SettingsChoiceRow(
          value: settings.allowSameArtist,
          title: settingsPlainLabel(
            l.translate('info_settings_song_rec_same_artist'),
          ),
          hint: l.translate('info_settings_song_rec_same_artist_body'),
          onChanged: (v) => onChanged(settings.copyWith(allowSameArtist: v)),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                settingsPlainLabel(l.translate('info_settings_song_rec_count')),
                style: SettingsType.title,
              ),
            ),
            DropdownButton<int>(
              value: settings.count,
              dropdownColor: const Color(0xFF2A2A2A),
              underline: const SizedBox.shrink(),
              style: SettingsType.title,
              items: [
                for (var n = SongRecommendationSettings.minCount;
                    n <= SongRecommendationSettings.maxCount;
                    n++)
                  DropdownMenuItem<int>(
                    value: n,
                    child: Text('$n'),
                  ),
              ],
              onChanged: (v) {
                if (v == null || v == settings.count) return;
                onChanged(settings.copyWith(count: v));
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l.translate('info_settings_song_rec_count_body'),
          style: SettingsType.hint,
        ),
      ],
    );
  }
}
