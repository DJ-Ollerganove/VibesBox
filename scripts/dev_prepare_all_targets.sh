#!/usr/bin/env bash
# Mac: Flutter + iOS-Pods vorbereiten, damit iOS- und Android-Builds aus demselben Stand möglich sind.
# PWA: liegt unter public/ – nach Änderungen ggf. firebase deploy (s. Projektregel).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "== flutter pub get =="
flutter pub get

echo "== pod install (ios) =="
( cd ios && pod install )

echo "OK: Vorbereitung fertig. Android: flutter build appbundle --release | iOS: Xcode oder ios_deploy Skript"
