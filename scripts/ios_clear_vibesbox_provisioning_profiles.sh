#!/usr/bin/env bash
# Entfernt zwischengespeicherte mobileprovision-Dateien für com.vibesbox.dj.
# Hilft, wenn das Portal ShazamKit/Associated Domains schon hat, Xcode aber noch ein altes Profil nutzt.
set -euo pipefail
DIR="${HOME}/Library/MobileDevice/Provisioning Profiles"
if [[ ! -d "$DIR" ]]; then
  echo "Ordner existiert nicht: $DIR"
  exit 0
fi
removed=0
for f in "$DIR"/*.mobileprovision; do
  [[ -e "$f" ]] || continue
  if security cms -D -i "$f" 2>/dev/null | grep -q "com.vibesbox.dj"; then
    echo "Entferne: $f"
    rm -f "$f"
    removed=$((removed + 1))
  fi
done
echo "Fertig. Entfernte Profile: $removed"
echo "Danach in Xcode: Settings → Accounts → Team → „Download Manual Profiles“, dann neu bauen."
