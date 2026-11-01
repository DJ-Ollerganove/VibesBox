#!/usr/bin/env bash
# Eine Versionsquelle: pubspec.yaml -> lib/tool_version.dart (+ Inno-Default).
# Vor Mac/Windows-Build ausfuehren, wenn die Version geaendert wurde.
set -euo pipefail
TOOL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUBSPEC="$TOOL_ROOT/pubspec.yaml"
VERSION="$(sed -nE 's/^version:[[:space:]]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' "$PUBSPEC" | head -1)"
if [[ -z "$VERSION" ]]; then
  echo "Konnte version in pubspec.yaml nicht lesen." >&2
  exit 1
fi
echo "Sync-Tool Version aus pubspec: $VERSION"
cat > "$TOOL_ROOT/lib/tool_version.dart" <<EOF
// GENERATED from pubspec.yaml - nicht von Hand pflegen.
// Quelle: tools/rb_now_playing/pubspec.yaml (version:)
// Sync: scripts/sync_version_from_pubspec.ps1 / .sh
const kSyncToolVersion = '$VERSION';
EOF
ISS="$TOOL_ROOT/installer/vibesbox_sync.iss"
if [[ -f "$ISS" ]]; then
  perl -0pi -e "s/#define MyAppVersion\\s+\\\"[^\\\"]+\\\"/#define MyAppVersion \\\"$VERSION\\\"/" "$ISS"
  perl -0pi -e "s/OutputBaseFilename=VibesBoxSync-Setup-[^\\r\\n]+/OutputBaseFilename=VibesBoxSync-Setup-$VERSION/" "$ISS"
fi
echo "OK: lib/tool_version.dart + installer/vibesbox_sync.iss -> Setup-$VERSION"
echo "$VERSION"
