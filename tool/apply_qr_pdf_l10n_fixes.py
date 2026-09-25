#!/usr/bin/env python3
"""Korrigiert QR/PDF-Export-Übersetzungen in l10n/app_*.arb."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "l10n"

# locale -> {key: new_value}
FIXES: dict[str, dict[str, str]] = {
    "pl": {
        "party_code_label": "Kod imprezy:",
        "party_pdf_single_intro_before": "Zeskanuj kod i wyślij swoje prośby o muzykę bezpośrednio do ",
        "contact_label": "Kontakt",
    },
    "cs": {
        "party_code_label": "Kód večírku:",
        "party_pdf_single": "Jednotlivý",
        "party_pdf_single_intro_before": "Naskenujte kód a pošlete své hudební požadavky přímo ",
        "contact_label": "Kontakt",
    },
    "el": {
        "party_code_label": "Κωδικός πάρτι:",
        "contact_label": "Επικοινωνία",
    },
    "uk": {
        "party_code_label": "Код вечірки:",
        "party_pdf_single": "Одинарний",
        "party_pdf_single_intro_before": "Відскануйте код і надішліть свої музичні побажання безпосередньо ",
        "party_pdf_single_intro_after": "!",
    },
    "sq": {
        "party_code_label": "Kodi i festës:",
        "party_pdf_single": "I vetëm",
    },
    "th": {
        "party_pdf_single": "หน้าเดียว",
    },
    "it": {
        "party_pdf_single": "Singolo",
        "party_pdf_single_intro_before": "Scansiona il codice e invia i tuoi desideri musicali direttamente a ",
    },
    "ru": {
        "party_pdf_single": "Отдельный",
    },
    "nl": {
        "party_pdf_single_intro_before": "Scan de code en stuur je muziekverzoeken rechtstreeks naar ",
        "contact_label": "Contact",
    },
    "ja": {
        "party_code_label": "パーティーコード:",
        "party_pdf_single_intro_before": "コードをスキャンして、音楽リクエストを直接 ",
        "contact_label": "連絡先",
    },
    "vi": {
        "party_pdf_single_intro_before": "Quét mã QR và gửi yêu cầu bài hát của bạn trực tiếp đến ",
    },
}


def main() -> None:
    for locale, keys in FIXES.items():
        path = ROOT / f"app_{locale}.arb"
        if not path.exists():
            print(f"skip missing {path}")
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        changed = []
        for key, value in keys.items():
            if data.get(key) != value:
                data[key] = value
                changed.append(key)
        if changed:
            path.write_text(
                json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
                encoding="utf-8",
            )
            print(f"{locale}: {', '.join(changed)}")
        else:
            print(f"{locale}: ok")


if __name__ == "__main__":
    main()
