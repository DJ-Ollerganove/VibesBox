#!/usr/bin/env python3
"""Repariert durch add_pre_wish_limit_l10n.py beschädigte ARB-Zeilen."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
L10N = ROOT / "l10n"

EXTRA_KEYS_ORDER = [
    "party_pre_wish_limit_label",
    "party_pre_wish_limit_unlimited",
    "party_pre_wish_limit_limited",
    "party_pre_wish_limit_count",
    "pre_wish_limit_remaining",
    "pre_wish_limit_reached",
    "pre_wish_limit_loading",
]


def fix_file(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    m = re.search(
        r'"party_pre_wish_limit_label":\s*"[^"]*",:\s*"((?:[^"\\]|\\.)*)"\s*,',
        text,
    )
    if not m:
        if '"party_allow_pre_wishes_info_body":' in text:
            print(f"ok {path.name}")
            return
        print(f"? {path.name} — manuell prüfen")
        return

    info_body = m.group(1).replace("\\n", "\n")

    # Entferne kaputten Block von info_body-Zeile bis party_wish_limits
    text = re.sub(
        r'\t"party_allow_pre_wishes_info_body"[^\n]*\n'
        r'(?:\t"[^"]+":[^\n]*\n)*?'
        r'\t"party_pre_wish_limit_label":[^\n]*\n',
        "",
        text,
        count=1,
    )

    insert_lines = [
        f'\t"party_allow_pre_wishes_info_body": "{info_body.replace(chr(34), chr(92)+chr(34))}",',
    ]
    for key in EXTRA_KEYS_ORDER:
        km = re.search(rf'"{key}":\s*"((?:[^"\\]|\\.)*)"', path.read_text(encoding="utf-8"))
        if km:
            insert_lines.append(f'\t"{key}": "{km.group(1)}",')

    block = "\n".join(insert_lines) + "\n"
    text = text.replace(
        '\t"party_allow_pre_wishes_info_title":',
        '\t"party_allow_pre_wishes_info_title":',
    )
    text = text.replace(
        '\t"party_allow_pre_wishes_info_title": "',
        '\t"party_allow_pre_wishes_info_title": "',
    )
    # Nach info_title-Zeile einfügen: finde info_title line und party_wish_limits
    text = re.sub(
        r'(\t"party_allow_pre_wishes_info_title":[^\n]+\n)',
        r"\1" + block,
        text,
        count=1,
    )

    path.write_text(text, encoding="utf-8")
    print(f"fixed {path.name}")


def main() -> None:
    for path in sorted(L10N.glob("app_*.arb")):
        fix_file(path)


if __name__ == "__main__":
    main()
