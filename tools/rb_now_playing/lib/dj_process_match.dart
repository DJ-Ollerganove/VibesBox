/// Prozess-/App-Namen-Matching für integrierte DJ-Softwares.
/// Keep in sync with windows/runner/dj_watchdog.cpp.
bool isIntegratedDjProcessName(String raw) {
  final lower = raw.trim().toLowerCase();
  if (lower.isEmpty) return false;
  if (lower.contains('vibesbox')) return false;

  if (lower.contains('rekordbox') && !lower.contains('agent')) return true;
  if (lower.contains('serato')) return true;
  if (lower.contains('mixxx')) return true;
  if (lower.contains('traktor')) return true;
  if (lower.contains('virtualdj') ||
      lower.contains('virtual dj') ||
      lower.contains('atomix')) {
    return true;
  }
  if (lower.contains('djay')) return true;
  if (lower.contains('enginedj') ||
      lower.contains('engine dj') ||
      lower.contains('engine prime')) {
    return true;
  }
  // Windows-Image manchmal nur „Engine.exe“.
  if (lower == 'engine.exe' || lower == 'engine') return true;
  return false;
}
