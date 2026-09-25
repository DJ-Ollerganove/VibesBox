#!/usr/bin/env python3
"""PDF-QR: getrennte Checkboxen Location Name / Location Adresse."""
import json
from pathlib import Path

L10N = Path(__file__).resolve().parent.parent / "l10n"

KEYS = ["pdf_checkbox_location_name", "pdf_checkbox_location_address"]

TRANSLATIONS = {
    "de": {
        "pdf_checkbox_location_name": "Location Name",
        "pdf_checkbox_location_address": "Location Adresse",
    },
    "en": {
        "pdf_checkbox_location_name": "Location name",
        "pdf_checkbox_location_address": "Location address",
    },
    "fr": {
        "pdf_checkbox_location_name": "Nom du lieu",
        "pdf_checkbox_location_address": "Adresse du lieu",
    },
    "es": {
        "pdf_checkbox_location_name": "Nombre del lugar",
        "pdf_checkbox_location_address": "Dirección del lugar",
    },
    "it": {
        "pdf_checkbox_location_name": "Nome location",
        "pdf_checkbox_location_address": "Indirizzo location",
    },
    "pt": {
        "pdf_checkbox_location_name": "Nome do local",
        "pdf_checkbox_location_address": "Morada do local",
    },
    "nl": {
        "pdf_checkbox_location_name": "Locatienaam",
        "pdf_checkbox_location_address": "Locatieadres",
    },
    "pl": {
        "pdf_checkbox_location_name": "Nazwa lokacji",
        "pdf_checkbox_location_address": "Adres lokacji",
    },
    "cs": {
        "pdf_checkbox_location_name": "Název lokality",
        "pdf_checkbox_location_address": "Adresa lokality",
    },
    "tr": {
        "pdf_checkbox_location_name": "Konum adı",
        "pdf_checkbox_location_address": "Konum adresi",
    },
    "ru": {
        "pdf_checkbox_location_name": "Название места",
        "pdf_checkbox_location_address": "Адрес места",
    },
    "uk": {
        "pdf_checkbox_location_name": "Назва локації",
        "pdf_checkbox_location_address": "Адреса локації",
    },
    "ar": {
        "pdf_checkbox_location_name": "اسم الموقع",
        "pdf_checkbox_location_address": "عنوان الموقع",
    },
    "hi": {
        "pdf_checkbox_location_name": "स्थान का नाम",
        "pdf_checkbox_location_address": "स्थान का पता",
    },
    "ja": {
        "pdf_checkbox_location_name": "場所名",
        "pdf_checkbox_location_address": "場所の住所",
    },
    "zh": {
        "pdf_checkbox_location_name": "地点名称",
        "pdf_checkbox_location_address": "地点地址",
    },
    "vi": {
        "pdf_checkbox_location_name": "Tên địa điểm",
        "pdf_checkbox_location_address": "Địa chỉ địa điểm",
    },
    "el": {
        "pdf_checkbox_location_name": "Όνομα τοποθεσίας",
        "pdf_checkbox_location_address": "Διεύθυνση τοποθεσίας",
    },
    "sq": {
        "pdf_checkbox_location_name": "Emri i vendndodhjes",
        "pdf_checkbox_location_address": "Adresa e vendndodhjes",
    },
    "th": {
        "pdf_checkbox_location_name": "ชื่อสถานที่",
        "pdf_checkbox_location_address": "ที่อยู่สถานที่",
    },
}


def main() -> None:
    for arb_path in sorted(L10N.glob("app_*.arb")):
        locale = arb_path.stem.replace("app_", "")
        data = json.loads(arb_path.read_text(encoding="utf-8"))
        tr = TRANSLATIONS.get(locale, TRANSLATIONS["en"])
        for key in KEYS:
            data[key] = tr[key]
        arb_path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
        print(f"OK {arb_path.name}")


if __name__ == "__main__":
    main()
