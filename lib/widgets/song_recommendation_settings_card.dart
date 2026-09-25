import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/dj_pro_session_service.dart';
import '../services/pro_feature_guard.dart';
import '../services/song_recommendation_settings_service.dart';
import '../utils/ui_constants.dart';
import 'free_feature_locked.dart';
import 'settings_help_dialog.dart';
import 'settings_info_icon_button.dart';

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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Switch(
                      value: isPro && _settings.enabled,
                      activeThumbColor: UIConstants.appOrange,
                      activeTrackColor:
                          UIConstants.appOrange.withValues(alpha: 0.42),
                      onChanged: isPro
                          ? (v) => _apply(_settings.copyWith(enabled: v))
                          : null,
                    ),
                    if (isPro)
                      SettingsInfoIconButton(
                        tooltip: l.settings_help_tooltip,
                        onPressed: () => showSettingsHelpFromL10n(
                          context,
                          titleKey: 'settings_song_rec_title',
                          introKey: 'info_settings_song_rec_intro',
                          bullets: const [
                            (
                              'info_settings_song_rec_enabled',
                              'info_settings_song_rec_enabled_body',
                            ),
                            (
                              'info_settings_song_rec_scope',
                              'info_settings_song_rec_scope_body',
                            ),
                            (
                              'info_settings_song_rec_familiarity',
                              'info_settings_song_rec_familiarity_body',
                            ),
                            (
                              'info_settings_song_rec_same_artist',
                              'info_settings_song_rec_same_artist_body',
                            ),
                            (
                              'info_settings_song_rec_count',
                              'info_settings_song_rec_count_body',
                            ),
                          ],
                        ),
                      )
                    else
                      ProUnlockInfoIcon(
                        title: l.free_feature_song_rec_title,
                        description: l.free_feature_song_rec_description,
                      ),
                  ],
                ),
                Text(
                  isPro
                      ? l.settings_song_rec_subtitle
                      : l.free_feature_song_rec_description,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
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
          l.settings_song_rec_scope,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 6),
        _ChipRow<SongRecScope>(
          value: settings.scope,
          options: [
            (SongRecScope.strict, l.settings_song_rec_scope_strict),
            (SongRecScope.similar, l.settings_song_rec_scope_similar),
            (SongRecScope.bold, l.settings_song_rec_scope_bold),
          ],
          onSelected: (v) => onChanged(settings.copyWith(scope: v)),
        ),
        const SizedBox(height: 12),
        Text(
          l.settings_song_rec_familiarity,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 6),
        _ChipRow<SongRecFamiliarity>(
          value: settings.familiarity,
          options: [
            (SongRecFamiliarity.hits, l.settings_song_rec_familiarity_hits),
            (SongRecFamiliarity.mix, l.settings_song_rec_familiarity_mix),
          ],
          onSelected: (v) => onChanged(settings.copyWith(familiarity: v)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.settings_song_rec_same_artist,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.settings_song_rec_same_artist_hint,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
            Switch(
              value: settings.allowSameArtist,
              activeThumbColor: UIConstants.appOrange,
              activeTrackColor: UIConstants.appOrange.withValues(alpha: 0.42),
              onChanged: (v) =>
                  onChanged(settings.copyWith(allowSameArtist: v)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                l.settings_song_rec_count,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
            DropdownButton<int>(
              value: settings.count,
              dropdownColor: const Color(0xFF2A2A2A),
              underline: const SizedBox.shrink(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
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
          l.settings_song_rec_count_hint,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}

class _ChipRow<T> extends StatelessWidget {
  const _ChipRow({
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option.$2),
            selected: value == option.$1,
            onSelected: (_) {
              if (value == option.$1) return;
              onSelected(option.$1);
            },
            selectedColor: UIConstants.appOrange,
            backgroundColor: const Color(0xFF2A2A2A),
            labelStyle: TextStyle(
              color: value == option.$1 ? Colors.black : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(
              color: value == option.$1
                  ? UIConstants.appOrange
                  : Colors.white24,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}
