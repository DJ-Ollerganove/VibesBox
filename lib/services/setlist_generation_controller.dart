import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/event_setlist_input.dart';
import '../models/event_setlist_track.dart';
import '../utils/debug_log.dart';
import '../utils/setlist_music_request_guard.dart';
import 'event_setlist_service.dart';
import 'setlist_session_cache.dart';

/// Läuft unabhängig vom Widget — auch wenn die App klein ist oder der Screen weg ist.
class SetlistGenerationController extends ChangeNotifier {
  SetlistGenerationController._();

  static final SetlistGenerationController instance =
      SetlistGenerationController._();

  bool _generating = false;
  bool _cancel = false;
  bool _discardOnCancel = false;
  List<EventSetlistTrack> _tracks = const [];
  String? _elapsedLabel;
  String? _libraryListId;
  String? _errorMessage;
  int _target = 0;
  final Stopwatch _sw = Stopwatch();

  bool get generating => _generating;
  List<EventSetlistTrack> get tracks => _tracks;
  String? get elapsedLabel => _elapsedLabel;
  String? get libraryListId => _libraryListId;
  String? get errorMessage => _errorMessage;
  int get target => _target;
  bool get hasResult => _tracks.isNotEmpty;

  Future<void> restoreFromCache() async {
    if (_generating) return;
    final session = await SetlistSessionCache.load();
    if (session.tracks.isEmpty) return;
    _tracks = session.tracks;
    _elapsedLabel = session.elapsedLabel;
    _libraryListId = session.libraryListId;
    _generating = false;
    notifyListeners();
  }

  Future<void> start(EventSetlistInput input) async {
    if (_generating) return;
    _cancel = false;
    _discardOnCancel = false;
    _errorMessage = null;
    _tracks = const [];
    _elapsedLabel = null;
    _libraryListId = null;
    _target = input.resolvedSongCount;
    _generating = true;
    _sw
      ..reset()
      ..start();
    notifyListeners();
    await SetlistSessionCache.clear();
    try {
      await WakelockPlus.enable();
    } catch (_) {}

    try {
      final items = await EventSetlistService.instance.generate(
        input: input,
        isCancelled: () => _cancel,
        onPartial: (soFar) {
          if (_cancel || soFar.isEmpty) return;
          _tracks = List<EventSetlistTrack>.from(soFar);
          notifyListeners();
          SetlistSessionCache.save(
            tracks: _tracks,
            elapsedLabel: null,
            libraryListId: _libraryListId,
            generating: true,
            target: _target,
          );
        },
      );
      if (_discardOnCancel) {
        _sw.stop();
        _generating = false;
        _tracks = const [];
        _elapsedLabel = null;
        notifyListeners();
        await SetlistSessionCache.clear();
        return;
      }
      if (_cancel) {
        _sw.stop();
        _generating = false;
        if (_tracks.isNotEmpty) {
          _elapsedLabel = _formatElapsed(_sw.elapsed);
        }
        notifyListeners();
        await _persist();
        return;
      }
      _sw.stop();
      _tracks = items;
      _elapsedLabel = _formatElapsed(_sw.elapsed);
      _generating = false;
      notifyListeners();
      await _persist();
      if (items.isEmpty) {
        _errorMessage = SetlistMusicRequestGuard.rejectedMessage;
        notifyListeners();
      }
    } on SetlistRejectedException catch (e) {
      _sw.stop();
      _generating = false;
      _tracks = const [];
      _elapsedLabel = null;
      _errorMessage = e.message;
      notifyListeners();
      await SetlistSessionCache.clear();
    } catch (e) {
      debugLog('SetlistGenerationController: $e');
      _sw.stop();
      _generating = false;
      if (_discardOnCancel) {
        _tracks = const [];
        _elapsedLabel = null;
        notifyListeners();
        await SetlistSessionCache.clear();
        return;
      }
      if (_tracks.isNotEmpty) {
        _elapsedLabel = _formatElapsed(_sw.elapsed);
      }
      if (_tracks.isEmpty) {
        _errorMessage = 'empty';
      }
      notifyListeners();
      await _persist();
    } finally {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }
  }

  void cancel() {
    _cancel = true;
  }

  /// Suche beenden, bisherige Songs behalten.
  void stopKeepingResults() {
    _discardOnCancel = false;
    _cancel = true;
  }

  /// Suche abbrechen und Ergebnisse verwerfen.
  void abortAndDiscard() {
    _discardOnCancel = true;
    _cancel = true;
    _tracks = const [];
    _elapsedLabel = null;
    _libraryListId = null;
    _errorMessage = null;
    _generating = false;
    _target = 0;
    notifyListeners();
    SetlistSessionCache.clear();
  }

  void clearResult() {
    abortAndDiscard();
  }

  void replaceTracks(List<EventSetlistTrack> next) {
    _tracks = List<EventSetlistTrack>.from(next);
    notifyListeners();
    _persist();
  }

  void setLibraryListId(String? id) {
    _libraryListId = (id ?? '').trim().isEmpty ? null : id!.trim();
    notifyListeners();
    _persist();
  }

  void consumeError() {
    _errorMessage = null;
  }

  Future<void> _persist() {
    return SetlistSessionCache.save(
      tracks: _tracks,
      elapsedLabel: _elapsedLabel,
      libraryListId: _libraryListId,
      generating: _generating,
      target: _target,
    );
  }

  static String _formatElapsed(Duration d) {
    final totalSec = d.inSeconds;
    if (totalSec < 60) return '$totalSec Sek';
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    if (m < 60) {
      return s == 0 ? '$m Min' : '$m Min $s Sek';
    }
    final h = m ~/ 60;
    final min = m % 60;
    if (min == 0 && s == 0) return '$h Std';
    if (s == 0) return '$h Std $min Min';
    return '$h Std $min Min $s Sek';
  }
}
