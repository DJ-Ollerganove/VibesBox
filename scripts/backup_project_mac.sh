#!/usr/bin/env bash
# VibesBox: Vollbackup (Flutter + PWA + iOS + Android + Firebase-Funktionen …)
# Analog zu backup_script.ps1 (Windows), angepasst für macOS.
#
# Verwendung (im Projektroot VibesBox):
#   chmod +x scripts/backup_project_mac.sh
#   ./scripts/backup_project_mac.sh
# Optional eigener Ordnername:
#   ./scripts/backup_project_mac.sh mein_backup_2026
#
# Ausgabe: Ordner <name> im Projektroot (neben lib/, android/, …)
# Große/regenerierbare Verzeichnisse werden per rsync ausgelassen (Pods, .gradle, build, node_modules).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

NAME="${1:-}"
if [[ -z "${NAME}" ]]; then
  NAME="backup_$(date +%Y-%m-%d_%H-%M-%S)"
fi

# Kein Überschreiben eines bestehenden Projektordners
if [[ -e "${ROOT}/${NAME}" ]]; then
  echo "Fehler: Ziel existiert bereits: ${ROOT}/${NAME}" >&2
  exit 1
fi

DEST="${ROOT}/${NAME}"
mkdir -p "${DEST}"

echo "→ Backup nach: ${DEST}"

RSYNC_EXCLUDES=(
  --exclude='.git'
  --exclude='Pods'
  --exclude='.symlinks'
  --exclude='**/DerivedData'
  --exclude='build'
  --exclude='.gradle'
  --exclude='**/node_modules'
  --exclude='.dart_tool'
)

copy_tree() {
  local rel="$1"
  if [[ -d "${ROOT}/${rel}" ]]; then
    echo "  Kopiere ${rel}/ …"
    rsync -a "${RSYNC_EXCLUDES[@]}" "${ROOT}/${rel}" "${DEST}/"
  else
    echo "  (übersprungen, fehlt: ${rel}/)"
  fi
}

# Ordner: App, PWA, Mobile, Desktop, Tests, L10n, Hilfsskripte
for d in lib public functions assets android ios web windows linux macos test l10n tool scripts; do
  copy_tree "$d"
done

# Einzeldateien (Konfiguration & Doku wie im Windows-Skript)
FILES=(
  pubspec.yaml
  pubspec.lock
  firestore.rules
  storage.rules
  firebase.json
  .firebaserc
  analysis_options.yaml
  .metadata
  README.md
  DEPLOY_ANLEITUNG.txt
  EINFACHE_ANLEITUNG.txt
  EMAILJS_SETUP.md
  KONTAKTFORMULAR_EMAIL_INFO.md
  PWA_DEPLOYMENT.md
  SOUND_ANLEITUNG.txt
  SOUND_DOWNLOAD_HILFE.md
  SOUND_FINDEN_ANLEITUNG.txt
  ZUSAMMENFASSUNG.txt
  RESTORE_ANLEITUNG.md
  backup_script.ps1
)
for f in "${FILES[@]}"; do
  if [[ -f "${ROOT}/${f}" ]]; then
    echo "  Kopiere ${f}"
    cp "${ROOT}/${f}" "${DEST}/"
  fi
done

if [[ -f "${ROOT}/l10n.yaml" ]]; then
  cp "${ROOT}/l10n.yaml" "${DEST}/"
fi

# Optionale PowerShell-/Shell-Skripte im Projektroot
shopt -s nullglob
for f in "${ROOT}"/*.ps1 "${ROOT}"/*.sh; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f")"
  echo "  Kopiere ${base}"
  cp "$f" "${DEST}/"
done
shopt -u nullglob

INFO="${DEST}/BACKUP_INFO.txt"
{
  echo "VibesBox Backup (macOS)"
  echo "======================="
  echo "Erstellt am:    $(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "Rechner:        $(hostname 2>/dev/null || echo unbekannt)"
  echo "Projektroot:    ${ROOT}"
  echo "Backup-Ordner:  ${DEST}"
  echo ""
  echo "Enthalten u. a.:"
  echo "  - Flutter (lib/, pubspec, …)"
  echo "  - PWA (public/)"
  echo "  - Android (android/, ohne .gradle/build)"
  echo "  - iOS (ios/, ohne Pods)"
  echo "  - Firebase Functions (functions/, ohne node_modules)"
  echo "  - Weitere Plattformordner (web, windows, linux, macos, test)"
  echo "  - l10n/, tool/, scripts/"
  echo ""
  echo "Nicht enthalten (regenerierbar / sehr groß):"
  echo "  - build/, .dart_tool/, ios/Pods, android/.gradle, node_modules"
} > "${INFO}"

echo ""
echo "Fertig."
echo "Größe (näherungsweise):"
du -sh "${DEST}" 2>/dev/null || true
echo ""
echo "Info: ${INFO}"
