import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/spotify_search_settings_service.dart';

/// Admin: Bearbeitung von [admin_config/spotify_settings] (Blacklist, max. Titel-Länge).
class SpotifySearchFilterSettingsSection extends StatefulWidget {
  const SpotifySearchFilterSettingsSection({super.key});

  @override
  State<SpotifySearchFilterSettingsSection> createState() =>
      _SpotifySearchFilterSettingsSectionState();
}

class _SpotifySearchFilterSettingsSectionState
    extends State<SpotifySearchFilterSettingsSection> {
  final _addController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  late List<String> _terms;
  late double _maxMinutes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SpotifySearchSettingsService.instance.loadOnStartup();
      final s = SpotifySearchSettingsService.instance;
      _terms = List<String>.from(s.keywordSubstringsLower);
      _maxMinutes = (s.maxSongDurationMs / 60000.0).clamp(1.0, 60.0);
    } catch (e) {
      _error = '$e';
      _terms = List<String>.from(SpotifySearchSettingsService.defaultSearchBlacklist);
      _maxMinutes = 15;
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ms = (_maxMinutes * 60000).round().clamp(60000, 3600000);
      await SpotifySearchSettingsService.instance.saveAndApplyLocal(
        searchBlacklist: _terms,
        maxSongDurationMs: ms,
      );
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.spotify_filter_saved),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = '$e');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addTerm() {
    final t = _addController.text.trim().toLowerCase();
    if (t.isEmpty) return;
    if (_terms.contains(t)) {
      _addController.clear();
      return;
    }
    setState(() {
      _terms.add(t);
      _addController.clear();
    });
  }

  void _removeTerm(String t) {
    setState(() => _terms.remove(t));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.spotify_admin_excluded_terms_intro,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _terms
              .map(
                (t) => InputChip(
                  label: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  deleteIconColor: Colors.orange,
                  backgroundColor: const Color(0xFF2A2A2A),
                  onDeleted: () => _removeTerm(t),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _addController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: l.spotify_admin_add_term_hint,
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.orange),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _addTerm(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _addTerm,
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              child: Text(l.spotify_admin_add_button),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l.spotify_admin_max_duration_label(_maxMinutes.round()),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Slider(
          value: _maxMinutes,
          min: 1,
          max: 60,
          divisions: 59,
          label: l.spotify_admin_slider_minutes(_maxMinutes.round()),
          activeColor: Colors.orange,
          inactiveColor: Colors.grey,
          onChanged: (v) => setState(() => _maxMinutes = v),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.save),
          label: Text(
            _saving ? l.saving_in_progress : l.spotify_save_cloud_and_local,
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}
