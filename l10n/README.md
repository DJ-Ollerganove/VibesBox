# Übersetzungen (App + PWA)

## Ein Befehl für alles

Im **Projektroot**:

```bash
chmod +x scripts/i18n-sync.sh   # einmalig
./scripts/i18n-sync.sh
```

Mit PWA-Deploy:

```bash
./scripts/i18n-sync.sh --deploy-hosting
```

Das Skript macht nacheinander:

1. Flutter Dart → ARB (falls in `.dart` geändert)
2. PWA `lang/*.js` → JSON
3. ARB → Dart, JSON → `lang/*.js`
4. **`l10n/languages.json` → Registry** (Datum/Zeit, Sprachlisten, PWA-Maps, `getTranslations`)

Alias: `./scripts/l10n_sync_all.sh` (ruft dasselbe auf).

---

## Zentrale Sprachliste

**`l10n/languages.json`** — pro Sprache u. a.:

| Feld | Bedeutung |
|------|-----------|
| `code` | ISO (`vi`, `pl`, …) |
| `intl_locale` | BCP-47 für **Datum/Uhrzeit** (`vi-VN`) — App + PWA |
| `hour12` | optional, nur wo nötig (z. B. `"hour12": true` für `en`) |
| `time_style` | Uhrzeit-Layout: `colon_suffix`, `fr_h`, `pt_h`, `ja_kanji`, `intl_12` — siehe [`DATETIME_RULES.md`](DATETIME_RULES.md) |
| `time_suffix` | Nur bei `colon_suffix`: Text **nach** der Zeit (DE `" Uhr"`, NL `" uur"`) |
| `name`, `icon`, `langKey` | PWA-Menü |

**Datum/Uhrzeit zentral:** Nur `languages.json` bearbeiten, dann `./scripts/i18n-sync.sh` (schreibt Registry, ARB `time_suffix`, PWA). App: `LanguageRegistry` + `FormattingUtils`; PWA: `party_shared.js` + `PARTY_LOCALE_OPTS`.

**Welche Sprache „Uhr“ / „uur“ / nichts?** → siehe [`DATETIME_RULES.md`](DATETIME_RULES.md) (Recherche + Tabelle).

**BabelEdit** = Texte in `l10n/app_*.arb`, `public/vb/babel/locales/*.json` und `public/dj/babel/locales/*.json`.

**Nur exportieren** (Dart/JS → ARB/JSON zum Übersetzen, ohne Regenerierung):

```bash
./scripts/i18n-export-for-translation.sh
```

---

## Neue Sprache (Kurz)

1. Eintrag in **`l10n/languages.json`** (mit `intl_locale`)
2. **`l10n/app_XX.arb`** + **`public/vb/babel/locales/XX.json`** (BabelEdit)
3. **`./scripts/i18n-sync.sh`**
4. Optional: **`./scripts/i18n-sync.sh --deploy-hosting`**

`intl_locale`, `hour12` und `time_suffix` kommen aus `languages.json` — nicht mehr manuell in `party_shared.js` / einzelnen ARB-Dateien pflegen (ARB wird beim Sync aus der Registry befüllt).

Optional: iOS `InfoPlist.strings`, Flagge in `public/vb/assets/flags.svg`.
