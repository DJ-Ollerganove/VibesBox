#!/usr/bin/env python3
"""Aktualisiert pre_wishes_paused_guest_message in PWA-Babel + Flutter-ARB."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BABEL_DIR = ROOT / "public/vb/babel/locales"
L10N_DIR = ROOT / "l10n"

TRANSLATIONS: dict[str, str] = {
    "de": "Es sind aktuell genug Vorabwünsche eingegangen – deshalb können vorerst keine weiteren abgegeben werden.",
    "en": "Enough advance requests have already been received – no further requests can be submitted for now.",
    "fr": "Assez de demandes anticipées ont déjà été reçues – aucune autre demande ne peut être envoyée pour le moment.",
    "es": "Ya se han recibido suficientes solicitudes anticipadas; por ahora no se pueden enviar más.",
    "it": "Sono già arrivate abbastanza richieste anticipate – per ora non è possibile inviarne altre.",
    "pt": "Já foram recebidos pedidos antecipados suficientes – por agora não é possível enviar mais.",
    "nl": "Er zijn al voldoende verzoeken vooraf binnengekomen – voorlopig kunnen er geen nieuwe meer worden verstuurd.",
    "pl": "Wpłynęło już wystarczająco dużo wcześniejszych próśb – na razie nie można wysyłać kolejnych.",
    "cs": "Již bylo přijato dost předběžných požadavků – prozatím nelze odesílat další.",
    "ru": "Уже поступило достаточно предварительных заявок – пока нельзя отправить новые.",
    "uk": "Вже надійшло достатньо попередніх заявок – поки що не можна надіслати нові.",
    "tr": "Şu anda yeterli sayıda ön talep alındı – şimdilik başka talep gönderilemez.",
    "ar": "تم استلام عدد كافٍ من الطلبات المسبقة – لذلك لا يمكن إرسال المزيد في الوقت الحالي.",
    "hi": "पहले से पर्याप्त अग्रिम अनुरोध प्राप्त हो चुके हैं – अभी के लिए और अनुरोध नहीं भेजे जा सकते।",
    "ja": "現在、十分な数の事前リクエストが届いています。当面はこれ以上送信できません。",
    "zh": "目前已收到足够的预先请求，暂时无法提交更多请求。",
    "vi": "Đã có đủ yêu cầu trước – tạm thời không thể gửi thêm.",
    "el": "Έχουν ήδη ληφθεί αρκετά προκαταβολικά αιτήματα – προς το παρόν δεν μπορούν να υποβληθούν άλλα.",
    "sq": "Janë marrë mjaft kërkesa paraprake – për momentin nuk mund të dërgohen të tjera.",
    "th": "มีคำขอล่วงหน้าเข้ามาเพียงพอแล้ว – ตอนนี้ยังไม่สามารถส่งคำขอเพิ่มได้",
}

KEY = "pre_wishes_paused_guest_message"


def patch_babel() -> int:
    count = 0
    for path in sorted(BABEL_DIR.glob("*.json")):
        code = path.stem
        if code not in TRANSLATIONS:
            print(f"WARN: keine Übersetzung für {code}")
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        data[KEY] = TRANSLATIONS[code]
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        count += 1
    return count


def patch_arb() -> int:
    count = 0
    pattern = re.compile(
        rf'(\t"{KEY}":\s*")([^"]*)(")',
        re.MULTILINE,
    )
    for path in sorted(L10N_DIR.glob("app_*.arb")):
        code = path.stem.replace("app_", "")
        if code not in TRANSLATIONS:
            continue
        text = path.read_text(encoding="utf-8")
        if KEY not in text:
            print(f"WARN: {KEY} fehlt in {path.name}")
            continue
        new_text, n = pattern.subn(
            lambda m: m.group(1) + TRANSLATIONS[code].replace("\\", "\\\\").replace('"', '\\"') + m.group(3),
            text,
            count=1,
        )
        if n != 1:
            print(f"WARN: {path.name} nicht ersetzt (n={n})")
            continue
        path.write_text(new_text, encoding="utf-8")
        count += 1
    return count


def main() -> None:
    babel_n = patch_babel()
    arb_n = patch_arb()
    print(f"OK: {babel_n} babel JSON, {arb_n} ARB aktualisiert")


if __name__ == "__main__":
    main()
