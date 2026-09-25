#!/usr/bin/env bash
# Exportiert aktuelle Übersetzungen für BabelEdit — ohne Import/Regenerierung.
#
#   ./scripts/i18n-export-for-translation.sh
#
# Erzeugt:
#   l10n/app_*.arb              ← aus lib/l10n/app_localizations_*.dart
#   public/vb/babel/locales/*.json  ← aus public/vb/lang/*.js
#   public/dj/babel/locales/*.json  ← aus public/dj/dj-l10n.js
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  VibesBox i18n-Export (nur ARB + JSON, zum Übersetzen)   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

echo "=== 1/3 Flutter: Dart → ARB ==="
dart run tool/export_l10n_arb.dart

echo ""
echo "=== 2/3 PWA: lang/*.js → JSON ==="
node scripts/pwa-lang-export-babel.js

echo ""
echo "=== 3/3 DJ-Browser: dj-l10n.js → JSON ==="
node scripts/dj-lang-export-babel.js

echo ""
echo "✓ Export fertig."
echo "  App:  l10n/app_*.arb"
echo "  PWA:  public/vb/babel/locales/*.json"
echo "  DJ:   public/dj/babel/locales/*.json"
echo ""
echo "Nach dem Übersetzen: ./scripts/i18n-sync.sh"
