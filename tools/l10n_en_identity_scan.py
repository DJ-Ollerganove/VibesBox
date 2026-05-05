# -*- coding: utf-8 -*-
"""
Zählt Einzeilen-Map-Einträge 'key': 'value', bei denen value == en_value (exakt).
Ignoriert mehrzeilige Werte (heuristisch). Liefert Priorität für Lektorat.
"""
import re
from pathlib import Path

L10N = Path(__file__).resolve().parent.parent / "lib" / "l10n"
# Einzeilen: 'key': '...',
LINE_RE = re.compile(
    r"^\s*'(?P<key>[a-zA-Z0-9_]+)':\s*'(?P<val>(?:\\'|[^'])*)'\s*,?\s*$",
    re.MULTILINE,
)


def load_single_line_map(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    return {m.group("key"): m.group("val") for m in LINE_RE.finditer(text)}


def main() -> None:
    en_path = L10N / "app_localizations_en.dart"
    en = load_single_line_map(en_path)
    rows = []
    for p in sorted(L10N.glob("app_localizations_*.dart")):
        code = p.stem.replace("app_localizations_", "")
        if code == "en":
            continue
        other = load_single_line_map(p)
        same = sum(1 for k, v in other.items() if k in en and en[k] == v)
        keys = len(other)
        pct = 100.0 * same / max(keys, 1)
        rows.append((same, pct, code, keys))

    rows.sort(reverse=True)
    print("Identische Einzeilen-Werte wie EN (heuristisch, nur einzeilige 'key': 'val',)\n")
    print(f"{'Spr':>4} {'gleich':>7} {'von':>6} {'%':>6}  Priorität Lektorat")
    for same, pct, code, keys in rows:
        prio = "hoch" if pct > 8 else ("mittel" if pct > 3 else "niedrig")
        print(f"{code:>4} {same:>7} {keys:>6} {pct:>5.1f}%  {prio}")


if __name__ == "__main__":
    main()
