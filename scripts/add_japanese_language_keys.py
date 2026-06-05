#!/usr/bin/env python3
"""japanese + lang_japanese in alle ARB/JSON (Menüname PWA: English „Japanese“)."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ARB_JAPANESE = {
    "de": "Japanisch",
    "en": "Japanese",
    "fr": "Japonais",
    "es": "Japonés",
    "it": "Giapponese",
    "pt": "Japonês",
    "ru": "Японский",
    "uk": "Японська",
    "tr": "Japonca",
    "zh": "日语",
    "hi": "जापानी",
    "ar": "اليابانية",
    "sq": "Japonisht",
    "vi": "Tiếng Nhật",
    "ja": "日本語",
}


def patch_arb(path: Path) -> None:
    code = path.stem.replace("app_", "")
    text = path.read_text(encoding="utf-8")
    if '"japanese"' in text:
        return
    val = ARB_JAPANESE.get(code, "Japanese")
    esc = val.replace("\\", "\\\\").replace('"', '\\"')
    ins = f'  "japanese": "{esc}",\n'
    if '"vietnamese"' in text:
        text = re.sub(
            r'^(\s*)"vietnamese":',
            ins + r'\1"vietnamese":',
            text,
            count=1,
            flags=re.M,
        )
    elif '"portuguese"' in text:
        text = re.sub(
            r'^(\s*)"portuguese":',
            ins + r'\1"portuguese":',
            text,
            count=1,
            flags=re.M,
        )
    else:
        text = ins + text
    if '"@@locale"' not in text and code == "ja":
        text = '{\n\t"@@locale": "ja",\n' + text.lstrip("{").lstrip()
    path.write_text(text, encoding="utf-8")
    print(f"  arb {path.name}")


def patch_json(path: Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("lang_japanese") == "Japanese" and data.get("japanese"):
        return
    data["lang_japanese"] = "Japanese"
    if "japanese" not in data:
        code = path.stem
        data["japanese"] = ARB_JAPANESE.get(code, "Japanese")
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"  json {path.name}")


def main() -> None:
    for p in sorted((ROOT / "l10n").glob("app_*.arb")):
        patch_arb(p)
    for p in sorted((ROOT / "public/vb/babel/locales").glob("*.json")):
        patch_json(p)
    print("done")


if __name__ == "__main__":
    main()
