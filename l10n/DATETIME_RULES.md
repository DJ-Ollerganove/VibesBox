# Datum & Uhrzeit – jede Sprache einzeln

**Gültig für die 18 Menü-Sprachen** (App/PWA-Sprachauswahl). **Arabisch (`ar`)** ist in `languages.json` vorbereitet, aber noch nicht im Menü – folgt später.

**Quelle:** [`languages.json`](languages.json) → `./scripts/i18n-sync.sh`  
**Pflege der Regeln:** [`scripts/apply-datetime-styles-to-registry.js`](../scripts/apply-datetime-styles-to-registry.js)

---

## Deutsch (de)

- **Datum:** `23.5.2026` (`intl_locale` de-DE)
- **Uhr:** `20:30 Uhr` (`colon_suffix` + ` Uhr`)

## Niederländisch (nl)

- **Datum:** `23-5-2026`
- **Uhr:** `20:30 uur`

## Englisch (en)

- **Datum:** `5/23/2026`
- **Uhr:** `8:30 PM` (`intl_12`)

## Hindi (hi)

- **Datum:** `23/5/2026`
- **Uhr:** `8:30 pm` (`intl_12`, lokal üblich)

## Arabisch (ar)

- **Datum:** `23/5/2026` (RTL-Layout je nach System)
- **Uhr:** `8:30 م` (`intl_12`)

## Französisch (fr)

- **Datum:** `23/05/2026`
- **Uhr:** `20 h 30` (`fr_h`, OQLF)

## Portugiesisch (pt)

- **Datum:** `23/05/2026`
- **Uhr:** `20h30` (`h_compact`)

## Italienisch (it)

- **Datum:** `23/05/2026`
- **Uhr:** `20h30` (`h_compact`, üblich z. B. 18h30)

## Spanisch (es)

- **Datum:** `23/5/2026`
- **Uhr:** `20:30 h` (24h + Doppelpunkt, optional **` h`** laut RAE/Fundéu)

## Russisch (ru)

- **Datum:** `23.05.2026`
- **Uhr:** `20:30` (24h, GOST/ISO 8601, **ohne** Zusatzzeichen)

## Ukrainisch (uk)

- **Datum:** `23.05.2026`
- **Uhr:** `20:30`

## Polnisch (pl)

- **Datum:** `23.05.2026`
- **Uhr:** `20:30`

## Tschechisch (cs)

- **Datum:** `23. 5. 2026` (Leerzeichen laut Locale)
- **Uhr:** `20:30`

## Griechisch (el)

- **Datum:** `23/5/2026`
- **Uhr:** `20:30` (24h, nicht 12h mit μ.μ.)

## Türkisch (tr)

- **Datum:** `23.05.2026`
- **Uhr:** `20:30`

## Albanisch (sq)

- **Datum:** `23.5.2026`
- **Uhr:** `20:30` (24h, nicht 12h „m.d.“)

## Vietnamesisch (vi)

- **Datum:** `23/5/2026`
- **Uhr:** `20:30` (24h in offiziellen/Apps-Kontexten)

## Chinesisch (zh)

- **Datum:** `2026/5/23`
- **Uhr:** `20:30` (24h; gesprochen oft 下午/上午, Schreibweise digital 24h üblich)

## Japanisch (ja)

- **Datum:** `2026/5/23`
- **Uhr:** `20時30分` (`ja_kanji`)

---

## Technische `time_style`-Werte

| `time_style` | Sprachen |
|--------------|----------|
| `colon_suffix` | de, nl, es, ru, uk, pl, cs, el, tr, sq, vi, zh |
| `intl_12` | en, hi, ar |
| `fr_h` | fr |
| `h_compact` | pt, it |
| `ja_kanji` | ja |
