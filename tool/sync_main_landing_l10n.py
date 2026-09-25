#!/usr/bin/env python3
"""Kopiert Landing-Keys (PWA Root, ohne Kontakt) aus babel/locales → l10n/app_*.arb"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BABEL = ROOT / "public/vb/babel/locales"
L10N = ROOT / "l10n"

KEYS = [
    "main_hero_title",
    "main_hero_tagline",
    "main_hero_btn_code",
    "main_hero_btn_party",
    "main_intro_title",
    "main_intro_paragraph1",
    "main_intro_paragraph2",
    "main_features_accent",
    "main_features_title",
    "main_feature_guest_title",
    "main_feature_guest_body",
    "main_feature_dj_title",
    "main_feature_dj_body",
    "main_feature_auto_title",
    "main_feature_auto_body",
    "main_philosophy_title",
    "main_philosophy_body",
    "main_social_title",
    "main_social_intro",
]


def main() -> None:
    for arb in sorted(L10N.glob("app_*.arb")):
        code = arb.stem.replace("app_", "")
        src = BABEL / f"{code}.json"
        if not src.exists():
            src = BABEL / "en.json"
        babel = json.loads(src.read_text(encoding="utf-8"))

        # Repariere ggf. kaputtes JSON (fehlendes Komma vor eingefügten Keys)
        raw = arb.read_text(encoding="utf-8")
        if '\n\t"main_hero_title"' in raw and '""\n\t"main_hero_title"' in raw:
            raw = raw.replace('""\n\t"main_hero_title"', '""\n,\n\t"main_hero_title"')
            raw = raw.replace('""\n\t"main_hero_title"', '",\n\t"main_hero_title"')

        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            # Letzter Eintrag ohne Komma vor neuen Keys
            import re
            raw = re.sub(
                r'("dj_home_widget_next_party_countdown": "")(\s*\n\t"main_)',
                r'\1,\2',
                raw,
            )
            data = json.loads(raw)

        for key in KEYS:
            if key in babel:
                data[key] = str(babel[key] or "")

        items = [(k, v) for k, v in data.items() if k != "@@locale"]
        lines = ["{"]
        lines.append('\t"@@locale": %s,' % json.dumps(data.get("@@locale", code)))
        for i, (k, v) in enumerate(items):
            comma = "," if i < len(items) - 1 else ""
            lines.append("\t%s: %s%s" % (json.dumps(k), json.dumps(v, ensure_ascii=False), comma))
        lines.append("}")
        arb.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"  ✓ {arb.name}")


if __name__ == "__main__":
    main()
