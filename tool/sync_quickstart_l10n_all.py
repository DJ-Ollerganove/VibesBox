#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Quickstart-L10n korrekt zusammenführen — ohne DE/EN in alle Dateien zu mischen.

Reihenfolge: headings → update → patch_l10n → remaining → Thai-Sonderblock → DE-Quelle.
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"
TOOL = ROOT / "tool"


def _load(name: str, filename: str):
    path = TOOL / filename
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load {path}")
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def _load_th() -> dict[str, str]:
    th_mod = _load("quickstart_th", "quickstart_l10n_th.py")
    return dict(th_mod.TRANSLATIONS)


def _quickstart_keys(data: dict) -> list[str]:
    return sorted(k for k in data if k.startswith("dj_quickstart_") and not k.startswith("@"))


def main() -> None:
    headings = _load("qs_headings", "apply_quickstart_headings_l10n.py")
    update = _load("qs_update", "apply_quickstart_update_l10n.py")
    patch = _load("qs_patch", "patch_quickstart_l10n.py")
    remaining = _load("qs_remaining", "patch_quickstart_remaining.py")
    th = _load_th()

    en = patch.TRANSLATIONS.get("en", {})
    de_arb = json.loads((L10N / "app_de.arb").read_text(encoding="utf-8"))

    for arb_path in sorted(L10N.glob("app_*.arb")):
        code = arb_path.stem.replace("app_", "")
        data = json.loads(arb_path.read_text(encoding="utf-8"))

        if code == "de":
            merged: dict[str, str] = {
                k: v
                for k, v in de_arb.items()
                if k.startswith("dj_quickstart_")
            }
            for layer in (
                headings.TRANSLATIONS.get("de"),
                update.DE,
            ):
                if layer:
                    merged.update(layer)
        else:
            merged = {}
            for layer in (
                headings.TRANSLATIONS.get(code),
                update.TRANSLATIONS.get(code),
                patch.TRANSLATIONS.get(code),
                remaining.LOCALES.get(code),
                th if code == "th" else None,
            ):
                if layer:
                    merged.update(layer)
            for k, v in en.items():
                merged.setdefault(k, v)

        for k, v in merged.items():
            if k.startswith("dj_quickstart_"):
                data[k] = v

        for obsolete in ("dj_quickstart_h1_stability", "dj_quickstart_p_stability"):
            data.pop(obsolete, None)

        arb_path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
        print(f"✓ {arb_path.name}: {len(_quickstart_keys(data))} quickstart keys")


if __name__ == "__main__":
    main()
