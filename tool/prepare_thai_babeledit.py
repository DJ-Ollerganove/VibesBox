#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Thailändisch für BabelEdit vorbereiten (noch NICHT in App/PWA einbinden).

1. Aktualisiert Quell-DE aus Dart/JS (Export)
2. Legt l10n/app_th.arb und public/vb/babel/locales/th.json als Kopie von DE an

Danach in BabelEdit übersetzen. Einbindung erst nach Freigabe durch Nutzer:
  ./scripts/i18n-sync.sh (+ languages.json, Registry, QR-Menü)
"""

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"
BABEL = ROOT / "public/vb/babel/locales"


def run(cmd: list[str], label: str) -> None:
    print(f"\n=== {label} ===")
    subprocess.run(cmd, cwd=ROOT, check=True)


def copy_de_to_th_arb() -> int:
    de_path = L10N / "app_de.arb"
    th_path = L10N / "app_th.arb"
    data = json.loads(de_path.read_text(encoding="utf-8"))
    data["@@locale"] = "th"
    th_path.write_text(
        json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
        encoding="utf-8",
    )
    keys = sum(1 for k in data if not k.startswith("@"))
    print(f"Wrote {th_path} ({keys} keys, Kopie von app_de.arb)")
    return keys


def copy_de_to_th_json() -> int:
    de_path = BABEL / "de.json"
    th_path = BABEL / "th.json"
    data = json.loads(de_path.read_text(encoding="utf-8"))
    th_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {th_path} ({len(data)} keys, Kopie von de.json)")
    return len(data)


def main() -> None:
    run(["dart", "run", "tool/export_l10n_arb.dart"], "Flutter: app_localizations_de.dart → l10n/app_*.arb")
    run(["node", "scripts/pwa-lang-export-babel.js"], "PWA: public/vb/lang/de.js → babel/locales/*.json")

    arb_n = copy_de_to_th_arb()
    json_n = copy_de_to_th_json()

    print("\n✓ BabelEdit-Vorbereitung fertig.")
    print("  App:  l10n/app_de.arb (Quelle) + l10n/app_th.arb (übersetzen)")
    print("  PWA:  public/vb/babel/locales/de.json (Quelle) + th.json (übersetzen)")
    print(f"  Keys: App {arb_n}, PWA {json_n}")
    print("\n  Noch NICHT ausführen: ./scripts/i18n-sync.sh")
    print("  Sag Bescheid, wenn die Übersetzung fertig ist — dann binde ich Thai ein.")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as e:
        print(f"Fehler (Exit {e.returncode}): {e.cmd}", file=sys.stderr)
        sys.exit(e.returncode)

