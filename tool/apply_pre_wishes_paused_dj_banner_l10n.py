#!/usr/bin/env python3
"""DJ-Banner: Vorab-Wünsche pausiert."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

KEY = "pre_wishes_paused_dj_banner"

TRANSLATIONS = {
    "de": "VORABWÜNSCHE PAUSIERT",
    "en": "ADVANCE REQUESTS PAUSED",
    "fr": "DEMANDES ANTICIPÉES EN PAUSE",
    "es": "SOLICITUDES ANTICIPADAS EN PAUSA",
    "it": "RICHIESTE ANTICIPATE IN PAUSA",
    "nl": "VERZOEKEN VOORAF GEPAUZEERD",
    "pt": "PEDIDOS ANTECIPADOS PAUSADOS",
    "pl": "WSTĘPNE PROŚBY WSTRZYMANE",
    "cs": "PŘEDBĚŽNÉ POŽADAVKY POZASTAVENY",
    "uk": "ПОПЕРЕДНІ ЗАЯВКИ ПРИЗУПИНЕНО",
    "ru": "ПРЕДВАРИТЕЛЬНЫЕ ЗАЯВКИ ПРИОСТАНОВЛЕНЫ",
    "tr": "ÖN TALEPLER DURAKLATILDI",
    "ja": "事前リクエスト一時停止中",
    "el": "ΟΙ ΠΡΟΚΑΤΑΒΟΛΙΚΕΣ ΑΙΤΗΣΕΙΣ ΣΕ ΠΑΥΣΗ",
    "ar": "الطلبات المسبقة متوقفة مؤقتًا",
    "vi": "YÊU CẦU TRƯỚC ĐANG TẠM DỪNG",
    "zh": "预先请求已暂停",
    "hi": "अग्रिम अनुरोध रोके गए",
    "sq": "KËRKESAT PARAPRAKE NË PAUZË",
    "th": "คำขอล่วงหน้าหยุดชั่วคราว",
}


def main() -> None:
    en = TRANSLATIONS["en"]
    for arb_path in sorted(L10N.glob("app_*.arb")):
        locale = arb_path.stem.replace("app_", "")
        data = json.loads(arb_path.read_text(encoding="utf-8"))
        data[KEY] = TRANSLATIONS.get(locale, en)
        arb_path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
        print(f"OK {arb_path.name}")


if __name__ == "__main__":
    main()
