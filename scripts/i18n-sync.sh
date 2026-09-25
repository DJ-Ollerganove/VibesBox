#!/usr/bin/env bash
# VibesBox — ein Befehl für Sprachen: Registry, ARB/JSON, Dart/JS (PWA).
#
# Nutzung (Projektroot):
#   ./scripts/i18n-sync.sh
#   ./scripts/i18n-sync.sh --deploy-hosting
#
# Neue Sprache: zuerst l10n/languages.json (+ app_XX.arb, locales/XX.json), dann dieses Skript.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEPLOY_HOSTING=0
for arg in "$@"; do
  case "$arg" in
    --deploy|--deploy-hosting)
      DEPLOY_HOSTING=1
      ;;
    -h|--help)
      echo "Usage: $0 [--deploy-hosting]"
      echo ""
      echo "  1. Flutter Dart → ARB (falls in .dart geändert)"
      echo "  2. PWA lang/*.js → JSON"
      echo "  3. DJ dj-l10n.js → JSON"
      echo "  4. ARB → Dart, JSON → lang/*.js + dj-l10n.js"
      echo "  5. l10n/languages.json → Registry (intl_locale, hour12, time_suffix, Maps)"
      echo "  6. time_suffix → ARB + PWA lang/*.js"
      echo ""
      echo "  --deploy-hosting   firebase deploy --only hosting"
      exit 0
      ;;
    *)
      echo "Unbekanntes Argument: $arg (siehe --help)" >&2
      exit 1
      ;;
  esac
done

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  VibesBox i18n-sync (Registry + Übersetzungen)           ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

echo "=== 1/6 Flutter: Dart → ARB ==="
dart run tool/export_l10n_arb.dart

echo ""
echo "=== 2/6 PWA: JS → JSON (BabelEdit-Quelle) ==="
node scripts/pwa-lang-export-babel.js

echo ""
echo "=== 3/6 DJ-Browser: JS → JSON (BabelEdit-Quelle) ==="
node scripts/dj-lang-export-babel.js

echo ""
echo "=== 4/6 Übersetzungen generieren (ARB→Dart, JSON→JS) ==="
dart run tool/import_l10n_from_arb.dart
node scripts/pwa-lang-import-babel.js
node scripts/dj-lang-import-babel.js

echo ""
echo "=== 5/6 Sprach-Registry (intl_locale, hour12, time_suffix, Listen, Maps) ==="
node scripts/sync-language-registry.js

echo ""
echo "=== 6/6 Datum/Zeit: languages.json → ARB + PWA ==="
node scripts/sync-datetime-from-registry.js

echo ""
echo "✓ Fertig."
echo "  Bearbeiten: l10n/*.arb, public/vb/babel/locales/*.json, public/dj/babel/locales/*.json, l10n/languages.json"
echo "  Nur exportieren: ./scripts/i18n-export-for-translation.sh"
if [[ "$DEPLOY_HOSTING" -eq 1 ]]; then
  echo ""
  echo "=== Firebase Hosting ==="
  firebase deploy --only hosting
  echo "✓ Hosting deployt."
else
  echo "  PWA live: ./scripts/i18n-sync.sh --deploy-hosting"
fi
