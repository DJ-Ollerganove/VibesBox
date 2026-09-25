#!/usr/bin/env python3
"""Ersetzt ScaffoldMessenger.showSnackBar durch showVibesSnackBar (mit Import)."""
from __future__ import annotations

import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib"
IMPORT_LINE = "import '../app_scaffold_messenger.dart';\n"
IMPORT_LINE_DEPTH = "import '{prefix}app_scaffold_messenger.dart';\n"

PATTERNS = [
    (re.compile(r"ScaffoldMessenger\.of\((\w+)\)\.showSnackBar\("), r"showVibesSnackBar(\1, "),
    (re.compile(r"appRootScaffoldMessengerKey\.currentState\?\.showSnackBar\("), r"showRootVibesSnackBar("),
    (re.compile(r"appRootScaffoldMessengerKey\.currentState!\.showSnackBar\("), r"showRootVibesSnackBar("),
]

SKIP = (".backup", ".txt", "app_scaffold_messenger.dart")


def rel_import_prefix(path: Path) -> str:
    rel = path.relative_to(ROOT)
    depth = len(rel.parts) - 1
    return "../" * depth


def process_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "showSnackBar(" not in text:
        return False
    original = text
    for pattern, repl in PATTERNS:
        text = pattern.sub(repl, text)
    if text == original:
        return False

    if "showVibesSnackBar" in text or "showRootVibesSnackBar" in text:
        if "app_scaffold_messenger.dart" not in text:
            prefix = rel_import_prefix(path)
            import_line = IMPORT_LINE_DEPTH.format(prefix=prefix)
            # nach letztem import einfügen
            lines = text.splitlines(keepends=True)
            last_import = 0
            for i, line in enumerate(lines):
                if line.startswith("import "):
                    last_import = i + 1
            lines.insert(last_import, import_line)
            text = "".join(lines)

    path.write_text(text, encoding="utf-8")
    return True


def main() -> None:
    changed = 0
    for path in ROOT.rglob("*.dart"):
        if any(s in path.name for s in SKIP):
            continue
        if process_file(path):
            changed += 1
            print(path.relative_to(ROOT.parent))
    print(f"Geändert: {changed} Dateien")


if __name__ == "__main__":
    main()
