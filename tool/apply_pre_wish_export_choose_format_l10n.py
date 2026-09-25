#!/usr/bin/env python3
"""Dropdown-Hinweis „Dateiformat wählen“ in alle Sprachen."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "l10n"
KEY = "pre_wish_export_choose_format"

TRANSLATIONS: dict[str, str] = {
    "de": "Dateiformat wählen",
    "en": "Choose file format",
    "fr": "Choisir le format de fichier",
    "es": "Elegir formato de archivo",
    "it": "Scegli formato file",
    "pt": "Escolher formato de ficheiro",
    "nl": "Bestandsformaat kiezen",
    "pl": "Wybierz format pliku",
    "cs": "Vyberte formát souboru",
    "ru": "Выберите формат файла",
    "uk": "Виберіть формат файлу",
    "el": "Επιλέξτε μορφή αρχείου",
    "tr": "Dosya formatı seçin",
    "zh": "选择文件格式",
    "ja": "ファイル形式を選択",
    "hi": "फ़ाइल प्रारूप चुनें",
    "ar": "اختر تنسيق الملف",
    "sq": "Zgjidh formatin e skedarit",
    "vi": "Chọn định dạng tệp",
    "th": "เลือกรูปแบบไฟล์",
}


def main() -> None:
    for locale, value in TRANSLATIONS.items():
        path = ROOT / f"app_{locale}.arb"
        if not path.exists():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        if data.get(KEY) == value:
            print(f"ok {locale}")
            continue
        data[KEY] = value
        path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
        print(f"updated {locale}")


if __name__ == "__main__":
    main()
