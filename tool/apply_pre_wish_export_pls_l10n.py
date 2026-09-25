#!/usr/bin/env python3
"""PLS-Export-Format + Info-Text in alle Sprachen."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "l10n"

PLS: dict[str, str] = {
    "de": "Als PLS-Datei (.pls)",
    "en": "As PLS file (.pls)",
    "fr": "Fichier PLS (.pls)",
    "es": "Archivo PLS (.pls)",
    "it": "File PLS (.pls)",
    "pt": "Arquivo PLS (.pls)",
    "nl": "PLS-bestand (.pls)",
    "pl": "Plik PLS (.pls)",
    "cs": "Soubor PLS (.pls)",
    "ru": "Файл PLS (.pls)",
    "uk": "Файл PLS (.pls)",
    "el": "Αρχείο PLS (.pls)",
    "tr": "PLS dosyası (.pls)",
    "zh": "PLS 文件 (.pls)",
    "ja": "PLS ファイル (.pls)",
    "hi": "PLS फ़ाइल (.pls)",
    "ar": "ملف PLS (.pls)",
    "sq": "Skedar PLS (.pls)",
    "vi": "Tệp PLS (.pls)",
    "th": "ไฟล์ PLS (.pls)",
}

# Ersetzungen im Info-Body (M3U → M3U und PLS / M3U, PLS)
INFO_PATCHES: dict[str, tuple[str, str]] = {
    "de": (
        "TXT, CSV und M3U sind schlanke Listen",
        "TXT, CSV, M3U und PLS sind schlanke Listen",
    ),
    "en": (
        "TXT, CSV and M3U are compact lists",
        "TXT, CSV, M3U and PLS are compact lists",
    ),
    "fr": (
        "TXT, CSV et M3U sont des listes compactes",
        "TXT, CSV, M3U et PLS sont des listes compactes",
    ),
    "es": (
        "TXT, CSV y M3U son listas compactas",
        "TXT, CSV, M3U y PLS son listas compactas",
    ),
    "it": (
        "TXT, CSV e M3U sono elenchi compatti",
        "TXT, CSV, M3U e PLS sono elenchi compatti",
    ),
    "pt": (
        "TXT, CSV e M3U são listas compactas",
        "TXT, CSV, M3U e PLS são listas compactas",
    ),
    "nl": (
        "TXT, CSV en M3U zijn compacte lijsten",
        "TXT, CSV, M3U en PLS zijn compacte lijsten",
    ),
    "pl": (
        "TXT, CSV i M3U to zwięzłe listy",
        "TXT, CSV, M3U i PLS to zwięzłe listy",
    ),
    "cs": (
        "TXT, CSV a M3U jsou přehledné seznamy",
        "TXT, CSV, M3U a PLS jsou přehledné seznamy",
    ),
    "ru": (
        "TXT, CSV и M3U — компактные списки",
        "TXT, CSV, M3U и PLS — компактные списки",
    ),
    "uk": (
        "TXT, CSV і M3U — компактні списки",
        "TXT, CSV, M3U і PLS — компактні списки",
    ),
    "el": (
        "TXT, CSV και M3U είναι συμπαγείς λίστες",
        "TXT, CSV, M3U και PLS είναι συμπαγείς λίστες",
    ),
    "tr": (
        "TXT, CSV ve M3U kompakt listelerdir",
        "TXT, CSV, M3U ve PLS kompakt listelerdir",
    ),
    "zh": (
        "TXT、CSV 和 M3U 是精简列表",
        "TXT、CSV、M3U 和 PLS 是精简列表",
    ),
    "ja": (
        "TXT、CSV、M3Uはコンパクトなリスト",
        "TXT、CSV、M3U、PLSはコンパクトなリスト",
    ),
    "hi": (
        "TXT, CSV और M3U कॉम्पैक्ट सूचियाँ हैं",
        "TXT, CSV, M3U और PLS कॉम्पैक्ट सूचियाँ हैं",
    ),
    "ar": (
        "ملفات TXT وCSV وM3U قوائم مدمجة",
        "ملفات TXT وCSV وM3U وPLS قوائم مدمجة",
    ),
    "sq": (
        "TXT, CSV dhe M3U janë lista kompakte",
        "TXT, CSV, M3U dhe PLS janë lista kompakte",
    ),
    "vi": (
        "TXT, CSV và M3U là danh sách gọn",
        "TXT, CSV, M3U và PLS là danh sách gọn",
    ),
    "th": (
        "TXT, CSV และ M3U เป็นรายการกระชับ",
        "TXT, CSV, M3U และ PLS เป็นรายการกระชับ",
    ),
}


def main() -> None:
    for locale, pls_label in PLS.items():
        path = ROOT / f"app_{locale}.arb"
        if not path.exists():
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        changed = False
        if data.get("pre_wish_export_format_pls") != pls_label:
            data["pre_wish_export_format_pls"] = pls_label
            changed = True
        if locale in INFO_PATCHES:
            old, new = INFO_PATCHES[locale]
            body = data.get("pre_wish_export_format_info_body", "")
            if old in body and new not in body:
                data["pre_wish_export_format_info_body"] = body.replace(old, new)
                changed = True
        if changed:
            path.write_text(
                json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
                encoding="utf-8",
            )
            print(f"updated {locale}")
        else:
            print(f"ok {locale}")


if __name__ == "__main__":
    main()
