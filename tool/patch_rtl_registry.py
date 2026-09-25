#!/usr/bin/env python3
"""Ersetzt hardcodierte RTL-Listen durch VbTextDirection (Quelle: languages.json)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"
IMPORT = "import 'package:vibesbox/l10n/text_direction_helper.dart';\n"

RTL_LIST = r"\[\s*'ar'\s*,\s*'he'\s*,\s*'fa'\s*,\s*'ur'\s*\]"

REPLACEMENTS = [
    (
        re.compile(RTL_LIST + r"\s*\.contains\(\s*Localizations\.localeOf\(context\)\.languageCode\s*\)"),
        "VbTextDirection.isRtl(context)",
    ),
    (
        re.compile(RTL_LIST + r"\s*\.contains\(\s*Localizations\.localeOf\(ctx\)\.languageCode\s*\)"),
        "VbTextDirection.isRtl(ctx)",
    ),
    (
        re.compile(RTL_LIST + r"\s*\.contains\(\s*locale\.languageCode\s*\)"),
        "VbTextDirection.isRtlLocale(locale)",
    ),
    (
        re.compile(RTL_LIST + r"\s*\.contains\(\s*locale\s*\)"),
        "VbTextDirection.isRtlLanguageCode(locale)",
    ),
    (
        re.compile(r"return\s+" + RTL_LIST + r"\s*\.contains\(\s*Localizations\.localeOf\(context\)\.languageCode\s*\)\s*;"),
        "return VbTextDirection.isRtl(context);",
    ),
]


def patch_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    original = text
    for pattern, repl in REPLACEMENTS:
        text = pattern.sub(repl, text)
    if text == original:
        return False
    if "VbTextDirection." in text and IMPORT.strip() not in text:
        lines = text.splitlines(keepends=True)
        insert_at = 0
        for i, line in enumerate(lines):
            if line.startswith("import "):
                insert_at = i + 1
            elif line.strip() and not line.startswith("//") and insert_at > 0:
                break
        lines.insert(insert_at, IMPORT)
        text = "".join(lines)
    path.write_text(text, encoding="utf-8")
    return True


def main() -> None:
    changed = 0
    for path in sorted(LIB.rglob("*.dart")):
        if ".backup" in path.name:
            continue
        if patch_file(path):
            print(f"  ✓ {path.relative_to(ROOT)}")
            changed += 1
    print(f"Fertig: {changed} Dateien angepasst.")


if __name__ == "__main__":
    main()
