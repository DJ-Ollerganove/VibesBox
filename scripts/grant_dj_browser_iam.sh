#!/usr/bin/env bash
# Einmalig ausführen, wenn /dj „Verbindung fehlgeschlagen“ beim Code-Einlösen zeigt.
# Ursache: createCustomToken braucht iam.serviceAccounts.signBlob (Rolle: Service Account Token Creator).
# Siehe Firebase-Logs: redeemDjBrowserCode → auth/insufficient-permission
set -euo pipefail

PROJECT_ID="${1:-dj-ollerganove}"
PROJECT_NUMBER="${2:-567845942758}"

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud CLI fehlt. IAM manuell in Google Cloud Console setzen:"
  echo "  IAM → Service Account Token Creator für:"
  echo "    ${PROJECT_ID}@appspot.gserviceaccount.com"
  echo "    ${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
  exit 1
fi

echo "Projekt: ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}" >/dev/null

for SA in \
  "${PROJECT_ID}@appspot.gserviceaccount.com" \
  "${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
do
  echo "→ Token Creator für ${SA}"
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SA}" \
    --role="roles/iam.serviceAccountTokenCreator" \
    --condition=None \
    --quiet
done

echo "Fertig. Danach neuen Code in der App erzeugen und auf /dj testen."
