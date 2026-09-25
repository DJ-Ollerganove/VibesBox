#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Wunsch-Verankern: l10n-Keys in allen Sprachen."""

import json
from pathlib import Path
from typing import Dict

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

KEYS = [
    "wish_anchor_tooltip",
    "wish_anchor_remove_tooltip",
    "wish_anchor_limit_snackbar",
    "wish_anchor_update_error",
]

TRANSLATIONS: Dict[str, Dict[str, str]] = {
    "de": {
        "wish_anchor_tooltip": "Wunsch verankern",
        "wish_anchor_remove_tooltip": "Verankerung aufheben",
        "wish_anchor_limit_snackbar": "Maximal 3 Wünsche können verankert werden.",
        "wish_anchor_update_error": "Verankerung konnte nicht gespeichert werden.",
    },
    "en": {
        "wish_anchor_tooltip": "Anchor wish",
        "wish_anchor_remove_tooltip": "Remove anchor",
        "wish_anchor_limit_snackbar": "You can anchor up to 3 wishes only.",
        "wish_anchor_update_error": "Could not save anchor.",
    },
    "fr": {
        "wish_anchor_tooltip": "Ancrer le souhait",
        "wish_anchor_remove_tooltip": "Retirer l'ancre",
        "wish_anchor_limit_snackbar": "Vous pouvez ancrer au maximum 3 souhaits.",
        "wish_anchor_update_error": "Impossible d'enregistrer l'ancre.",
    },
    "es": {
        "wish_anchor_tooltip": "Anclar deseo",
        "wish_anchor_remove_tooltip": "Quitar ancla",
        "wish_anchor_limit_snackbar": "Solo puedes anclar hasta 3 deseos.",
        "wish_anchor_update_error": "No se pudo guardar el ancla.",
    },
    "it": {
        "wish_anchor_tooltip": "Ancora desiderio",
        "wish_anchor_remove_tooltip": "Rimuovi ancora",
        "wish_anchor_limit_snackbar": "Puoi ancorare al massimo 3 desideri.",
        "wish_anchor_update_error": "Impossibile salvare l'ancora.",
    },
    "pt": {
        "wish_anchor_tooltip": "Ancorar pedido",
        "wish_anchor_remove_tooltip": "Remover âncora",
        "wish_anchor_limit_snackbar": "Só podes ancorar até 3 pedidos.",
        "wish_anchor_update_error": "Não foi possível guardar a âncora.",
    },
    "nl": {
        "wish_anchor_tooltip": "Wens verankeren",
        "wish_anchor_remove_tooltip": "Verankering opheffen",
        "wish_anchor_limit_snackbar": "Je kunt maximaal 3 wensen verankeren.",
        "wish_anchor_update_error": "Verankering kon niet worden opgeslagen.",
    },
    "pl": {
        "wish_anchor_tooltip": "Zakotwicz życzenie",
        "wish_anchor_remove_tooltip": "Usuń kotwicę",
        "wish_anchor_limit_snackbar": "Możesz zakotwiczyć maksymalnie 3 życzenia.",
        "wish_anchor_update_error": "Nie udało się zapisać kotwicy.",
    },
    "cs": {
        "wish_anchor_tooltip": "Ukotvit přání",
        "wish_anchor_remove_tooltip": "Zrušit ukotvení",
        "wish_anchor_limit_snackbar": "Můžeš ukotvit maximálně 3 přání.",
        "wish_anchor_update_error": "Ukotvení se nepodařilo uložit.",
    },
    "tr": {
        "wish_anchor_tooltip": "İsteği sabitle",
        "wish_anchor_remove_tooltip": "Sabitlemeyi kaldır",
        "wish_anchor_limit_snackbar": "En fazla 3 istek sabitlenebilir.",
        "wish_anchor_update_error": "Sabitleme kaydedilemedi.",
    },
    "ru": {
        "wish_anchor_tooltip": "Закрепить пожелание",
        "wish_anchor_remove_tooltip": "Снять закрепление",
        "wish_anchor_limit_snackbar": "Можно закрепить не более 3 пожеланий.",
        "wish_anchor_update_error": "Не удалось сохранить закрепление.",
    },
    "uk": {
        "wish_anchor_tooltip": "Закріпити побажання",
        "wish_anchor_remove_tooltip": "Зняти закріплення",
        "wish_anchor_limit_snackbar": "Можна закріпити не більше 3 побажань.",
        "wish_anchor_update_error": "Не вдалося зберегти закріплення.",
    },
    "ar": {
        "wish_anchor_tooltip": "تثبيت الطلب",
        "wish_anchor_remove_tooltip": "إلغاء التثبيت",
        "wish_anchor_limit_snackbar": "يمكنك تثبيت 3 طلبات كحد أقصى.",
        "wish_anchor_update_error": "تعذر حفظ التثبيت.",
    },
    "hi": {
        "wish_anchor_tooltip": "विश इंकर लगाएँ",
        "wish_anchor_remove_tooltip": "इंकर हटाएँ",
        "wish_anchor_limit_snackbar": "अधिकतम 3 विश ही इंकर किए जा सकते हैं।",
        "wish_anchor_update_error": "इंकर सहेजा नहीं जा सका।",
    },
    "ja": {
        "wish_anchor_tooltip": "リクエストを固定",
        "wish_anchor_remove_tooltip": "固定を解除",
        "wish_anchor_limit_snackbar": "固定できるリクエストは最大3件です。",
        "wish_anchor_update_error": "固定を保存できませんでした。",
    },
    "zh": {
        "wish_anchor_tooltip": "锚定请求",
        "wish_anchor_remove_tooltip": "取消锚定",
        "wish_anchor_limit_snackbar": "最多只能锚定 3 个请求。",
        "wish_anchor_update_error": "无法保存锚定。",
    },
    "vi": {
        "wish_anchor_tooltip": "Neo yêu cầu",
        "wish_anchor_remove_tooltip": "Bỏ neo",
        "wish_anchor_limit_snackbar": "Chỉ có thể neo tối đa 3 yêu cầu.",
        "wish_anchor_update_error": "Không thể lưu neo.",
    },
    "el": {
        "wish_anchor_tooltip": "Άγκυρα ευχής",
        "wish_anchor_remove_tooltip": "Αφαίρεση άγκυρας",
        "wish_anchor_limit_snackbar": "Μπορείς να αγκυρώσεις το πολύ 3 ευχές.",
        "wish_anchor_update_error": "Δεν ήταν δυνατή η αποθήκευση της άγκυρας.",
    },
    "sq": {
        "wish_anchor_tooltip": "Ankoro kërkesën",
        "wish_anchor_remove_tooltip": "Hiq ankorimin",
        "wish_anchor_limit_snackbar": "Mund të ankorohen maksimumi 3 kërkesa.",
        "wish_anchor_update_error": "Ankorimi nuk u ruajt.",
    },
}


def main() -> None:
    for arb_path in sorted(L10N.glob("app_*.arb")):
        locale = arb_path.stem.replace("app_", "")
        if locale not in TRANSLATIONS:
            print(f"Überspringe {locale} (keine Übersetzungen)")
            continue
        data = json.loads(arb_path.read_text(encoding="utf-8"))
        for key in KEYS:
            data[key] = TRANSLATIONS[locale][key]
        arb_path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
        print(f"OK {arb_path.name}")


if __name__ == "__main__":
    main()
