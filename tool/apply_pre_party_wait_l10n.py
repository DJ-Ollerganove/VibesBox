#!/usr/bin/env python3
"""Fügt pre_party_title_with_name + pre_party_subtitle in alle Flutter-ARB-Dateien ein (aus PWA-Babel)."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BABEL_DIR = ROOT / "public/vb/babel/locales"
L10N_DIR = ROOT / "l10n"

KEYS = ("pre_party_title_with_name", "pre_party_subtitle")
ANCHOR = "party_code_not_started"


def load_babel() -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for path in sorted(BABEL_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        code = path.stem
        out[code] = {k: str(data[k]) for k in KEYS if k in data}
    return out


def escape_arb(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def patch_arb(babel: dict[str, dict[str, str]]) -> int:
    count = 0
    for path in sorted(L10N_DIR.glob("app_*.arb")):
        code = path.stem.replace("app_", "")
        translations = babel.get(code)
        if not translations or len(translations) < len(KEYS):
            print(f"WARN: unvollständige Babel-Daten für {code}")
            continue
        text = path.read_text(encoding="utf-8")
        if all(k in text for k in KEYS):
            print(f"SKIP {path.name} (Keys vorhanden)")
            continue
        anchor_match = re.search(
            rf'(\t"{ANCHOR}":\s*"[^"]*",\n)',
            text,
        )
        if not anchor_match:
            print(f"WARN: Anker {ANCHOR} nicht in {path.name}")
            continue
        insert = ""
        for key in KEYS:
            insert += f'\t"{key}": "{escape_arb(translations[key])}",\n'
        new_text = text[: anchor_match.end()] + insert + text[anchor_match.end() :]
        path.write_text(new_text, encoding="utf-8")
        count += 1
        print(f"OK {path.name}")
    return count


def main() -> None:
    babel = load_babel()
    n = patch_arb(babel)
    print(f"Fertig: {n} ARB-Dateien aktualisiert.")


if __name__ == "__main__":
    main()
