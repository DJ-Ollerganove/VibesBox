# -*- coding: utf-8 -*-
from pathlib import Path

L10N = Path(__file__).resolve().parents[1] / "lib" / "l10n"
INS = {
    "de": "    'admin_set_default_start_view_title': 'Standard-Startansicht festlegen',\n",
    "en": "    'admin_set_default_start_view_title': 'Set default home view',\n",
    "es": "    'admin_set_default_start_view_title': 'Establecer vista de inicio predeterminada',\n",
    "fr": "    'admin_set_default_start_view_title': 'Définir l’écran d’accueil par défaut',\n",
    "it": "    'admin_set_default_start_view_title': 'Imposta schermata iniziale predefinita',\n",
    "pt": "    'admin_set_default_start_view_title': 'Definir vista inicial predefinida',\n",
    "tr": "    'admin_set_default_start_view_title': 'Varsayılan başlangıç görünümünü ayarla',\n",
    "ru": "    'admin_set_default_start_view_title': 'Задать вид главного экрана по умолчанию',\n",
    "uk": "    'admin_set_default_start_view_title': 'Типовий початковий екран',\n",
    "zh": "    'admin_set_default_start_view_title': '设置默认启动视图',\n",
    "ar": "    'admin_set_default_start_view_title': 'تعيين عرض البداية الافتراضي',\n",
}
NEEDLE = "    'admin_dialog_last_announcement_empty_title':"


def main() -> None:
    for p in sorted(L10N.glob("app_localizations_*.dart")):
        lang = p.stem.replace("app_localizations_", "")
        if lang not in INS:
            continue
        t = p.read_text(encoding="utf-8")
        if "'admin_set_default_start_view_title':" in t:
            print("skip", p.name)
            continue
        if NEEDLE not in t:
            print("no needle", p.name)
            continue
        t = t.replace(NEEDLE, INS[lang] + NEEDLE, 1)
        p.write_text(t, encoding="utf-8")
        print("ok", p.name)


if __name__ == "__main__":
    main()
