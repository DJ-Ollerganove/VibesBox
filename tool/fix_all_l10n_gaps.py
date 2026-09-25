#!/usr/bin/env python3
"""Füllt fehlende/leere Übersetzungen in ARB, Gast-PWA-Babel und DJ-Babel."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
L10N = ROOT / "l10n"
PWA = ROOT / "public/vb/babel/locales"
DJ = ROOT / "public/dj/babel/locales"

# Absichtlich leer (optional / HTML-Bundles)
INTENTIONAL_EMPTY = {
    "main_intro_paragraph2",
    "time_suffix",
}

# DJ manueller Wunsch + Vorschläge — aus Flutter-ARB in DJ-Babel spiegeln
DJ_MANUAL_KEYS = [
    "add_manual_wish",
    "manual_by_dj",
    "wish_artist_label",
    "wish_title_label",
    "wish_greeting_label",
    "wish_greeting_max_chars",
    "wish_greeting_max_chars_error",
    "wish_title_or_artist_required",
    "manual_wish_saved_snack",
    "manual_wish_duplicate_history_and_open",
    "manual_wish_duplicate_history_only",
    "manual_wish_duplicate_open_only",
    "duplicates",
    "submit_wish",
    "cancel",
    "error",
    "catalog_top_songs",
    "suggestions_auto_appear",
]

MAIN_HERO_BTN_PARTY: dict[str, str] = {
    "de": "Zur Party",
    "en": "Go to party",
    "fr": "Aller à la party",
    "es": "Ir a la fiesta",
    "it": "Vai alla party",
    "pt": "Ir para a festa",
    "nl": "Naar het feest",
    "pl": "Do imprezy",
    "cs": "Na party",
    "tr": "Partiye git",
    "ru": "К party",
    "uk": "До вечірки",
    "zh": "前往派对",
    "ja": "パーティーへ",
    "hi": "पार्टी पर जाएँ",
    "sq": "Te festa",
    "vi": "Đến party",
    "el": "Στο πάρτι",
    "th": "ไปที่ปาร์ตี้",
    "ar": "Go to party",
}

ADMIN_PLATFORM: dict[str, dict[str, str]] = {
    "de": {
        "admin_platform_totals_title": "PLATTFORM-ÜBERSICHT",
        "admin_platform_totals_recount_hint": "Vollständige Neuzählung alle 7 Tage; dazwischen nur neue Accounts/Partys.",
        "admin_platform_totals_guests": "Gäste (angemeldet)",
        "admin_platform_totals_djs_total": "DJs gesamt",
        "admin_platform_totals_djs_free": "davon Free",
        "admin_platform_totals_djs_pro": "davon Pro",
        "admin_platform_totals_djs_pro_life": "davon Pro Life",
        "admin_platform_totals_parties_total": "Partys gesamt",
        "admin_platform_totals_parties_running": "Partys gerade laufend",
    },
    "en": {
        "admin_platform_totals_title": "PLATFORM OVERVIEW",
        "admin_platform_totals_recount_hint": "Full recount every 7 days; in between only new accounts/parties are added.",
        "admin_platform_totals_guests": "Guests (registered)",
        "admin_platform_totals_djs_total": "DJs total",
        "admin_platform_totals_djs_free": "of which Free",
        "admin_platform_totals_djs_pro": "of which Pro",
        "admin_platform_totals_djs_pro_life": "of which Pro Life",
        "admin_platform_totals_parties_total": "Parties total",
        "admin_platform_totals_parties_running": "Parties running now",
    },
    "fr": {
        "admin_platform_totals_title": "APERÇU DE LA PLATEFORME",
        "admin_platform_totals_recount_hint": "Recomptage complet tous les 7 jours ; entre-temps seuls les nouveaux comptes/partys sont ajoutés.",
        "admin_platform_totals_guests": "Invités (inscrits)",
        "admin_platform_totals_djs_total": "DJs au total",
        "admin_platform_totals_djs_free": "dont Free",
        "admin_platform_totals_djs_pro": "dont Pro",
        "admin_platform_totals_djs_pro_life": "dont Pro Life",
        "admin_platform_totals_parties_total": "Partys au total",
        "admin_platform_totals_parties_running": "Partys en cours",
    },
    "es": {
        "admin_platform_totals_title": "RESUMEN DE LA PLATAFORMA",
        "admin_platform_totals_recount_hint": "Recuento completo cada 7 días; entre medias solo se añaden cuentas/partys nuevas.",
        "admin_platform_totals_guests": "Invitados (registrados)",
        "admin_platform_totals_djs_total": "DJs en total",
        "admin_platform_totals_djs_free": "de los cuales Free",
        "admin_platform_totals_djs_pro": "de los cuales Pro",
        "admin_platform_totals_djs_pro_life": "de los cuales Pro Life",
        "admin_platform_totals_parties_total": "Fiestas en total",
        "admin_platform_totals_parties_running": "Fiestas en curso",
    },
    "it": {
        "admin_platform_totals_title": "PANORAMICA PIATTAFORMA",
        "admin_platform_totals_recount_hint": "Riconteggio completo ogni 7 giorni; nel frattempo solo nuovi account/party.",
        "admin_platform_totals_guests": "Ospiti (registrati)",
        "admin_platform_totals_djs_total": "DJ totali",
        "admin_platform_totals_djs_free": "di cui Free",
        "admin_platform_totals_djs_pro": "di cui Pro",
        "admin_platform_totals_djs_pro_life": "di cui Pro Life",
        "admin_platform_totals_parties_total": "Party totali",
        "admin_platform_totals_parties_running": "Party in corso",
    },
}


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def save_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def save_arb(path: Path, data: dict) -> None:
    items = [(k, v) for k, v in data.items() if k != "@@locale"]
    lines = ["{"]
    code = data.get("@@locale", path.stem.replace("app_", ""))
    lines.append(f'\t"@@locale": {json.dumps(code)},')
    for i, (k, v) in enumerate(items):
        comma = "," if i < len(items) - 1 else ""
        lines.append(f"\t{json.dumps(k)}: {json.dumps(v, ensure_ascii=False)}{comma}")
    lines.append("}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def is_empty(val) -> bool:
    return not str(val or "").strip()


def pick_value(code: str, key: str, de: dict, en: dict, lang: dict, pwa: dict | None) -> str | None:
    if key in INTENTIONAL_EMPTY:
        return lang.get(key, "") if key in lang else ""
    for src in (lang, pwa, ADMIN_PLATFORM.get(code, {}), MAIN_HERO_BTN_PARTY if key == "main_hero_btn_party" else {}, en, de):
        if isinstance(src, dict) and key in src and not is_empty(src.get(key)):
            return str(src[key])
    if key == "main_hero_btn_party" and code in MAIN_HERO_BTN_PARTY:
        return MAIN_HERO_BTN_PARTY[code]
    if key in ADMIN_PLATFORM.get("en", {}) and code != "de":
        if code in ADMIN_PLATFORM and key in ADMIN_PLATFORM[code]:
            return ADMIN_PLATFORM[code][key]
        return ADMIN_PLATFORM["en"][key]
    return None


def load_all_arbs() -> dict[str, dict]:
    out = {}
    for f in sorted(L10N.glob("app_*.arb")):
        code = f.stem.replace("app_", "")
        if code == "ar":
            continue
        out[code] = load_json(f)
    return out


def fix_arbs(arbs: dict[str, dict]) -> int:
    de = arbs["de"]
    en = arbs["en"]
    ref_keys = [k for k in de if not k.startswith("@")]
    n = 0
    for code, data in arbs.items():
        if code == "de":
            continue
        pwa_path = PWA / f"{code}.json"
        pwa = load_json(pwa_path) if pwa_path.exists() else {}
        for key in ref_keys:
            if not is_empty(data.get(key)):
                continue
            if is_empty(de.get(key)) and key not in INTENTIONAL_EMPTY:
                continue
            val = pick_value(code, key, de, en, data, pwa)
            if val is None:
                continue
            data[key] = val
            n += 1
        save_arb(L10N / f"app_{code}.arb", data)
        arbs[code] = data
    return n


def fix_pwa_babel(arbs: dict[str, dict]) -> int:
    de = load_json(PWA / "de.json")
    en = load_json(PWA / "en.json")
    n = 0
    for f in sorted(PWA.glob("*.json")):
        code = f.stem
        data = load_json(f)
        arb = arbs.get(code, arbs.get("en", {}))
        for key, de_val in de.items():
            if is_empty(data.get(key)) and not is_empty(de_val) and key not in INTENTIONAL_EMPTY:
                val = pick_value(code, key, de, en, arb, data)
                if val is None and not is_empty(en.get(key)):
                    val = en[key]
                if val is not None:
                    data[key] = val
                    n += 1
            elif key not in data and not is_empty(de_val):
                val = pick_value(code, key, de, en, arb, data) or en.get(key) or de_val
                data[key] = val
                n += 1
        if code in MAIN_HERO_BTN_PARTY:
            data["main_hero_btn_party"] = MAIN_HERO_BTN_PARTY[code]
        save_json(f, data)
    return n


def fix_dj_babel(arbs: dict[str, dict]) -> int:
    de = load_json(DJ / "de.json")
    en = load_json(DJ / "en.json")
    ref_keys = set(de.keys())
    n = 0
    for f in sorted(DJ.glob("*.json")):
        code = f.stem
        data = load_json(f)
        arb = arbs.get(code, arbs.get("en", {}))
        for key in ref_keys:
            if key in data and not is_empty(data.get(key)):
                continue
            if key in DJ_MANUAL_KEYS and not is_empty(arb.get(key)):
                data[key] = arb[key]
                n += 1
                continue
            if not is_empty(en.get(key)):
                data[key] = en[key]
                n += 1
            elif not is_empty(de.get(key)):
                data[key] = de[key]
                n += 1
        save_json(f, data)
    return n


def audit_arbs(arbs: dict[str, dict]) -> int:
    de = arbs["de"]
    ref = {k for k in de if not k.startswith("@")}
    issues = 0
    for code, data in sorted(arbs.items()):
        if code == "de":
            continue
        missing = ref - set(data.keys())
        empty = [
            k for k in ref
            if k not in INTENTIONAL_EMPTY
            and not is_empty(de.get(k))
            and is_empty(data.get(k))
        ]
        n = len(missing) + len(empty)
        if n:
            print(f"  ARB {code}: fehlend={len(missing)} leer={len(empty)}")
            issues += n
    return issues


def audit_json(folder: Path, ref_file: Path, label: str) -> int:
    de = load_json(ref_file)
    ref = set(de.keys())
    issues = 0
    for f in sorted(folder.glob("*.json")):
        data = load_json(f)
        missing = ref - set(data.keys())
        empty = [
            k for k in ref
            if k not in INTENTIONAL_EMPTY
            and not is_empty(de.get(k))
            and is_empty(data.get(k))
        ]
        n = len(missing) + len(empty)
        if n:
            print(f"  {label} {f.stem}: fehlend={len(missing)} leer={len(empty)}")
            issues += n
    return issues


def main() -> None:
    print("=== fix_all_l10n_gaps ===")
    arbs = load_all_arbs()
    n_arb = fix_arbs(arbs)
    print(f"ARB: {n_arb} Werte ergänzt")
    n_pwa = fix_pwa_babel(arbs)
    print(f"PWA babel: {n_pwa} Werte ergänzt")
    n_dj = fix_dj_babel(arbs)
    print(f"DJ babel: {n_dj} Werte ergänzt")

    arbs = load_all_arbs()
    print("\n=== Audit nach Fix ===")
    ai = audit_arbs(arbs)
    pi = audit_json(PWA, PWA / "de.json", "PWA")
    di = audit_json(DJ, DJ / "de.json", "DJ")
    total = ai + pi + di
    print(f"\nVerbleibende Issues: {total} (0 = strukturell vollständig)")
    if total:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
