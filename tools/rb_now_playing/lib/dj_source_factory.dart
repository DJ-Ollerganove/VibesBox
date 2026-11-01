import 'dj_library_prefs.dart';
import 'dj_library_source.dart';
import 'djay_library.dart';
import 'engine_dj_library.dart';
import 'library_match.dart';
import 'mixxx_library.dart';
import 'rekordbox_history.dart';
import 'serato_library.dart';
import 'traktor_library.dart';
import 'virtualdj_library.dart';

DjLibrarySource openDjLibrarySource(DjSoftware software, String? overridePath) {
  switch (software) {
    case DjSoftware.rekordbox:
      final reader = RekordboxHistoryReader();
      final path = overridePath?.trim();
      reader.overrideDbPath = (path == null || path.isEmpty) ? null : path;
      return _RekordboxSource(reader);
    case DjSoftware.serato:
      return SeratoLibrarySource(overridePath);
    case DjSoftware.virtualDj:
      return VirtualDjLibrarySource(overridePath);
    case DjSoftware.traktor:
      return TraktorLibrarySource(overridePath);
    case DjSoftware.mixxx:
      return MixxxLibrarySource(overridePath);
    case DjSoftware.engineDj:
      return EngineDjLibrarySource(overridePath);
    case DjSoftware.djayPro:
      return DjayLibrarySource(overridePath);
  }
}

class _RekordboxSource implements DjLibrarySource {
  _RekordboxSource(this._inner);

  final RekordboxHistoryReader _inner;

  @override
  String get label => 'Rekordbox';

  @override
  HistorySnapshot readHistory() => _inner.read();

  @override
  List<LibraryTrack> readLibrary() => _inner.readLibrary();

  @override
  LibraryPulse libraryPulse() => _inner.libraryPulse();

  @override
  Map<String, int> readPlayCounts() => _inner.readPlayCounts();

  @override
  void close() => _inner.close();
}
