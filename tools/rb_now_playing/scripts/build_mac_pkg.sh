#!/bin/bash
# Baut das Mac-Installationspaket mit Begruessung und Abschluss
# in allen VibesBox-Sprachen. Die Sprache kommt vom Mac, es gibt
# kein eigenes Sprachmenue wie beim Windows-Setup.
#
# Signieren und notarizen macht dieses Skript nicht.
# Aufruf aus tools/rb_now_playing:
#   ./scripts/build_mac_pkg.sh
#   ./scripts/build_mac_pkg.sh "/Pfad/VibesBox Sync.app"

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build/macos/Build/Products/Release/VibesBox Sync.app}"
RES="$ROOT/installer/macos/resources"
DIST_SRC="$ROOT/installer/macos/distribution.xml"
OUT_DIR="$ROOT/dist"
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/vibesbox-sync-pkg.XXXXXX")"

cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

if [[ ! -d "$APP" ]]; then
  echo "App nicht gefunden: $APP" >&2
  echo "Zuerst: flutter build macos --release" >&2
  exit 1
fi

VERSION="$(sed -n 's/^version: \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' "$ROOT/pubspec.yaml" | head -n 1)"
if [[ -z "$VERSION" ]]; then
  echo "Version in pubspec.yaml nicht lesbar." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
DIST="$WORKDIR/distribution.xml"
sed "s/version=\"1.0.5\"/version=\"$VERSION\"/" "$DIST_SRC" > "$DIST"

echo "VibesBox Sync $VERSION"
echo "App: $APP"

COPYFILE_DISABLE=1 pkgbuild \
  --component "$APP" \
  --install-location /Applications \
  --identifier com.vibesbox.sync \
  --version "$VERSION" \
  "$WORKDIR/VibesBoxSync-component.pkg"

COPYFILE_DISABLE=1 productbuild \
  --distribution "$DIST" \
  --resources "$RES" \
  --package-path "$WORKDIR" \
  "$OUT_DIR/VibesBox-Sync-$VERSION-mac.pkg"

echo "Fertig: $OUT_DIR/VibesBox-Sync-$VERSION-mac.pkg"
echo "Noch nicht signiert und nicht notarisiert."
