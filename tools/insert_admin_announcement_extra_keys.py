# -*- coding: utf-8 -*-
from pathlib import Path

L10N = Path(__file__).resolve().parents[1] / "lib" / "l10n"
INS = {
    "de": "    'admin_no_announcement_yet': 'Keine Ankündigung vorhanden.',\n    'admin_show_last_announcement_button': 'Letzte Nachricht anzeigen',\n",
    "en": "    'admin_no_announcement_yet': 'No announcement yet.',\n    'admin_show_last_announcement_button': 'Show latest message',\n",
    "es": "    'admin_no_announcement_yet': 'No hay anuncio.',\n    'admin_show_last_announcement_button': 'Ver último mensaje',\n",
    "fr": "    'admin_no_announcement_yet': 'Aucune annonce.',\n    'admin_show_last_announcement_button': 'Afficher le dernier message',\n",
    "it": "    'admin_no_announcement_yet': 'Nessun annuncio.',\n    'admin_show_last_announcement_button': 'Mostra ultimo messaggio',\n",
    "pt": "    'admin_no_announcement_yet': 'Sem anúncio.',\n    'admin_show_last_announcement_button': 'Ver última mensagem',\n",
    "tr": "    'admin_no_announcement_yet': 'Duyuru yok.',\n    'admin_show_last_announcement_button': 'Son mesajı göster',\n",
    "ru": "    'admin_no_announcement_yet': 'Объявлений нет.',\n    'admin_show_last_announcement_button': 'Показать последнее сообщение',\n",
    "uk": "    'admin_no_announcement_yet': 'Немає оголошень.',\n    'admin_show_last_announcement_button': 'Показати останнє повідомлення',\n",
    "zh": "    'admin_no_announcement_yet': '暂无公告。',\n    'admin_show_last_announcement_button': '显示最新消息',\n",
    "ar": "    'admin_no_announcement_yet': 'لا يوجد إعلان.',\n    'admin_show_last_announcement_button': 'عرض آخر رسالة',\n",
}
NEEDLE = "    'announcement_need_subject_or_message':"


def main() -> None:
    for p in sorted(L10N.glob("app_localizations_*.dart")):
        lang = p.stem.replace("app_localizations_", "")
        if lang not in INS:
            continue
        t = p.read_text(encoding="utf-8")
        if "admin_no_announcement_yet" in t:
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
