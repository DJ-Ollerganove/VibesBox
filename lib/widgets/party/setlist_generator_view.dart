import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../helpers/security_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../models/event_setlist_input.dart';
import '../../models/event_setlist_track.dart';
import '../../app_scaffold_messenger.dart';
import '../../services/dj_setlist_library_service.dart';
import '../../services/pro_feature_guard.dart';
import '../../services/setlist_form_draft_service.dart';
import '../../services/setlist_generation_controller.dart';
import '../../utils/setlist_music_request_guard.dart';
import '../../utils/ui_constants.dart';
import '../free_feature_locked.dart';
import 'setlist_export_menu.dart';
import 'setlist_paginated_track_list.dart';
import 'setlist_track_action_icons.dart';

/// Formular oder Ergebnisliste — eingebettet in der Party-Verwaltung.
class SetlistGeneratorView extends StatefulWidget {
  const SetlistGeneratorView({
    super.key,
    required this.onClose,
    this.hidePageChrome = false,
  });

  final VoidCallback onClose;
  /// Im App-Header eingebettet: kein zweites Zurück/Titel.
  final bool hidePageChrome;

  @override
  State<SetlistGeneratorView> createState() => _SetlistGeneratorViewState();
}

class _SetlistGeneratorViewState extends State<SetlistGeneratorView>
    with WidgetsBindingObserver {
  final _occasionOther = TextEditingController();
  final _artistsMust = TextEditingController();
  final _blacklist = TextEditingController();
  final _songCount = TextEditingController(text: '20');
  final _hours = TextEditingController(text: '6');

  String _occasionId = 'wedding';
  final Set<String> _genres = <String>{};
  final List<String> _markets = <String>[];
  final Map<String, int> _marketPercents = <String, int>{};
  final Set<String> _ages = <String>{};
  String _bpmBandId = 'any';
  String _energyCurveId = 'warm_peak_cool';
  String _familiarityId = 'hits';
  String _scopeId = 'strict';

  EventSetlistSizeMode _mode = EventSetlistSizeMode.songs;
  bool _generating = false;
  List<EventSetlistTrack> _tracks = const [];
  String? _libraryListId;
  bool _draftReady = false;
  /// Gesamtdauer der letzten Generierung (Anzeige im Ergebnis).
  String? _elapsedLabel;

  final _job = SetlistGenerationController.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _job.addListener(_onJobChanged);
    _restoreDraft();
  }

  void _onJobChanged() {
    if (!mounted) return;
    setState(() {
      _generating = _job.generating;
      _tracks = _job.tracks;
      _elapsedLabel = _job.elapsedLabel;
      _libraryListId = _job.libraryListId;
    });
    final err = _job.errorMessage;
    if (err == null) return;
    _job.consumeError();
    final l = AppLocalizations.of(context)!;
    if (err == SetlistMusicRequestGuard.rejectedMessage) {
      _showReject(l.translate('dj_setlist_not_music'));
    } else if (err == 'empty') {
      _showReject(l.translate('dj_setlist_no_suggestions'));
    } else if (err.trim().isNotEmpty) {
      _showReject(err);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _persistDraft();
      // Job speichert selbst; hier nur Formular.
    }
    if (state == AppLifecycleState.resumed && mounted) {
      // Nach Display-Aus: UI an laufenden Job / Cache anbinden.
      setState(() {
        _generating = _job.generating;
        _tracks = _job.tracks;
        _elapsedLabel = _job.elapsedLabel;
        _libraryListId = _job.libraryListId;
      });
    }
  }

  Future<void> _restoreDraft() async {
    final draft = await SetlistFormDraftService.load();
    if (!_job.generating) {
      await _job.restoreFromCache();
    }
    if (!mounted) return;
    _occasionOther.text = draft.occasionOther;
    _artistsMust.text = draft.artistsMust;
    _blacklist.text = draft.blacklist;
    _songCount.text = draft.songCount.isEmpty ? '20' : draft.songCount;
    _hours.text = draft.hours.isEmpty ? '6' : draft.hours;
    setState(() {
      _occasionId = draft.occasionId;
      _genres
        ..clear()
        ..addAll(draft.genreIds);
      _markets
        ..clear()
        ..addAll(draft.marketIds);
      _marketPercents
        ..clear()
        ..addAll(draft.marketPercents);
      _ages
        ..clear()
        ..addAll(draft.ages);
      _bpmBandId = draft.bpmBandId;
      _energyCurveId = draft.energyCurveId;
      _familiarityId = draft.familiarityId;
      _scopeId = draft.scopeId;
      _mode = draft.mode;
      _generating = _job.generating;
      _tracks = _job.tracks;
      _elapsedLabel = _job.elapsedLabel;
      _libraryListId = _job.libraryListId;
      _draftReady = true;
    });
  }

  SetlistFormDraft _currentDraft() {
    return SetlistFormDraft(
      occasionId: _occasionId,
      occasionOther: _occasionOther.text,
      genreIds: _genres.toList(),
      artistsMust: _artistsMust.text,
      blacklist: _blacklist.text,
      marketIds: List<String>.from(_markets),
      marketPercents: Map<String, int>.from(_marketPercents),
      bpmBandId: _bpmBandId,
      energyCurveId: _energyCurveId,
      familiarityId: _familiarityId,
      scopeId: _scopeId,
      ages: Set<String>.from(_ages),
      mode: _mode,
      songCount: _songCount.text.trim().isEmpty ? '20' : _songCount.text.trim(),
      hours: _hours.text.trim().isEmpty ? '6' : _hours.text.trim(),
    );
  }

  Future<void> _persistDraft() {
    return SetlistFormDraftService.save(_currentDraft());
  }

  Future<void> _clearFormFields() async {
    await SetlistFormDraftService.clear();
    if (!mounted) return;
    _occasionOther.clear();
    _artistsMust.clear();
    _blacklist.clear();
    _songCount.text = '20';
    _hours.text = '6';
    setState(() {
      _occasionId = 'wedding';
      _genres.clear();
      _markets.clear();
      _marketPercents.clear();
      _ages.clear();
      _bpmBandId = 'any';
      _energyCurveId = 'warm_peak_cool';
      _familiarityId = 'hits';
      _scopeId = 'strict';
      _mode = EventSetlistSizeMode.songs;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _job.removeListener(_onJobChanged);
    // NICHT abbrechen — Suche läuft im Controller weiter (App klein / Screen weg).
    final draft = _currentDraft();
    _occasionOther.dispose();
    _artistsMust.dispose();
    _blacklist.dispose();
    _songCount.dispose();
    _hours.dispose();
    super.dispose();
    SetlistFormDraftService.save(draft);
  }

  EventSetlistInput _readInput(AppLocalizations l) {
    final songs = int.tryParse(_songCount.text.trim()) ?? 20;
    final hours = int.tryParse(_hours.text.trim()) ?? 6;
    return EventSetlistInput(
      occasionId: EventSetlistInput.pickId(
        _occasionId.isEmpty ? 'wedding' : _occasionId,
        EventSetlistInput.occasionOptionIds,
        'wedding',
      ),
      occasionOther: SecurityHelper.sanitize(_occasionOther.text, maxLength: 200),
      genreIds: EventSetlistInput.sanitizeIds(_genres, EventSetlistInput.genreOptionIds),
      artistsMust: SecurityHelper.sanitize(_artistsMust.text, maxLength: 800),
      blacklist: SecurityHelper.sanitize(_blacklist.text, maxLength: 1500),
      ageStructure: _ages.isEmpty
          ? l.translate('dj_setlist_age_mixed')
          : (EventSetlistInput.ageOptionIds
              .where(_ages.contains)
              .map((o) => l.translate('dj_setlist_age_$o'))
              .join(', ')),
      marketIds: EventSetlistInput.sanitizeIds(
        _markets,
        EventSetlistInput.marketOptionIds,
        maxItems: EventSetlistInput.maxMarkets,
      ),
      marketPercents: EventSetlistInput.normalizePercents(
        EventSetlistInput.sanitizeIds(
          _markets,
          EventSetlistInput.marketOptionIds,
          maxItems: EventSetlistInput.maxMarkets,
        ),
        _marketPercents,
      ),
      bpmBandId: EventSetlistInput.pickId(
        _bpmBandId.isEmpty ? 'any' : _bpmBandId,
        EventSetlistInput.bpmBandOptionIds,
        'any',
      ),
      energyCurveId: EventSetlistInput.pickId(
        _energyCurveId.isEmpty ? 'warm_peak_cool' : _energyCurveId,
        EventSetlistInput.energyCurveOptionIds,
        'warm_peak_cool',
      ),
      familiarityId: EventSetlistInput.pickId(
        _familiarityId.isEmpty ? 'hits' : _familiarityId,
        EventSetlistInput.familiarityOptionIds,
        'hits',
      ),
      scopeId: EventSetlistInput.pickId(
        _scopeId.isEmpty ? 'strict' : _scopeId,
        EventSetlistInput.scopeOptionIds,
        'strict',
      ),
      sizeMode: _mode,
      songCount: songs.clamp(
        EventSetlistInput.minSongs,
        EventSetlistInput.maxSongs,
      ),
      durationHours: hours.clamp(
        EventSetlistInput.minHours,
        EventSetlistInput.maxHours,
      ),
    );
  }

  Future<void> _generate() async {
    if (_job.generating) return;
    final l = AppLocalizations.of(context)!;
    if (!ProFeatureGuard.canUseProExclusiveNow()) {
      await FreeFeatureLockedDialog.show(
        context,
        title: l.free_feature_dj_setlist_title,
        description: l.free_feature_dj_setlist_description,
      );
      return;
    }
    final input = _readInput(l);
    if (!SetlistMusicRequestGuard.isMusicRequest(
      eventType: input.eventTypeBlob,
      preferred: input.preferredBlob,
      blacklist: input.blacklist,
      artistsMust: input.artistsMust,
    )) {
      _showReject(l.translate('dj_setlist_not_music'));
      return;
    }
    await _persistDraft();
    await _job.start(input);
  }

  void _showReject(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _resetToForm() {
    _job.clearResult();
    setState(() {
      _tracks = const [];
      _generating = false;
      _libraryListId = null;
      _elapsedLabel = null;
    });
  }

  /// Ergebnisliste lokal + ggf. bereits gespeicherte Library-Liste aktualisieren.
  Future<void> _applyTracks(List<EventSetlistTrack> next) async {
    _job.replaceTracks(next);
    final id = (_libraryListId ?? '').trim();
    if (id.isEmpty) return;
    try {
      await DjSetlistLibraryService.instance.replaceTracks(
        id: id,
        tracks: next,
      );
    } catch (e) {
      if (!mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(l.tp('dj_setlist_action_failed', {'error': '$e'})),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  Future<void> _confirmAbortSearch() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          l.translate('dj_setlist_abort_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l.translate('dj_setlist_abort_body'),
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.translate('dj_setlist_abort_confirm'),
              style: const TextStyle(color: Color(0xFFFF8A80)),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _job.abortAndDiscard();
  }

  String _listTitle(AppLocalizations l) {
    if (_occasionId == 'other' && _occasionOther.text.trim().isNotEmpty) {
      return _occasionOther.text.trim();
    }
    return l.translate('dj_setlist_occasion_$_occasionId');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.hidePageChrome)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () {
                      widget.onClose();
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: Colors.white70,
                    ),
                    label: Text(
                      AppLocalizations.of(context)!.back,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: !_draftReady
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: UIConstants.appOrange,
                        ),
                      ),
                    )
                  : ((_generating || _tracks.isNotEmpty)
                      ? _resultBody()
                      : _formBody()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _formBody() {
    final l = AppLocalizations.of(context)!;
    final hours = int.tryParse(_hours.text.trim()) ?? 6;
    final est = EventSetlistInput.songsForHours(hours);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.hidePageChrome) ...[
            Text(
              l.translate('dj_setlist_create_title'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            l.translate('dj_setlist_gen_intro'),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: GestureDetector(
              onTap: _generating ? null : _clearFormFields,
              child: Text(
                l.translate('dj_setlist_clear_form'),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel(l.translate('dj_setlist_occasion')),
          _pickDropdown(
            allIds: EventSetlistInput.occasionOptionIds,
            selected: {
              if (_occasionId.isNotEmpty) _occasionId,
            },
            multi: false,
            labelOf: (id) => l.translate('dj_setlist_occasion_$id'),
            onAdd: (id) => setState(() => _occasionId = id),
            onRemove: (_) => setState(() => _occasionId = ''),
          ),
          if (_occasionId == 'other')
            _field(
              _occasionOther,
              l.translate('dj_setlist_occasion_other_label'),
              l.translate('dj_setlist_occasion_other_hint'),
              maxLength: 200,
            ),
          _sectionLabel(l.translate('dj_setlist_genres_label')),
          Text(
            l.translate('dj_setlist_genres_hint'),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 6),
          _pickDropdown(
            allIds: EventSetlistInput.genreOptionIds,
            selected: _genres,
            multi: true,
            labelOf: (id) => l.translate('dj_setlist_genre_$id'),
            onAdd: (id) => setState(() => _genres.add(id)),
            onRemove: (id) => setState(() => _genres.remove(id)),
          ),
          _field(
            _artistsMust,
            l.translate('dj_setlist_artists_label'),
            l.translate('dj_setlist_artists_hint'),
            maxLines: 2,
            maxLength: 800,
          ),
          _field(
            _blacklist,
            l.translate('dj_setlist_gen_blacklist'),
            l.translate('dj_setlist_gen_blacklist_hint'),
            maxLines: 2,
          ),
          _sectionLabel(l.translate('dj_setlist_age_structure')),
          _pickDropdown(
            allIds: EventSetlistInput.ageOptionIds,
            selected: _ages,
            multi: true,
            labelOf: (id) => l.translate('dj_setlist_age_$id'),
            onAdd: (id) => setState(() => _ages.add(id)),
            onRemove: (id) => setState(() => _ages.remove(id)),
          ),
          _sectionLabel(l.translate('dj_setlist_market_label')),
          Text(
            l.translate('dj_setlist_market_hint'),
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 6),
          _pickDropdown(
            allIds: EventSetlistInput.marketOptionIds,
            selected: _markets.toSet(),
            multi: true,
            maxSelected: EventSetlistInput.maxMarkets,
            labelOf: (id) => l.translate('dj_setlist_market_$id'),
            onAdd: _addMarket,
            onRemove: _removeMarket,
          ),
          if (_markets.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              l.tp('dj_setlist_market_percent_sum', {
                'sum': '${_percentSum()}',
              }),
              style: TextStyle(
                color: _percentSum() == 100
                    ? Colors.white54
                    : const Color(0xFFFF8A80),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            for (final id in _markets) _marketPercentSlider(l, id),
          ],
          _sectionLabel(l.translate('dj_setlist_bpm_label')),
          _pickDropdown(
            allIds: EventSetlistInput.bpmBandOptionIds,
            selected: {
              if (_bpmBandId.isNotEmpty) _bpmBandId,
            },
            multi: false,
            labelOf: (id) => l.translate('dj_setlist_bpm_$id'),
            onAdd: (id) => setState(() => _bpmBandId = id),
            onRemove: (_) => setState(() => _bpmBandId = ''),
          ),
          _sectionLabel(l.translate('dj_setlist_energy_label')),
          _pickDropdown(
            allIds: EventSetlistInput.energyCurveOptionIds,
            selected: {
              if (_energyCurveId.isNotEmpty) _energyCurveId,
            },
            multi: false,
            labelOf: (id) => l.translate('dj_setlist_energy_$id'),
            onAdd: (id) => setState(() => _energyCurveId = id),
            onRemove: (_) => setState(() => _energyCurveId = ''),
          ),
          _sectionLabel(l.translate('dj_setlist_familiarity_label')),
          _pickDropdown(
            allIds: EventSetlistInput.familiarityOptionIds,
            selected: {
              if (_familiarityId.isNotEmpty) _familiarityId,
            },
            multi: false,
            labelOf: (id) => l.translate('dj_setlist_familiarity_$id'),
            onAdd: (id) => setState(() => _familiarityId = id),
            onRemove: (_) => setState(() => _familiarityId = ''),
          ),
          _sectionLabel(l.translate('dj_setlist_scope_label')),
          _pickDropdown(
            allIds: EventSetlistInput.scopeOptionIds,
            selected: {
              if (_scopeId.isNotEmpty) _scopeId,
            },
            multi: false,
            labelOf: (id) => l.translate('dj_setlist_scope_$id'),
            onAdd: (id) => setState(() => _scopeId = id),
            onRemove: (_) => setState(() => _scopeId = ''),
          ),
          const SizedBox(height: 8),
          _sectionLabel(l.translate('dj_setlist_length')),
          _pickDropdown(
            allIds: const <String>['songs', 'duration'],
            selected: {_mode == EventSetlistSizeMode.duration ? 'duration' : 'songs'},
            multi: false,
            labelOf: (id) => id == 'duration'
                ? l.translate('dj_setlist_duration')
                : l.translate('dj_setlist_song_count'),
            onAdd: (id) => setState(() {
              _mode = id == 'duration'
                  ? EventSetlistSizeMode.duration
                  : EventSetlistSizeMode.songs;
            }),
            onRemove: (_) {},
            allowClear: false,
          ),
          const SizedBox(height: 8),
          if (_mode == EventSetlistSizeMode.songs)
            _numberField(
              _songCount,
              l.translate('dj_setlist_song_count_range'),
              EventSetlistInput.maxSongs,
              l,
            )
          else ...[
            _numberField(
              _hours,
              l.translate('dj_setlist_duration_hours'),
              EventSetlistInput.maxHours,
              l,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.tp('dj_setlist_approx_songs', {'count': '$est'}),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _generating ? null : _generate,
            style: ElevatedButton.styleFrom(
              backgroundColor: UIConstants.colorDjSetlist,
              foregroundColor: Colors.black,
              disabledBackgroundColor:
                  UIConstants.colorDjSetlist.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              l.translate('dj_setlist_generate'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultBody() {
    final l = AppLocalizations.of(context)!;
    final elapsed = (_elapsedLabel ?? '').trim();
    final titleText = elapsed.isEmpty
        ? l.tp('dj_setlist_suggestions', {'count': '${_tracks.length}'})
        : l.tp('dj_setlist_result_timing', {
            'count': '${_tracks.length}',
            'time': elapsed,
          });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_generating)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFFD54F),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.translate(
                      _tracks.isEmpty
                          ? 'dj_setlist_creating'
                          : 'dj_setlist_refining',
                    ),
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _job.stopKeepingResults(),
                  child: Text(
                    l.translate('dj_setlist_stop'),
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _confirmAbortSearch,
                  tooltip: l.cancel,
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  titleText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _generating ? null : _resetToForm,
                child: Text(l.translate('dj_setlist_back_new')),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ElevatedButton.icon(
            onPressed: _generating
                ? null
                : () async {
                    final id = await SetlistExportMenu.show(
                      context: context,
                      tracks: _tracks,
                      listTitle: _listTitle(l),
                      libraryListId: _libraryListId,
                    );
                    if (!mounted) return;
                    if (id != null && id.isNotEmpty) {
                      _job.setLibraryListId(id);
                    }
                  },
            icon: const Icon(Icons.ios_share),
            label: Text(l.pre_wish_export),
            style: ElevatedButton.styleFrom(
              backgroundColor: UIConstants.colorDjSetlist,
              foregroundColor: Colors.black,
              disabledBackgroundColor:
                  UIConstants.colorDjSetlist.withValues(alpha: 0.35),
            ),
          ),
        ),
        Expanded(
          child: SetlistPaginatedTrackList(
            key: ValueKey(
              '${_tracks.length}-${_tracks.isEmpty ? '' : _tracks.first.title}',
            ),
            tracks: _tracks,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            onReorder: _generating
                ? null
                : (next) {
                    _applyTracks(next);
                  },
            onEdit: _generating
                ? null
                : (index, track) async {
                    final edited = await SetlistTrackActionIcons.editTrack(
                      context,
                      title: track.title,
                      artist: track.artist,
                    );
                    if (edited == null || !mounted) return;
                    final next = [..._tracks];
                    if (index < 0 || index >= next.length) return;
                    next[index] = track.copyWith(
                      title: edited.title,
                      artist: edited.artist,
                    );
                    await _applyTracks(next);
                  },
            onDelete: _generating
                ? null
                : (index, track) async {
                    final ok = await SetlistTrackActionIcons.confirmDelete(
                      context,
                      title: track.title,
                      artist: track.artist,
                    );
                    if (!ok || !mounted) return;
                    await _applyTracks([..._tracks]..removeAt(index));
                  },
          ),
        ),
      ],
    );
  }

  void _addMarket(String id) {
    if (_markets.contains(id)) return;
    if (_markets.length >= EventSetlistInput.maxMarkets) return;
    setState(() {
      _markets.add(id);
      _marketPercents
        ..clear()
        ..addAll(EventSetlistInput.equalPercents(_markets));
    });
  }

  void _removeMarket(String id) {
    setState(() {
      _markets.remove(id);
      _marketPercents.remove(id);
      if (_markets.isEmpty) {
        _marketPercents.clear();
      } else {
        final next = EventSetlistInput.normalizePercents(
          _markets,
          _marketPercents,
        );
        _marketPercents
          ..clear()
          ..addAll(next);
      }
    });
  }

  void _setMarketPercent(String id, int value) {
    setState(() {
      final next = EventSetlistInput.setPercentKeepingSum(
        _markets,
        _marketPercents,
        id,
        value,
      );
      _marketPercents
        ..clear()
        ..addAll(next);
    });
  }

  int _percentSum() =>
      _marketPercents.values.fold<int>(0, (a, b) => a + b);

  Widget _marketPercentSlider(AppLocalizations l, String id) {
    final pct = _marketPercents[id] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.translate('dj_setlist_market_$id'),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  color: UIConstants.colorDjSetlist,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: UIConstants.colorDjSetlist,
              inactiveTrackColor: Colors.white24,
              thumbColor: UIConstants.colorDjSetlist,
              overlayColor: UIConstants.colorDjSetlist.withValues(alpha: 0.2),
              valueIndicatorColor: UIConstants.colorDjSetlist,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Slider(
              value: pct.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '$pct%',
              onChanged: _generating
                  ? null
                  : (v) => _setMarketPercent(id, v.round()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  /// Dropdown im Setlist-Stil: Auswahl fliegt raus, erscheint als Chip mit X.
  Widget _pickDropdown({
    required List<String> allIds,
    required Set<String> selected,
    required bool multi,
    required String Function(String id) labelOf,
    required void Function(String id) onAdd,
    required void Function(String id) onRemove,
    bool allowClear = true,
    int? maxSelected,
  }) {
    final l = AppLocalizations.of(context)!;
    final atMax =
        maxSelected != null && selected.length >= maxSelected;
    final available = allIds.where((id) => !selected.contains(id)).toList()
      ..sort((a, b) {
        final la = labelOf(a);
        final lb = labelOf(b);
        return la.toLowerCase().compareTo(lb.toLowerCase());
      });
    // Auswahl-Chips: Reihenfolge der Auswahl beibehalten (nicht alphabetisch).
    final selectedOrdered = selected.toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (available.isNotEmpty && !atMax)
            DropdownButtonFormField<String>(
              key: ValueKey(
                'pick-${allIds.length}-${selected.join(',')}-${available.length}',
              ),
              initialValue: null,
              isExpanded: true,
              dropdownColor: const Color(0xFF2A2A2A),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              iconEnabledColor: UIConstants.colorDjSetlist,
              decoration: InputDecoration(
                hintText: maxSelected != null
                    ? l.tp('dj_setlist_pick_hint_max', {
                        'max': '$maxSelected',
                      })
                    : l.translate('dj_setlist_pick_hint'),
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                contentPadding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white38),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: UIConstants.colorDjSetlist,
                    width: 1.5,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
              items: [
                for (final id in available)
                  DropdownMenuItem<String>(
                    value: id,
                    child: Text(
                      labelOf(id),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _generating
                  ? null
                  : (value) {
                      if (value == null) return;
                      if (!multi && selected.isNotEmpty) {
                        for (final old in selected.toList()) {
                          onRemove(old);
                        }
                      }
                      onAdd(value);
                    },
            )
          else if (atMax)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l.tp('dj_setlist_pick_max_reached', {'max': '$maxSelected'}),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          if (selectedOrdered.isNotEmpty) ...[
            if (available.isNotEmpty && !atMax) const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in selectedOrdered)
                  InputChip(
                    label: Text(labelOf(id)),
                    onDeleted: (_generating || !allowClear)
                        ? null
                        : () => onRemove(id),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    deleteIconColor: Colors.black87,
                    backgroundColor: UIConstants.colorDjSetlist,
                    side: BorderSide.none,
                    labelStyle: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    int maxLength = 1500,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        enabled: !_generating,
        maxLines: maxLines,
        maxLength: maxLength,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          alignLabelWithHint: true,
          labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
          floatingLabelStyle: const TextStyle(
            color: Color(0xFFFFF59D),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          counterText: '',
          contentPadding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.white38),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: UIConstants.colorDjSetlist,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    int max,
    AppLocalizations l,
  ) {
    return TextField(
      controller: controller,
      enabled: !_generating,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(color: Colors.white),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFFFFF59D),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        contentPadding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white38),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: UIConstants.colorDjSetlist,
            width: 1.5,
          ),
        ),
        helperText: l.tp('dj_setlist_maximum', {'max': '$max'}),
        helperStyle: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }
}
