# Migration: `wishes` → `parties/{partyId}/wishes/{wishId}`

## Reihenfolge (Produktion)

1. **Backup** (Firestore Export + `./scripts/backup_project_mac.sh`)
2. **Code deployen:** Rules, Indexes, Functions, Hosting, App-Stores
3. **Migration ausführen** (mit Service Account):
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS=/pfad/serviceAccount.json
   export GOOGLE_CLOUD_PROJECT=dj-ollerganove
   node functions/migrateWishesToPartySubcollections.js --dry-run
   node functions/migrateWishesToPartySubcollections.js
   node functions/migrateWishesToPartySubcollections.js --delete-source
   ```
4. Prüfen: Admin-Statistik, DJ Offen-Liste, PWA Absenden, Push-Benachrichtigung

`--delete-source` erst nach erfolgreichem Dry-run und Kopier-Lauf.

## Hinweis

Neue Indexes (`status`+`createdAt` in Subcollection) können einige Minuten brauchen (Firebase Console).
