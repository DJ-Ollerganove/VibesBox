import 'library_match.dart';
import 'rekordbox_history.dart';

abstract class DjLibrarySource {
  String get label;
  HistorySnapshot readHistory();
  List<LibraryTrack> readLibrary();
  LibraryPulse libraryPulse();
  Map<String, int> readPlayCounts();
  void close();
}

String? textOrNull(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? intOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? doubleOrNull(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
