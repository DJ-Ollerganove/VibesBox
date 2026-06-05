#!/usr/bin/env python3
"""greek, dutch, polish, czech + lang_* (PWA-Menü: English) in alle ARB/JSON."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

LANG_KEYS = ["greek", "dutch", "polish", "czech"]
LANG_MENU = {
    "lang_greek": "Greek",
    "lang_dutch": "Dutch",
    "lang_polish": "Polish",
    "lang_czech": "Czech",
}

ARB_NAMES = {
    "de": {"greek": "Griechisch", "dutch": "Niederländisch", "polish": "Polnisch", "czech": "Tschechisch"},
    "en": {"greek": "Greek", "dutch": "Dutch", "polish": "Polish", "czech": "Czech"},
    "fr": {"greek": "Grec", "dutch": "Néerlandais", "polish": "Polonais", "czech": "Tchèque"},
    "es": {"greek": "Griego", "dutch": "Neerlandés", "polish": "Polaco", "czech": "Checo"},
    "it": {"greek": "Greco", "dutch": "Olandese", "polish": "Polacco", "czech": "Ceco"},
    "pt": {"greek": "Grego", "dutch": "Holandês", "polish": "Polaco", "czech": "Checo"},
    "ru": {"greek": "Греческий", "dutch": "Нидерландский", "polish": "Польский", "czech": "Чешский"},
    "uk": {"greek": "Грецька", "dutch": "Нідерландська", "polish": "Польська", "czech": "Чеська"},
    "tr": {"greek": "Yunanca", "dutch": "Felemenkçe", "polish": "Lehçe", "czech": "Çekçe"},
    "zh": {"greek": "希腊语", "dutch": "荷兰语", "polish": "波兰语", "czech": "捷克语"},
    "hi": {"greek": "ग्रीक", "dutch": "डच", "polish": "पोलिश", "czech": "चेक"},
    "ar": {"greek": "اليونانية", "dutch": "الهولندية", "polish": "البولندية", "czech": "التشيكية"},
    "sq": {"greek": "Greqisht", "dutch": "Holandisht", "polish": "Polonisht", "czech": "Çekisht"},
    "vi": {"greek": "Tiếng Hy Lạp", "dutch": "Tiếng Hà Lan", "polish": "Tiếng Ba Lan", "czech": "Tiếng Séc"},
    "ja": {"greek": "ギリシャ語", "dutch": "オランダ語", "polish": "ポーランド語", "czech": "チェコ語"},
    "el": {"greek": "Ελληνικά", "dutch": "Ολλανδικά", "polish": "Πολωνικά", "czech": "Τσεχικά"},
    "nl": {"greek": "Grieks", "dutch": "Nederlands", "polish": "Pools", "czech": "Tsjechisch"},
    "pl": {"greek": "Grecki", "dutch": "Niderlandzki", "polish": "Polski", "czech": "Czeski"},
    "cs": {"greek": "Řečtina", "dutch": "Nizozemština", "polish": "Polština", "czech": "Čeština"},
}


def patch_arb(path: Path) -> None:
    code = path.stem.replace("app_", "")
    text = path.read_text(encoding="utf-8")
    names = ARB_NAMES.get(code, ARB_NAMES["en"])
    lines_to_add = []
    for k in LANG_KEYS:
        if f'"{k}"' in text:
            continue
        val = names.get(k, ARB_NAMES["en"][k])
        lines_to_add.append(f'  "{k}": "{val.replace(chr(34), chr(92)+chr(34))}",')
    if not lines_to_add:
        return
    block = "\n".join(lines_to_add) + "\n"
    if '"japanese"' in text:
        text = re.sub(r'^(\s*)"japanese":', block + r'\1"japanese":', text, count=1, flags=re.M)
    elif '"vietnamese"' in text:
        text = re.sub(r'^(\s*)"vietnamese":', block + r'\1"vietnamese":', text, count=1, flags=re.M)
    else:
        text = block + text
    path.write_text(text, encoding="utf-8")
    print(f"  arb {path.name}")


def patch_json(path: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    code = path.stem
    names = ARB_NAMES.get(code, ARB_NAMES["en"])
    changed = False
    for lk, en in LANG_MENU.items():
        if data.get(lk) != en:
            data[lk] = en
            changed = True
    for k in LANG_KEYS:
        if k not in data:
            data[k] = names.get(k, ARB_NAMES["en"][k])
            changed = True
    if changed:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"  json {path.name}")


def main() -> None:
    for p in sorted((ROOT / "l10n").glob("app_*.arb")):
        patch_arb(p)
    for p in sorted((ROOT / "public/vb/babel/locales").glob("*.json")):
        patch_json(p)
    print("done")


if __name__ == "__main__":
    main()
