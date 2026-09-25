#!/usr/bin/env python3
"""QR-Dialog: Label „Sprache für PDF / Bild“ in alle Sprachen."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "l10n"
KEY = "qr_export_language_label"

TRANSLATIONS: dict[str, str] = {
    "de": "Sprache für PDF / Bild",
    "en": "Language for PDF / image",
    "fr": "Langue pour PDF / image",
    "es": "Idioma para PDF / imagen",
    "it": "Lingua per PDF / immagine",
    "pt": "Idioma para PDF / imagem",
    "nl": "Taal voor PDF / afbeelding",
    "pl": "Język dla PDF / obrazu",
    "cs": "Jazyk pro PDF / obrázek",
    "ru": "Язык для PDF / изображения",
    "uk": "Мова для PDF / зображення",
    "el": "Γλώσσα για PDF / εικόνα",
    "tr": "PDF / görsel için dil",
    "zh": "PDF/图片语言",
    "ja": "PDF／画像の言語",
    "hi": "PDF / छवि के लिए भाषा",
    "ar": "اللغة لملف PDF / الصورة",
    "sq": "Gjuha për PDF / imazh",
    "vi": "Ngôn ngữ cho PDF / ảnh",
    "th": "ภาษาสำหรับ PDF / รูปภาพ",
}


def main() -> None:
    for locale, value in TRANSLATIONS.items():
        path = ROOT / f"app_{locale}.arb"
        if not path.exists():
            print(f"skip {path}")
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get(KEY) == value:
            print(f"{locale}: ok")
            continue
        data[KEY] = value
        path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
        print(f"{locale}: updated")


if __name__ == "__main__":
    main()
