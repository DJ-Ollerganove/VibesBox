#!/bin/bash
# Baut das Mac-Installationspaket mit Begruessung und Abschluss
# in allen VibesBox-Sprachen. Die Sprache kommt vom Mac, es gibt
# kein eigenes Sprachmenue wie beim Windows-Setup.
#
# Signiert die App mit dem Developer-ID-Application-Zertifikat
# und das Paket mit dem Developer-ID-Installer-Zertifikat.
# Notarisierung macht dieses Skript nicht.
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

APP_IDENTITY="Developer ID Application: Swen Steller (ZMJK572375)"
PKG_IDENTITY="Developer ID Installer: Swen Steller (ZMJK572375)"
ENTITLEMENTS="$ROOT/macos/Runner/Release.entitlements"

echo "VibesBox Sync $VERSION"
echo "App: $APP"

# Verschachtelte Frameworks zuerst, danach das App-Bundle.
# Xcode 27 erwartet Hardened Runtime und einen Zeitstempel.
while IFS= read -r -d '' item; do
  codesign --force --options runtime --timestamp --sign "$APP_IDENTITY" "$item" || exit 1
done < <(find "$APP/Contents" -depth \( -name "*.framework" -o -name "*.dylib" -o -name "*.bundle" -o -name "*.xpc" \) -print0)

codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$APP_IDENTITY" \
  "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

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
  "$WORKDIR/VibesBox-Sync-unsigned.pkg"

productsign --sign "$PKG_IDENTITY" \
  "$WORKDIR/VibesBox-Sync-unsigned.pkg" \
  "$OUT_DIR/VibesBox-Sync-$VERSION-mac.pkg"
pkgutil --check-signature "$OUT_DIR/VibesBox-Sync-$VERSION-mac.pkg"

ICON="$ROOT/installer/macos/vibesbox_sync.icns"
PKG_OUT="$OUT_DIR/VibesBox-Sync-$VERSION-mac.pkg"
if [[ -f "$ICON" ]]; then
  osascript - "$ICON" "$PKG_OUT" <<'APPLESCRIPT' || true
use framework "AppKit"
on run argv
  set imagePath to item 1 of argv
  set destPath to item 2 of argv
  set theImage to current application's NSImage's alloc()'s initWithContentsOfFile:imagePath
  if theImage is missing value then error "Icon nicht lesbar"
  set ws to current application's NSWorkspace's sharedWorkspace()
  ws's setIcon:theImage forFile:destPath options:0
end run
APPLESCRIPT
fi

echo "Fertig: $OUT_DIR/VibesBox-Sync-$VERSION-mac.pkg"
echo "Signiert mit Developer ID. Noch nicht notarisiert."
