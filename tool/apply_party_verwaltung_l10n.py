#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Party-Verwaltung / Party-History: fehlende l10n-Keys in allen Sprachen."""

import json
from pathlib import Path
from typing import Dict

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

TRANSLATIONS: Dict[str, Dict[str, str]] = {
    "de": {
        "party_history_title": "Party-Historie",
        "dj_home_party_history_title": "Party-Historie",
        "party_management_pro_banner": "Mit Pro unbegrenzt Partys planen",
    },
    "en": {
        "party_history_title": "Party history",
        "dj_home_party_history_title": "Party history",
        "party_management_pro_banner": "Plan unlimited parties with Pro",
    },
    "fr": {
        "party_history_title": "Historique des fêtes",
        "dj_home_party_history_title": "Historique des fêtes",
        "party_management_pro_banner": "Planifie des fêtes illimitées avec Pro",
    },
    "es": {
        "party_history_title": "Historial de fiestas",
        "dj_home_party_history_title": "Historial de fiestas",
        "party_management_pro_banner": "Planifica fiestas ilimitadas con Pro",
    },
    "it": {
        "party_history_title": "Cronologia feste",
        "dj_home_party_history_title": "Cronologia feste",
        "party_management_pro_banner": "Pianifica feste illimitate con Pro",
    },
    "pt": {
        "party_history_title": "Histórico de festas",
        "dj_home_party_history_title": "Histórico de festas",
        "party_management_pro_banner": "Plane festas ilimitadas com Pro",
    },
    "nl": {
        "party_history_title": "Feestgeschiedenis",
        "dj_home_party_history_title": "Feestgeschiedenis",
        "party_management_pro_banner": "Plan onbeperkt feesten met Pro",
    },
    "pl": {
        "party_history_title": "Historia imprez",
        "dj_home_party_history_title": "Historia imprez",
        "party_management_pro_banner": "Planuj nieograniczoną liczbę imprez z Pro",
    },
    "cs": {
        "party_history_title": "Historie párty",
        "dj_home_party_history_title": "Historie párty",
        "party_management_pro_banner": "S Pro plánuj neomezeně párty",
    },
    "tr": {
        "party_history_title": "Parti geçmişi",
        "dj_home_party_history_title": "Parti geçmişi",
        "party_management_pro_banner": "Pro ile sınırsız parti planla",
    },
    "ru": {
        "party_history_title": "История вечеринок",
        "dj_home_party_history_title": "История вечеринок",
        "party_management_pro_banner": "Планируй неограниченное число вечеринок с Pro",
    },
    "uk": {
        "party_history_title": "Історія вечірок",
        "dj_home_party_history_title": "Історія вечірок",
        "party_management_pro_banner": "Плануй необмежену кількість вечірок з Pro",
    },
    "ar": {
        "party_history_title": "سجل الحفلات",
        "dj_home_party_history_title": "سجل الحفلات",
        "party_management_pro_banner": "خطط لحفلات غير محدودة مع Pro",
    },
    "hi": {
        "party_history_title": "पार्टी इतिहास",
        "dj_home_party_history_title": "पार्टी इतिहास",
        "party_management_pro_banner": "Pro के साथ असीमित पार्टियाँ प्लान करें",
    },
    "ja": {
        "party_history_title": "パーティー履歴",
        "dj_home_party_history_title": "パーティー履歴",
        "party_management_pro_banner": "Proで無制限にパーティーを計画",
    },
    "zh": {
        "party_history_title": "派对历史",
        "dj_home_party_history_title": "派对历史",
        "party_management_pro_banner": "使用 Pro 无限制规划派对",
    },
    "vi": {
        "party_history_title": "Lịch sử bữa tiệc",
        "dj_home_party_history_title": "Lịch sử bữa tiệc",
        "party_management_pro_banner": "Lên kế hoạch tiệc không giới hạn với Pro",
    },
    "el": {
        "party_history_title": "Ιστορικό πάρτι",
        "dj_home_party_history_title": "Ιστορικό πάρτι",
        "party_management_pro_banner": "Σχεδίασε απεριόριστα πάρτι με Pro",
    },
    "sq": {
        "party_history_title": "Historiku i festave",
        "dj_home_party_history_title": "Historiku i festave",
        "party_management_pro_banner": "Planifiko festa të pakufizuara me Pro",
    },
}


def main() -> None:
    for arb_path in sorted(L10N.glob("app_*.arb")):
        locale = arb_path.stem.replace("app_", "")
        if locale not in TRANSLATIONS:
            print(f"Überspringe {locale}")
            continue
        data = json.loads(arb_path.read_text(encoding="utf-8"))
        for key, value in TRANSLATIONS[locale].items():
            data[key] = value
        arb_path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
        print(f"OK {arb_path.name}")


if __name__ == "__main__":
    main()
