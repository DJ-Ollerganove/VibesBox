import 'dj_app_match.dart';

const djWatchLabel = 'com.vibesbox.sync.djwatch';

String bashSingleQuote(String value) =>
    "'${value.replaceAll("'", "'\\''")}'";

String xmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _bashPattern(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll(' ', r'\ ');

String _bashArms(Iterable<String> values) =>
    values.map(_bashPattern).join('|');

String powershellSingleQuote(String value) =>
    "'${value.replaceAll("'", "''")}'";

/// Funktionen ohne Schleife, damit Tests sie ausführen können.
/// Sie starten nichts.
String buildMacMatchHelpers() {
  final bundles = <String>[
    for (final rule in djAppRules) ...rule.bundleIds,
  ];
  final names = <String>[
    for (final rule in djAppRules) ...rule.names,
  ];
  final denied = deniedExactNames.toList()..sort();
  return '''
lower() { printf '%s' "\$1" | /usr/bin/tr '[:upper:]' '[:lower:]'; }

is_denied_bundle() {
  [ -n "\$1" ] || return 1
  case "\$1" in
    *pulsedj*|*rekordbox*agent*|*agent*rekordbox*) return 0 ;;
  esac
  return 1
}

is_denied_name() {
  [ -n "\$1" ] || return 1
  case "\$1" in
    ${_bashArms(denied)}) return 0 ;;
    *rekordbox*agent*|*agent*rekordbox*) return 0 ;;
  esac
  return 1
}

is_allowed_bundle() {
  [ -n "\$1" ] || return 1
  case "\$1" in
    ${_bashArms(bundles)}) return 0 ;;
  esac
  return 1
}

is_allowed_name() {
  [ -n "\$1" ] || return 1
  case "\$1" in
    ${_bashArms(names)}) return 0 ;;
  esac
  return 1
}

is_dj() {
  local bid_l app_l exe_l
  bid_l=\$(lower "\$1")
  app_l=\$(lower "\$2")
  exe_l=\$(lower "\$3")
  if is_denied_bundle "\$bid_l" || is_denied_name "\$app_l" || is_denied_name "\$exe_l"; then
    return 1
  fi
  if is_allowed_bundle "\$bid_l" || is_allowed_name "\$app_l" || is_allowed_name "\$exe_l"; then
    return 0
  fi
  return 1
}

parse_app() {
  local cmd="\$1" prefix
  case "\$cmd" in
    *.app/Contents/MacOS/*)
      prefix="\${cmd%%.app/Contents/MacOS/*}"
      printf '%s\\n' "\${prefix##*/}"
      ;;
  esac
}
''';
}

/// Lokaler macOS-Wächter. Startet nur VibesBox Sync, nie eine DJ-App.
String buildMacWatchScript({
  required String syncAppPath,
  required String syncExePath,
  required String statePath,
}) {
  final app = bashSingleQuote(syncAppPath);
  final exe = bashSingleQuote(syncExePath);
  final state = bashSingleQuote(statePath);
  return '''
#!/bin/bash
# Startet nur VibesBox Sync, wenn eine unterstützte DJ-App zu laufen beginnt.
# Startet keine DJ-Software und nicht Pulse DJ.
SYNC_APP=$app
SYNC_EXE=$exe
STATE=$state
/bin/mkdir -p "\$(/usr/bin/dirname "\$STATE")"

${buildMacMatchHelpers()}
scan() {
  dj=0
  sync_on=0
  while IFS= read -r cmd; do
    [ -n "\$cmd" ] || continue
    if [ "\$cmd" = "\$SYNC_EXE" ] || [ "\${cmd#"\$SYNC_EXE "}" != "\$cmd" ]; then
      sync_on=1
      continue
    fi
    case "\$cmd" in
      *.app/Contents/MacOS/*)
        prefix="\${cmd%%.app/Contents/MacOS/*}"
        app="\${prefix##*/}"
        exe="\${cmd#*.app/Contents/MacOS/}"
        exe="\${exe%% *}"
        app_l=\$(lower "\$app")
        exe_l=\$(lower "\$exe")
        if is_denied_name "\$app_l" || is_denied_name "\$exe_l"; then
          continue
        fi
        if is_allowed_name "\$app_l" || is_allowed_name "\$exe_l"; then
          dj=1
          continue
        fi
        case "\$app_l" in
          *rekordbox*|*serato*|*virtual*|*traktor*|*mixxx*|*engine*|*djay*|*pioneer*|*algoriddim*|*atomix*|*pulse*|*denon*)
            ;;
          *)
            continue
            ;;
        esac
        plist="\${prefix}.app/Contents/Info.plist"
        bid=""
        if [ -f "\$plist" ]; then
          bid=\$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "\$plist" 2>/dev/null || true)
        fi
        bid_l=\$(lower "\$bid")
        if is_denied_bundle "\$bid_l"; then
          continue
        fi
        if is_allowed_bundle "\$bid_l"; then
          dj=1
        fi
        ;;
    esac
  done < <(/bin/ps -axww -o command=)
}

prev=0
if [ -f "\$STATE" ]; then
  prev=\$(/usr/bin/tr -d '[:space:]' < "\$STATE" 2>/dev/null || true)
fi
if [ "\$prev" != 1 ]; then
  prev=0
fi

/bin/sleep 2
while true; do
  if [ ! -d "\$SYNC_APP" ]; then
    /bin/sleep 30
    continue
  fi
  dj=0
  sync_on=0
  scan
  if [ "\$dj" -eq 1 ] && [ "\$prev" -eq 0 ] && [ "\$sync_on" -eq 0 ]; then
    /usr/bin/open "\$SYNC_APP"
  fi
  if [ "\$dj" -eq 1 ]; then
    prev=1
  else
    prev=0
  fi
  printf '%s\\n' "\$prev" > "\$STATE"
  /bin/sleep 3
done
''';
}

String buildMacLaunchAgentPlist({required String scriptPath}) {
  final path = xmlEscape(scriptPath);
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$djWatchLabel</string>
  <key>AssociatedBundleIdentifiers</key>
  <array>
    <string>com.vibesbox.rbNowPlaying</string>
  </array>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$path</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>10</integer>
  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
</dict>
</plist>
''';
}

/// Pfad des `.app`-Bundles aus dem laufenden macOS-Binary.
String? macBundlePath(String executable) {
  const marker = '.app/Contents/MacOS/';
  final index = executable.indexOf(marker);
  if (index < 0) return null;
  return executable.substring(0, index + 4);
}

/// Lokaler Windows-Wächter. Startet nur VibesBox Sync.
String buildWindowsWatchScript({
  required String syncExePath,
  required String statePath,
  required String pidPath,
}) {
  final exe = powershellSingleQuote(syncExePath);
  final state = powershellSingleQuote(statePath);
  final pid = powershellSingleQuote(pidPath);
  return '''
\$ErrorActionPreference = 'Continue'
\$SyncExe = $exe
\$StateFile = $state
\$PidFile = $pid
Set-Content -Path \$PidFile -Value \$PID -Encoding ascii
\$Allowed = @{
${[
    for (final rule in djAppRules)
      for (final name in rule.names)
        "  ${powershellSingleQuote(name)} = \$true",
  ].join('\n')}
}
\$Denied = @{
${[
    for (final name in deniedExactNames) "  ${powershellSingleQuote(name)} = \$true",
  ].join('\n')}
}

function Test-DeniedName([string]\$Name) {
  if (\$Denied.ContainsKey(\$Name)) { return \$true }
  if (\$Name.Contains('rekordbox') -and \$Name.Contains('agent')) { return \$true }
  return \$false
}

\$prev = \$false
if (Test-Path -LiteralPath \$StateFile) {
  \$prev = (Get-Content -LiteralPath \$StateFile -Raw).Trim() -eq '1'
}

Start-Sleep -Seconds 2
while (\$true) {
  try {
    if (-not (Test-Path -LiteralPath \$SyncExe)) {
      Start-Sleep -Seconds 30
      continue
    }
    \$dj = \$false
    \$syncOn = \$false
    \$procs = Get-CimInstance Win32_Process
    foreach (\$p in \$procs) {
      \$path = [string]\$p.ExecutablePath
      if (\$path -and (\$path -ieq \$SyncExe)) { \$syncOn = \$true }
      \$raw = [string]\$p.Name
      if (-not \$raw) { continue }
      \$name = \$raw.ToLowerInvariant()
      if (\$name.EndsWith('.exe')) { \$name = \$name.Substring(0, \$name.Length - 4) }
      if (Test-DeniedName \$name) { continue }
      if (\$Allowed.ContainsKey(\$name)) { \$dj = \$true }
    }
    if (\$dj -and -not \$prev -and -not \$syncOn) {
      Start-Process -FilePath \$SyncExe
    }
    if (\$dj) { \$prev = \$true } else { \$prev = \$false }
    if (\$prev) { '1' } else { '0' } | Set-Content -LiteralPath \$StateFile -Encoding ascii
  } catch {
  }
  Start-Sleep -Seconds 3
}
''';
}

String buildWindowsWatchVbs({required String ps1Path}) {
  final escaped = ps1Path.replaceAll('"', '""');
  return 'CreateObject("Wscript.Shell").Run "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$escaped""", 0, False\r\n';
}
