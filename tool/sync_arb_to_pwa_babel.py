#!/usr/bin/env python3
"""Kopiert alle ARB-Keys, die auch in PWA-en.json existieren, in public/vb/babel/locales/*.json."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"
PWA = ROOT / "public" / "vb" / "babel" / "locales"

en_pwa = json.loads((PWA / "en.json").read_text(encoding="utf-8"))
pwa_keys = set(en_pwa.keys())

total = 0
for arb_path in sorted(L10N.glob("app_*.arb")):
    code = arb_path.stem.replace("app_", "")
    pwa_path = PWA / f"{code}.json"
    if not pwa_path.exists():
        continue
    arb = json.loads(arb_path.read_text(encoding="utf-8"))
    pwa = json.loads(pwa_path.read_text(encoding="utf-8"))
    changed = 0
    for key in pwa_keys:
        if key.startswith("@"):
            continue
        if key in arb and pwa.get(key) != arb[key]:
            pwa[key] = arb[key]
            changed += 1
    if changed:
        pwa_path.write_text(json.dumps(pwa, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"  {code}.json: {changed} keys")
        total += changed

print(f"Done: {total} key writes to PWA babel JSON")
