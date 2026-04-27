#!/usr/bin/env python3
"""Ersetzt print( und debugPrint( durch debugLog( und fügt den passenden Import ein."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"


def relative_import(from_file: Path) -> str:
    rel = from_file.relative_to(LIB)
    depth = len(rel.parts) - 1
    if depth == 0:
        return "import 'utils/debug_log.dart';"
    prefix = "../" * depth
    return f"import '{prefix}utils/debug_log.dart';"


def needs_transform(text: str) -> bool:
    return bool(re.search(r"\bprint\s*\(", text)) or bool(
        re.search(r"\bdebugPrint\s*\(", text)
    )


def already_has_debug_log_import(text: str) -> bool:
    return "debug_log.dart" in text


def add_import(text: str, imp: str) -> str:
    if already_has_debug_log_import(text):
        return text
    lines = text.splitlines(keepends=True)
    insert_at = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = i + 1
        elif line.startswith("part "):
            insert_at = max(insert_at, i + 1)
    lines.insert(insert_at, imp + "\n")
    return "".join(lines)


def transform(text: str) -> str:
    text = re.sub(r"\bprint\s*\(", "debugLog(", text)
    text = re.sub(r"\bdebugPrint\s*\(", "debugLog(", text)
    return text


def is_part_file(text: str) -> bool:
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith("//"):
            continue
        return s.startswith("part of ")
    return False


def ensure_main_imports_debug_log() -> None:
    main_path = LIB / "main.dart"
    if not main_path.is_file():
        return
    text = main_path.read_text(encoding="utf-8")
    imp = relative_import(main_path)
    if "debug_log.dart" in text:
        return
    main_path.write_text(add_import(text, imp), encoding="utf-8", newline="\n")


def main() -> int:
    skip = {"debug_log.dart"}
    changed = 0
    part_changed = False
    for path in sorted(LIB.rglob("*.dart")):
        if path.name in skip:
            continue
        raw = path.read_text(encoding="utf-8")
        if is_part_file(raw):
            if not needs_transform(raw):
                continue
            new = transform(raw)
            if new != raw:
                path.write_text(new, encoding="utf-8", newline="\n")
                changed += 1
                part_changed = True
            continue
        if not needs_transform(raw):
            continue
        new = transform(raw)
        imp = relative_import(path)
        new = add_import(new, imp)
        if new != raw:
            path.write_text(new, encoding="utf-8", newline="\n")
            changed += 1
    if part_changed:
        ensure_main_imports_debug_log()
    print(f"Updated {changed} files", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
