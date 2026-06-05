#!/usr/bin/env python3
"""Fügt Vorab-Wunsch-Limit-Keys in alle ARB- und Babel-JSON-Dateien ein."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

KEYS = {
    "de": {
        "party_pre_wish_limit_label": "Vorab-Wünsche pro Gast",
        "party_pre_wish_limit_unlimited": "Unbegrenzt",
        "party_pre_wish_limit_limited": "Limit pro Gast",
        "party_pre_wish_limit_count": "Max. Vorab-Wünsche",
        "pre_wish_limit_remaining": "Noch {remaining} von {limit} Vorab-Wünschen möglich",
        "pre_wish_limit_reached": "Du hast das Limit von {limit} Vorab-Wünschen erreicht.",
        "pre_wish_limit_loading": "Lade Vorab-Limit…",
    },
    "en": {
        "party_pre_wish_limit_label": "Advance wishes per guest",
        "party_pre_wish_limit_unlimited": "Unlimited",
        "party_pre_wish_limit_limited": "Limit per guest",
        "party_pre_wish_limit_count": "Max. advance wishes",
        "pre_wish_limit_remaining": "{remaining} of {limit} advance wishes still possible",
        "pre_wish_limit_reached": "You have reached the limit of {limit} advance wishes.",
        "pre_wish_limit_loading": "Loading advance wish limit…",
    },
    "fr": {
        "party_pre_wish_limit_label": "Souhaits anticipés par invité",
        "party_pre_wish_limit_unlimited": "Illimité",
        "party_pre_wish_limit_limited": "Limite par invité",
        "party_pre_wish_limit_count": "Max. souhaits anticipés",
        "pre_wish_limit_remaining": "Encore {remaining} sur {limit} souhaits anticipés possibles",
        "pre_wish_limit_reached": "Vous avez atteint la limite de {limit} souhaits anticipés.",
        "pre_wish_limit_loading": "Chargement de la limite…",
    },
    "es": {
        "party_pre_wish_limit_label": "Deseos anticipados por invitado",
        "party_pre_wish_limit_unlimited": "Ilimitado",
        "party_pre_wish_limit_limited": "Límite por invitado",
        "party_pre_wish_limit_count": "Máx. deseos anticipados",
        "pre_wish_limit_remaining": "Aún {remaining} de {limit} deseos anticipados posibles",
        "pre_wish_limit_reached": "Has alcanzado el límite de {limit} deseos anticipados.",
        "pre_wish_limit_loading": "Cargando límite…",
    },
    "it": {
        "party_pre_wish_limit_label": "Richieste anticipate per ospite",
        "party_pre_wish_limit_unlimited": "Illimitato",
        "party_pre_wish_limit_limited": "Limite per ospite",
        "party_pre_wish_limit_count": "Max. richieste anticipate",
        "pre_wish_limit_remaining": "Ancora {remaining} di {limit} richieste anticipate possibili",
        "pre_wish_limit_reached": "Hai raggiunto il limite di {limit} richieste anticipate.",
        "pre_wish_limit_loading": "Caricamento limite…",
    },
    "pt": {
        "party_pre_wish_limit_label": "Pedidos antecipados por convidado",
        "party_pre_wish_limit_unlimited": "Ilimitado",
        "party_pre_wish_limit_limited": "Limite por convidado",
        "party_pre_wish_limit_count": "Máx. pedidos antecipados",
        "pre_wish_limit_remaining": "Ainda {remaining} de {limit} pedidos antecipados possíveis",
        "pre_wish_limit_reached": "Atingiste o limite de {limit} pedidos antecipados.",
        "pre_wish_limit_loading": "A carregar limite…",
    },
    "ru": {
        "party_pre_wish_limit_label": "Предварительные пожелания на гостя",
        "party_pre_wish_limit_unlimited": "Без ограничений",
        "party_pre_wish_limit_limited": "Лимит на гостя",
        "party_pre_wish_limit_count": "Макс. предварительных пожеланий",
        "pre_wish_limit_remaining": "Ещё {remaining} из {limit} предварительных пожеланий доступно",
        "pre_wish_limit_reached": "Вы достигли лимита в {limit} предварительных пожеланий.",
        "pre_wish_limit_loading": "Загрузка лимита…",
    },
    "uk": {
        "party_pre_wish_limit_label": "Попередні побажання на гостя",
        "party_pre_wish_limit_unlimited": "Без обмежень",
        "party_pre_wish_limit_limited": "Ліміт на гостя",
        "party_pre_wish_limit_count": "Макс. попередніх побажань",
        "pre_wish_limit_remaining": "Ще {remaining} з {limit} попередніх побажань доступно",
        "pre_wish_limit_reached": "Ви досягли ліміту в {limit} попередніх побажань.",
        "pre_wish_limit_loading": "Завантаження ліміту…",
    },
    "tr": {
        "party_pre_wish_limit_label": "Misafir başına ön istek",
        "party_pre_wish_limit_unlimited": "Sınırsız",
        "party_pre_wish_limit_limited": "Misafir başına limit",
        "party_pre_wish_limit_count": "Maks. ön istek",
        "pre_wish_limit_remaining": "Bu partide hâlâ {remaining} / {limit} ön istek mümkün",
        "pre_wish_limit_reached": "{limit} ön istek limitine ulaştınız.",
        "pre_wish_limit_loading": "Limit yükleniyor…",
    },
    "zh": {
        "party_pre_wish_limit_label": "每位客人的预先点歌",
        "party_pre_wish_limit_unlimited": "无限制",
        "party_pre_wish_limit_limited": "每位客人限制",
        "party_pre_wish_limit_count": "最多预先点歌数",
        "pre_wish_limit_remaining": "还可发送 {remaining}/{limit} 个预先点歌",
        "pre_wish_limit_reached": "您已达到 {limit} 个预先点歌的上限。",
        "pre_wish_limit_loading": "正在加载限制…",
    },
    "hi": {
        "party_pre_wish_limit_label": "प्रति अतिथि पूर्व-अनुरोध",
        "party_pre_wish_limit_unlimited": "असीमित",
        "party_pre_wish_limit_limited": "प्रति अतिथि सीमा",
        "party_pre_wish_limit_count": "अधिकतम पूर्व-अनुरोध",
        "pre_wish_limit_remaining": "अभी भी {remaining}/{limit} पूर्व-अनुरोध संभव",
        "pre_wish_limit_reached": "आप {limit} पूर्व-अनुरोधों की सीमा तक पहुँच गए हैं।",
        "pre_wish_limit_loading": "सीमा लोड हो रही है…",
    },
    "ar": {
        "party_pre_wish_limit_label": "طلبات مسبقة لكل ضيف",
        "party_pre_wish_limit_unlimited": "غير محدود",
        "party_pre_wish_limit_limited": "حد لكل ضيف",
        "party_pre_wish_limit_count": "الحد الأقصى للطلبات المسبقة",
        "pre_wish_limit_remaining": "لا يزال بإمكانك إرسال {remaining} من {limit} طلبات مسبقة",
        "pre_wish_limit_reached": "لقد وصلت إلى حد {limit} طلبات مسبقة.",
        "pre_wish_limit_loading": "جاري تحميل الحد…",
    },
    "sq": {
        "party_pre_wish_limit_label": "Kërkesa paraprake për mysafir",
        "party_pre_wish_limit_unlimited": "I pakufizuar",
        "party_pre_wish_limit_limited": "Limit për mysafir",
        "party_pre_wish_limit_count": "Maks. kërkesa paraprake",
        "pre_wish_limit_remaining": "Ende {remaining} nga {limit} kërkesa paraprake të mundshme",
        "pre_wish_limit_reached": "Ke arritur limitin prej {limit} kërkesash paraprake.",
        "pre_wish_limit_loading": "Duke ngarkuar limitin…",
    },
    "vi": {
        "party_pre_wish_limit_label": "Yêu cầu trước mỗi khách",
        "party_pre_wish_limit_unlimited": "Không giới hạn",
        "party_pre_wish_limit_limited": "Giới hạn mỗi khách",
        "party_pre_wish_limit_count": "Tối đa yêu cầu trước",
        "pre_wish_limit_remaining": "Còn {remaining}/{limit} yêu cầu trước có thể gửi",
        "pre_wish_limit_reached": "Bạn đã đạt giới hạn {limit} yêu cầu trước.",
        "pre_wish_limit_loading": "Đang tải giới hạn…",
    },
}


def patch_arb(code: str) -> None:
    path = ROOT / "l10n" / f"app_{code}.arb"
    if not path.exists():
        print(f"skip arb {code}")
        return
    text = path.read_text(encoding="utf-8")
    for key, val in KEYS[code].items():
        if f'"{key}"' in text:
            continue
        esc = val.replace("\\", "\\\\").replace('"', '\\"')
        insert = f'\t"{key}": "{esc}",\n'
        marker = '"party_allow_pre_wishes_info_body"'
        if marker in text:
            text = text.replace(
                marker,
                marker + "\n" + insert.rstrip("\n"),
                1,
            )
        else:
            text += "\n" + insert
    path.write_text(text, encoding="utf-8")
    print(f"✓ {path.name}")


def patch_json(code: str) -> None:
    path = ROOT / "public/vb/babel/locales" / f"{code}.json"
    if not path.exists():
        print(f"skip json {code}")
        return
    data = json.loads(path.read_text(encoding="utf-8"))
    data.update(KEYS[code])
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"✓ locales/{code}.json")


def main() -> None:
    for code in KEYS:
        patch_arb(code)
        patch_json(code)
    print("done")


if __name__ == "__main__":
    main()
