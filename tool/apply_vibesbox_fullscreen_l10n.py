#!/usr/bin/env python3
"""VibesBox DJ-Vollbild: Tooltip-Texte."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

KEYS = ["vibesbox_fullscreen_enter", "vibesbox_fullscreen_exit"]

TRANSLATIONS = {
    "de": {
        "vibesbox_fullscreen_enter": "Vollbild",
        "vibesbox_fullscreen_exit": "Minimieren",
    },
    "en": {
        "vibesbox_fullscreen_enter": "Full screen",
        "vibesbox_fullscreen_exit": "Minimize",
    },
    "fr": {
        "vibesbox_fullscreen_enter": "Plein écran",
        "vibesbox_fullscreen_exit": "Réduire",
    },
    "es": {
        "vibesbox_fullscreen_enter": "Pantalla completa",
        "vibesbox_fullscreen_exit": "Minimizar",
    },
    "it": {
        "vibesbox_fullscreen_enter": "Schermo intero",
        "vibesbox_fullscreen_exit": "Riduci",
    },
    "nl": {
        "vibesbox_fullscreen_enter": "Volledig scherm",
        "vibesbox_fullscreen_exit": "Verkleinen",
    },
    "pt": {
        "vibesbox_fullscreen_enter": "Ecrã inteiro",
        "vibesbox_fullscreen_exit": "Minimizar",
    },
    "pl": {
        "vibesbox_fullscreen_enter": "Pełny ekran",
        "vibesbox_fullscreen_exit": "Minimalizuj",
    },
    "cs": {
        "vibesbox_fullscreen_enter": "Celá obrazovka",
        "vibesbox_fullscreen_exit": "Minimalizovat",
    },
    "uk": {
        "vibesbox_fullscreen_enter": "На весь екран",
        "vibesbox_fullscreen_exit": "Згорнути",
    },
    "ru": {
        "vibesbox_fullscreen_enter": "Полный экран",
        "vibesbox_fullscreen_exit": "Свернуть",
    },
    "tr": {
        "vibesbox_fullscreen_enter": "Tam ekran",
        "vibesbox_fullscreen_exit": "Küçült",
    },
    "ja": {
        "vibesbox_fullscreen_enter": "全画面",
        "vibesbox_fullscreen_exit": "最小化",
    },
    "el": {
        "vibesbox_fullscreen_enter": "Πλήρης οθόνη",
        "vibesbox_fullscreen_exit": "Ελαχιστοποίηση",
    },
    "ar": {
        "vibesbox_fullscreen_enter": "ملء الشاشة",
        "vibesbox_fullscreen_exit": "تصغير",
    },
    "vi": {
        "vibesbox_fullscreen_enter": "Toàn màn hình",
        "vibesbox_fullscreen_exit": "Thu nhỏ",
    },
    "zh": {
        "vibesbox_fullscreen_enter": "全屏",
        "vibesbox_fullscreen_exit": "最小化",
    },
    "hi": {
        "vibesbox_fullscreen_enter": "पूर्ण स्क्रीन",
        "vibesbox_fullscreen_exit": "छोटा करें",
    },
    "sq": {
        "vibesbox_fullscreen_enter": "Ekran i plotë",
        "vibesbox_fullscreen_exit": "Minimizo",
    },
    "th": {
        "vibesbox_fullscreen_enter": "เต็มจอ",
        "vibesbox_fullscreen_exit": "ย่อ",
    },
}


def main() -> None:
    en = TRANSLATIONS["en"]
    for arb_path in sorted(L10N.glob("app_*.arb")):
        locale = arb_path.stem.replace("app_", "")
        tr = TRANSLATIONS.get(locale, en)
        data = json.loads(arb_path.read_text(encoding="utf-8"))
        for key in KEYS:
            data[key] = tr.get(key, en[key])
        arb_path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
        print(f"OK {arb_path.name}")


if __name__ == "__main__":
    main()
