#!/usr/bin/env bash
# VibesBox — physisches iPhone/iPad: signierter Build (niemals --no-codesign fürs Gerät).
#
# Modi:
#   install              → Debug (Hot-Reload / flutter run)
#   install-stable       → Profile (AOT, näher an Release — oft stabiler vom Springboard)
#   run / run-stable     → flutter run --debug bzw. --profile
#
#   ./scripts/ios_deploy_device.sh install [<device-id>]
#   ./scripts/ios_deploy_device.sh install-stable [<device-id>]
#   FLUTTER_DEVICE_ID=<id> ./scripts/ios_deploy_device.sh install-stable

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEVICE="${FLUTTER_DEVICE_ID:-}"
MODE="install"
FLAVOR_FLAGS=(--debug)

if [[ $# -gt 0 ]]; then
  case "$1" in
    run | install | run-stable | install-stable)
      MODE="$1"
      shift
      ;;
  esac
fi

if [[ $# -gt 0 ]]; then
  DEVICE="$1"
fi

if [[ -z "${DEVICE:-}" ]]; then
  echo "Geräte (iPhone/iPad verbinden und „Vertrauen“ auf dem Gerät):"
  flutter devices
  echo ""
  echo "Beispiele:"
  echo "  ./scripts/ios_deploy_device.sh install <device-id>         # Debug"
  echo "  ./scripts/ios_deploy_device.sh install-stable <device-id> # Profile (stabiler Kaltstart)"
  echo "  ./scripts/ios_deploy_device.sh run <device-id>"
  echo "  ./scripts/ios_deploy_device.sh run-stable <device-id>"
  exit 1
fi

case "$MODE" in
  install-stable | run-stable)
    FLAVOR_FLAGS=(--profile)
    ;;
esac

echo "== iOS: pub get → pod install → flutter build ios ${FLAVOR_FLAGS[0]} (signiert) → $MODE =="
flutter pub get
( cd ios && pod install )

if [[ "$MODE" == "run" ]]; then
  exec flutter run --debug -d "$DEVICE"
fi
if [[ "$MODE" == "run-stable" ]]; then
  exec flutter run --profile -d "$DEVICE"
fi

flutter build ios "${FLAVOR_FLAGS[@]}"
if [[ "${FLAVOR_FLAGS[0]}" == "--profile" ]]; then
  flutter install --profile -d "$DEVICE"
else
  flutter install --debug -d "$DEVICE"
fi
echo "== Fertig installiert auf Gerät $DEVICE (${FLAVOR_FLAGS[0]}) =="
