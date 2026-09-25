#!/usr/bin/env python3
"""dj-admin: lang_menu_swipe_hint, RTL-Badge, add_manual_wish (ar) in alle babel-Locales."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES_DIR = ROOT / "public/dj-admin/babel/locales"

NEW_KEYS: dict[str, dict[str, str]] = {
    "lang_menu_swipe_hint": {
        "de": "Nach links oder rechts wischen",
        "en": "Swipe left or right for more languages",
        "ar": "اسحب لليسار أو لليمين لمزيد من اللغات",
        "cs": "Přejeďte doleva nebo doprava pro více jazyků",
        "el": "Σύρετε αριστερά ή δεξιά για περισσότερες γλώσσες",
        "es": "Desliza a izquierda o derecha para más idiomas",
        "fr": "Balayez à gauche ou à droite pour plus de langues",
        "hi": "अधिक भाषाओं के लिए बाएँ या दाएँ स्वाइप करें",
        "it": "Scorri a sinistra o a destra per altre lingue",
        "ja": "左右にスワイプして他の言語を表示",
        "nl": "Veeg naar links of rechts voor meer talen",
        "pl": "Przesuń w lewo lub w prawo, aby zobaczyć więcej języków",
        "pt": "Deslize para a esquerda ou direita para mais idiomas",
        "ru": "Проведите влево или вправо для других языков",
        "sq": "Rrëshqit majtas ose djathtas për më shumë gjuhë",
        "th": "ปัดซ้ายหรือขวาเพื่อดูภาษาเพิ่มเติม",
        "tr": "Daha fazla dil için sola veya sağa kaydırın",
        "uk": "Проведіть вліво або вправо для інших мов",
        "vi": "Vuốt trái hoặc phải để xem thêm ngôn ngữ",
        "zh": "左右滑动查看更多语言",
    },
    "lang_menu_scroll_left": {
        "de": "Nach links scrollen",
        "en": "Scroll left",
        "ar": "التمرير لليسار",
        "cs": "Posunout doleva",
        "el": "Κύλιση αριστερά",
        "es": "Desplazar a la izquierda",
        "fr": "Défiler vers la gauche",
        "hi": "बाएँ स्क्रॉल करें",
        "it": "Scorri a sinistra",
        "ja": "左にスクロール",
        "nl": "Naar links scrollen",
        "pl": "Przewiń w lewo",
        "pt": "Rolar para a esquerda",
        "ru": "Прокрутить влево",
        "sq": "Lëviz majtas",
        "th": "เลื่อนไปทางซ้าย",
        "tr": "Sola kaydır",
        "uk": "Прокрутити вліво",
        "vi": "Cuộn sang trái",
        "zh": "向左滚动",
    },
    "lang_menu_scroll_right": {
        "de": "Nach rechts scrollen",
        "en": "Scroll right",
        "ar": "التمرير لليمين",
        "cs": "Posunout doprava",
        "el": "Κύλιση δεξιά",
        "es": "Desplazar a la derecha",
        "fr": "Défiler vers la droite",
        "hi": "दाएँ स्क्रॉल करें",
        "it": "Scorri a destra",
        "ja": "右にスクロール",
        "nl": "Naar rechts scrollen",
        "pl": "Przewiń w prawo",
        "pt": "Rolar para a direita",
        "ru": "Прокрутить вправо",
        "sq": "Lëviz djathtas",
        "th": "เลื่อนไปทางขวา",
        "tr": "Sağa kaydır",
        "uk": "Прокрутити вправо",
        "vi": "Cuộn sang phải",
        "zh": "向右滚动",
    },
    "dj_rtl_badge_tooltip": {
        "de": "Rechts-nach-links (RTL) — Tabs beginnen rechts: {offen} → {gespielt} → {abgelehnt}",
        "en": "Right-to-left (RTL) — tabs start on the right: {offen} → {gespielt} → {abgelehnt}",
        "ar": "من اليمين إلى اليسار (RTL) — التبويبات تبدأ من اليمين: {offen} → {gespielt} → {abgelehnt}",
        "cs": "Zprava doleva (RTL) — záložky začínají vpravo: {offen} → {gespielt} → {abgelehnt}",
        "el": "Δεξιά προς αριστερά (RTL) — οι καρτέλες ξεκινούν δεξιά: {offen} → {gespielt} → {abgelehnt}",
        "es": "De derecha a izquierda (RTL) — las pestañas empiezan a la derecha: {offen} → {gespielt} → {abgelehnt}",
        "fr": "De droite à gauche (RTL) — les onglets commencent à droite : {offen} → {gespielt} → {abgelehnt}",
        "hi": "दाएँ से बाएँ (RTL) — टैब दाएँ से शुरू: {offen} → {gespielt} → {abgelehnt}",
        "it": "Da destra a sinistra (RTL) — le schede iniziano a destra: {offen} → {gespielt} → {abgelehnt}",
        "ja": "右から左 (RTL) — タブは右から: {offen} → {gespielt} → {abgelehnt}",
        "nl": "Rechts naar links (RTL) — tabbladen beginnen rechts: {offen} → {gespielt} → {abgelehnt}",
        "pl": "Od prawej do lewej (RTL) — zakładki zaczynają się po prawej: {offen} → {gespielt} → {abgelehnt}",
        "pt": "Da direita para a esquerda (RTL) — separadores começam à direita: {offen} → {gespielt} → {abgelehnt}",
        "ru": "Справа налево (RTL) — вкладки начинаются справа: {offen} → {gespielt} → {abgelehnt}",
        "sq": "Nga e djathta në të majtë (RTL) — skedat fillojnë djathtas: {offen} → {gespielt} → {abgelehnt}",
        "th": "ขวาไปซ้าย (RTL) — แท็บเริ่มทางขวา: {offen} → {gespielt} → {abgelehnt}",
        "tr": "Sağdan sola (RTL) — sekmeler sağdan başlar: {offen} → {gespielt} → {abgelehnt}",
        "uk": "Справа наліво (RTL) — вкладки починаються справа: {offen} → {gespielt} → {abgelehnt}",
        "vi": "Phải sang trái (RTL) — tab bắt đầu bên phải: {offen} → {gespielt} → {abgelehnt}",
        "zh": "从右到左 (RTL) — 标签页从右侧开始：{offen} → {gespielt} → {abgelehnt}",
    },
    "dj_rtl_badge_label": {
        "de": "RTL · {lang} · Tabs →",
        "en": "RTL · {lang} · Tabs →",
        "ar": "RTL · {lang} · تبويبات →",
        "cs": "RTL · {lang} · Záložky →",
        "el": "RTL · {lang} · Καρτέλες →",
        "es": "RTL · {lang} · Pestañas →",
        "fr": "RTL · {lang} · Onglets →",
        "hi": "RTL · {lang} · टैब →",
        "it": "RTL · {lang} · Schede →",
        "ja": "RTL · {lang} · タブ →",
        "nl": "RTL · {lang} · Tabs →",
        "pl": "RTL · {lang} · Zakładki →",
        "pt": "RTL · {lang} · Separadores →",
        "ru": "RTL · {lang} · Вкладки →",
        "sq": "RTL · {lang} · Skeda →",
        "th": "RTL · {lang} · แท็บ →",
        "tr": "RTL · {lang} · Sekmeler →",
        "uk": "RTL · {lang} · Вкладки →",
        "vi": "RTL · {lang} · Tab →",
        "zh": "RTL · {lang} · 标签 →",
    },
}

FIX_KEYS: dict[str, dict[str, str]] = {
    "add_manual_wish": {
        "ar": "إضافة أمنية يدوياً",
    },
}


def main() -> None:
    for path in sorted(LOCALES_DIR.glob("*.json")):
        code = path.stem.lower()
        data = json.loads(path.read_text(encoding="utf-8"))
        changed = False
        for key, by_lang in NEW_KEYS.items():
            if key not in data and code in by_lang:
                data[key] = by_lang[code]
                changed = True
        for key, by_lang in FIX_KEYS.items():
            if code in by_lang and data.get(key) != by_lang[code]:
                data[key] = by_lang[code]
                changed = True
        if changed:
            path.write_text(
                json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            print(f"updated {path.name}")


if __name__ == "__main__":
    main()
