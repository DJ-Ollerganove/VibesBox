#!/usr/bin/env bash
# Push zu origin – für Cursor-Agent und CI, wenn HTTPS ohne Keychain funktioniert.
# Voraussetzung: .secrets/cursor_git.env mit GITHUB_PAT (siehe scripts/cursor_git_env.example)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/.secrets/cursor_git.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

TOKEN="${GITHUB_PAT:-${GITHUB_TOKEN:-}}"
if [[ -z "$TOKEN" ]]; then
  echo "git_push.sh: Kein GITHUB_PAT oder GITHUB_TOKEN." >&2
  echo "Lege an: $ROOT/.secrets/cursor_git.env (Vorlage: scripts/cursor_git_env.example)" >&2
  exit 2
fi

REMOTE_URL="$(git remote get-url origin)"
if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)? ]]; then
  OWNER="${BASH_REMATCH[1]}"
  REPO="${BASH_REMATCH[2]}"
else
  echo "git_push.sh: origin-URL nicht erkannt: $REMOTE_URL" >&2
  exit 1
fi

BRANCH="${1:-$(git branch --show-current)}"
AUTH_URL="https://oauth2:${TOKEN}@github.com/${OWNER}/${REPO}.git"

# Einmaliger Push über authentifizierte URL (Remote-URL im Repo bleibt unverändert)
GIT_TERMINAL_PROMPT=0 git push "$AUTH_URL" "HEAD:${BRANCH}"
