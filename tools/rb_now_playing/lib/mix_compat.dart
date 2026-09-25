import 'camelot.dart';

/// BPM-Fenster je Musikraum — analog zum KI-Mixhinweis (±6 streng).
int mixBpmWindow(String scope) {
  switch (scope) {
    case 'strict':
      return 6;
    case 'bold':
      return 20;
    default:
      return 12;
  }
}

int camelotNeighborDistance(String scope) {
  switch (scope) {
    case 'strict':
      return 1;
    case 'bold':
      return 2;
    default:
      return 1;
  }
}

bool bpmMixable(double? seed, double? candidate, {required int window}) {
  if (seed == null || candidate == null) return false;
  if (seed < 60 || seed > 220 || candidate < 60 || candidate > 220) {
    return false;
  }
  return (seed - candidate).abs() <= window;
}

bool camelotMixable(
  String? seed,
  String? candidate, {
  required int neighborDistance,
}) {
  final a = camelotFromScaleName(seed);
  final b = camelotFromScaleName(candidate);
  if (a == null || b == null) return false;
  if (a == b) return true;
  final parsedA = _splitCamelot(a);
  final parsedB = _splitCamelot(b);
  if (parsedA == null || parsedB == null) return false;
  if (parsedA.number == parsedB.number) return true;
  if (parsedA.letter != parsedB.letter) return false;
  final raw = (parsedA.number - parsedB.number).abs();
  final wrap = 12 - raw;
  final dist = raw < wrap ? raw : wrap;
  return dist <= neighborDistance;
}

/// Extra-Übergang nur, wenn BPM **und** Tonart zum Seed passen.
/// Ohne Metadaten zählt der Song nur, wenn er schon im Genre-Pool liegt.
bool fitsMixWindow({
  required double? seedBpm,
  required String? seedCamelot,
  required double? candidateBpm,
  required String? candidateCamelot,
  required String scope,
}) {
  return bpmMixable(
        seedBpm,
        candidateBpm,
        window: mixBpmWindow(scope),
      ) &&
      camelotMixable(
        seedCamelot,
        candidateCamelot,
        neighborDistance: camelotNeighborDistance(scope),
      );
}

({int number, String letter})? _splitCamelot(String code) {
  final match = RegExp(r'^([1-9]|1[0-2])([AB])$').firstMatch(code);
  if (match == null) return null;
  return (
    number: int.parse(match.group(1)!),
    letter: match.group(2)!,
  );
}
