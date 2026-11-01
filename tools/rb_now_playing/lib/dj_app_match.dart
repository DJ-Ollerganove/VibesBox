import 'dj_library_prefs.dart';

/// Unterstützte DJ-Apps an Bundle-ID, `.app`-Namen oder Windows-EXE.
///
/// Pulse DJ (`pulsedj.com.Pulse-DJ`, `/Applications/Pulse DJ.app`) und der
/// rekordbox-Agent sind absichtlich keine Treffer. Sync startet sie nie
/// und startet auch sonst keine DJ-Software — nur sich selbst.
class DjAppRule {
  const DjAppRule(this.software, this.bundleIds, this.names);

  final DjSoftware software;

  /// macOS `CFBundleIdentifier`, kleingeschrieben.
  final List<String> bundleIds;

  /// App-Name ohne `.app` und EXE ohne `.exe`, kleingeschrieben.
  final List<String> names;
}

const deniedExactNames = <String>{
  'pulse dj',
  'pulsedj',
  'pulse-dj',
  'rekordboxagent',
  'rekordbox agent',
};

List<String> _numbered(String prefix, int from, int to) => [
      for (var i = from; i <= to; i++) '$prefix $i',
    ];

final List<DjAppRule> djAppRules = [
  DjAppRule(
    DjSoftware.rekordbox,
    const [
      'com.pioneerdj.rekordboxdj',
      'com.pioneer.rekordboxdj',
    ],
    [
      'rekordbox',
      ..._numbered('rekordbox', 4, 12),
    ],
  ),
  DjAppRule(
    DjSoftware.serato,
    const [
      'com.serato.seratodj',
      'com.serato.seratodjpro',
    ],
    const [
      'serato dj pro',
      'serato dj',
      'seratodj',
    ],
  ),
  DjAppRule(
    DjSoftware.virtualDj,
    const [
      'com.atomixproductions.virtualdj',
    ],
    [
      'virtualdj',
      'virtual dj',
      'virtualdj 8',
      'virtual dj 8',
      ..._numbered('virtualdj', 2016, 2032),
      ..._numbered('virtual dj', 2016, 2032),
    ],
  ),
  DjAppRule(
    DjSoftware.traktor,
    const [
      'com.native-instruments.traktor',
    ],
    const [
      'traktor',
      'traktor pro',
      'traktor pro 2',
      'traktor pro 3',
      'traktor pro 4',
      'traktor pro 5',
    ],
  ),
  DjAppRule(
    DjSoftware.mixxx,
    const [
      'org.mixxx.mixxx',
    ],
    const [
      'mixxx',
    ],
  ),
  DjAppRule(
    DjSoftware.engineDj,
    const [
      'com.inmusicbrands.enginedj',
      'com.inmusicbrands.engineprime',
    ],
    const [
      'engine dj',
      'engine prime',
      'enginedj',
      'engineprime',
    ],
  ),
  DjAppRule(
    DjSoftware.djayPro,
    const [
      // djay Pro AI für den Mac trägt diese ID (Algoriddim-Handbuch).
      'com.algoriddim.djay-iphone-free',
      'com.algoriddim.djay-pro-ai',
      'com.algoriddim.djay-pro-mac',
      'com.algoriddim.djay-pro',
    ],
    const [
      'djay',
      'djay pro',
      'djay pro ai',
    ],
  ),
];

final Map<String, DjSoftware> _byBundle = {
  for (final rule in djAppRules)
    for (final id in rule.bundleIds) id: rule.software,
};

final Map<String, DjSoftware> _byName = {
  for (final rule in djAppRules)
    for (final name in rule.names) name: rule.software,
};

String normBundleId(String? raw) => raw?.trim().toLowerCase() ?? '';

String normDjName(String? raw) {
  if (raw == null) return '';
  var text = raw.trim().toLowerCase();
  if (text.endsWith('.app')) text = text.substring(0, text.length - 4);
  if (text.endsWith('.exe')) text = text.substring(0, text.length - 4);
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool isDeniedBundle(String bundle) {
  if (bundle.isEmpty) return false;
  if (bundle.contains('pulsedj')) return true;
  if (bundle.contains('rekordbox') && bundle.contains('agent')) return true;
  return false;
}

bool isDeniedName(String name) {
  if (name.isEmpty) return false;
  if (deniedExactNames.contains(name)) return true;
  if (name.contains('rekordbox') && name.contains('agent')) return true;
  return false;
}

/// App-Name und EXE aus einem macOS- oder Windows-Prozesspfad.
({String? appName, String? exeName}) namesFromExecutablePath(String path) {
  final unified = path.replaceAll('\\', '/').trim();
  if (unified.isEmpty) return (appName: null, exeName: null);
  final lower = unified.toLowerCase();
  String? appName;
  const marker = '.app/';
  final appAt = lower.indexOf(marker);
  if (appAt >= 0) {
    appName = unified.substring(0, appAt).split('/').last;
  } else if (lower.endsWith('.app')) {
    appName = unified.split('/').last;
  }
  String? exeName;
  const macBin = '.app/contents/macos/';
  final binAt = lower.indexOf(macBin);
  if (binAt >= 0) {
    var rest = unified.substring(binAt + macBin.length);
    final space = rest.indexOf(' ');
    if (space >= 0) rest = rest.substring(0, space);
    exeName = rest;
  } else {
    final base = unified.split('/').last;
    if (base.isNotEmpty && !base.toLowerCase().endsWith('.app')) {
      exeName = base;
    }
  }
  return (appName: appName, exeName: exeName);
}

/// `null`, wenn es keine unterstützte DJ-App ist.
/// Ein verbotenes Signal (Pulse DJ, rekordbox-Agent) verwirft den ganzen Prozess.
DjSoftware? matchDjApp({
  String? bundleId,
  String? appName,
  String? exeName,
  String? executablePath,
}) {
  final fromPath = executablePath == null || executablePath.trim().isEmpty
      ? (appName: null, exeName: null)
      : namesFromExecutablePath(executablePath);
  final bundle = normBundleId(bundleId);
  final names = <String>[
    normDjName(appName),
    normDjName(exeName),
    normDjName(fromPath.appName),
    normDjName(fromPath.exeName),
  ].where((name) => name.isNotEmpty);
  if (isDeniedBundle(bundle)) return null;
  for (final name in names) {
    if (isDeniedName(name)) return null;
  }
  if (bundle.isNotEmpty) {
    final byId = _byBundle[bundle];
    if (byId != null) return byId;
  }
  for (final name in names) {
    final hit = _byName[name];
    if (hit != null) return hit;
  }
  return null;
}

/// Startet Sync einmal, wenn eine DJ-App zu laufen beginnt
/// (oder beim ersten Blick schon läuft) und Sync noch nicht läuft.
/// Schließt der Nutzer Sync, während die DJ-App weiterläuft, bleibt es zu,
/// bis die DJ-App neu startet. So entsteht kein zweites Fenster.
class DjWatchGate {
  bool djWasRunning = false;

  bool shouldLaunchSync({
    required bool djRunning,
    required bool syncRunning,
  }) {
    final rising = djRunning && !djWasRunning;
    djWasRunning = djRunning;
    return rising && !syncRunning;
  }
}
