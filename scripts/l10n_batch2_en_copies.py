#!/usr/bin/env python3
"""Translate keys that still copy English in non-EN locales."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "lib" / "l10n"
LANGS = ["en", "fr", "es", "it", "pt", "ru", "uk", "tr", "zh", "hi", "sq", "ar"]

# key -> lang -> value (omit lang = no change)
B2: dict[str, dict[str, str]] = {
    "announcement_field_message_label": {
        "fr": "Message", "es": "Mensaje", "it": "Messaggio", "pt": "Mensagem",
        "ru": "Сообщение", "uk": "Повідомлення", "tr": "Mesaj", "zh": "消息",
        "hi": "संदेश", "sq": "Mesazhi", "ar": "رسالة",
    },
    "announcement_progress_original": {
        "fr": "{label} (original)", "es": "{label} (original)", "pt": "{label} (original)",
    },
    "change_password_short": {
        "it": "Password",
    },
    "connectionStable": {
        "es": "Estable", "it": "Stabile", "pt": "Estável", "ru": "Стабильно",
        "uk": "Стабільно", "tr": "Kararlı", "zh": "稳定", "hi": "स्थिर",
        "sq": "Stabil", "ar": "مستقر",
    },
    "contact": {
        "es": "Contacto", "it": "Contatto", "pt": "Contacto", "ru": "Контакт",
        "uk": "Контакт", "tr": "İletişim", "zh": "联系", "hi": "संपर्क",
        "sq": "Kontakt", "ar": "اتصال",
    },
    "contact_email_label": {
        "fr": "E-mail", "es": "Correo electrónico", "it": "E-mail", "pt": "E-mail",
        "ru": "Эл. почта", "uk": "Ел. пошта", "tr": "E-posta", "zh": "电子邮件",
        "hi": "ईमेल", "sq": "E-mail", "ar": "البريد الإلكتروني",
    },
    "contact_error_title": {
        "fr": "Erreur", "es": "Error", "it": "Errore", "pt": "Erro",
        "ru": "Ошибка", "uk": "Помилка", "tr": "Hata", "zh": "错误",
        "hi": "त्रुटि", "sq": "Gabim", "ar": "خطأ",
    },
    "contact_label": {
        "es": "Contacto", "it": "Contatto", "pt": "Contacto", "ru": "Контакт",
        "uk": "Контакт", "tr": "İletişim", "zh": "联系", "hi": "संपर्क",
        "sq": "Kontakt", "ar": "اتصال",
    },
    "dj_home_stats_row_total": {
        "fr": "Total :", "es": "Total:", "it": "Totale:", "pt": "Total:",
        "ru": "Всего:", "uk": "Усього:", "tr": "Toplam:", "zh": "总计：",
        "hi": "कुल:", "sq": "Totali:", "ar": "الإجمالي:",
    },
    "dj_quickstart_h1_notifications": {
        "es": "Notificaciones", "it": "Notifiche", "pt": "Notificações",
        "ru": "Уведомления", "uk": "Сповіщення", "tr": "Bildirimler",
        "zh": "通知", "hi": "सूचनाएँ", "sq": "Njoftimet", "ar": "الإشعارات",
    },
    "error": {
        "fr": "Erreur", "es": "Error", "it": "Errore", "pt": "Erro",
        "ru": "Ошибка", "uk": "Помилка", "tr": "Hata", "zh": "错误",
        "hi": "त्रुटि", "sq": "Gabim", "ar": "خطأ",
    },
    "history_page": {
        "es": "Página", "it": "Pagina", "pt": "Página", "ru": "Страница",
        "uk": "Сторінка", "tr": "Sayfa", "zh": "页", "hi": "पृष्ठ",
        "sq": "Faqja", "ar": "صفحة",
    },
    "italian": {
        "fr": "Italien", "es": "Italiano", "it": "Italiano", "pt": "Italiano",
        "ru": "Итальянский", "uk": "Італійська", "tr": "İtalyanca",
        "zh": "意大利语", "hi": "इतालवी", "sq": "Italisht", "ar": "الإيطالية",
    },
    "labelDjId": {
        "fr": "ID DJ", "es": "ID de DJ", "ru": "ID DJ", "uk": "ID DJ",
        "tr": "DJ Kimliği", "zh": "DJ ID", "hi": "DJ ID", "sq": "ID DJ",
        "ar": "معرّف DJ",
    },
    "label_date": {
        "es": "Fecha", "it": "Data", "pt": "Data", "ru": "Дата",
        "uk": "Дата", "tr": "Tarih", "zh": "日期", "hi": "तारीख",
        "sq": "Data", "ar": "التاريخ",
    },
    "label_message": {
        "fr": "Message", "es": "Mensaje", "it": "Messaggio", "pt": "Mensagem",
        "ru": "Сообщение", "uk": "Повідомлення", "tr": "Mesaj", "zh": "消息",
        "hi": "संदेश", "sq": "Mesazhi", "ar": "رسالة",
    },
    "login_password_label": {
        "it": "Password",
    },
    "party_minute": {
        "fr": "minute", "es": "minuto", "it": "minuto", "pt": "minuto",
        "ru": "минута", "uk": "хвилина", "tr": "dakika", "zh": "分钟",
        "hi": "मिनट", "sq": "minutë", "ar": "دقيقة",
    },
    "party_minutes": {
        "fr": "minutes", "es": "minutos", "it": "minuti", "pt": "minutos",
        "ru": "минут", "uk": "хвилин", "tr": "dakika", "zh": "分钟",
        "hi": "मिनट", "sq": "minuta", "ar": "دقائق",
    },
    "party_pdf_poster_a4": {
        "fr": "Affiche (A4)", "es": "Cartel (A4)", "it": "Manifesto (A4)",
        "pt": "Cartaz (A4)", "ru": "Плакат (A4)", "uk": "Плакат (A4)",
        "tr": "Afiş (A4)", "zh": "海报 (A4)", "hi": "पोस्टर (A4)",
        "sq": "Poster (A4)", "ar": "ملصق (A4)",
    },
    "party_private": {
        "sq": "Privat",
    },
    "party_type_private": {
        "sq": "Privat",
    },
    "party_type_public": {
        "es": "Público", "it": "Pubblico", "pt": "Público", "ru": "Публичная",
        "uk": "Публічна", "tr": "Herkese açık", "zh": "公开", "hi": "सार्वजनिक",
        "sq": "Publike", "ar": "عامة",
    },
    "paywall_tip_badge": {
        "fr": "ASTUCE", "es": "CONSEJO", "it": "SUGGERIMENTO", "pt": "DICA",
        "ru": "СОВЕТ", "uk": "ПОРАДА", "tr": "İPUCU", "zh": "提示",
        "hi": "सुझाव", "sq": "KËSHILLË", "ar": "نصيحة",
    },
    "pdf_checkbox_email": {
        "fr": "E-mail", "es": "Correo electrónico", "it": "E-mail", "pt": "E-mail",
        "ru": "Эл. почта", "uk": "Ел. пошта", "tr": "E-posta", "zh": "电子邮件",
        "hi": "ईमेल", "sq": "E-mail", "ar": "البريد الإلكتروني",
    },
    "permanent": {
        "es": "Permanente", "it": "Permanente", "pt": "Permanente",
        "ru": "Постоянно", "uk": "Постійно", "tr": "Kalıcı", "zh": "永久",
        "hi": "स्थायी", "sq": "E përhershme", "ar": "دائم",
    },
    "profile_alternative_email_dialog_email": {
        "fr": "E-mail", "es": "Correo electrónico", "it": "E-mail", "pt": "E-mail",
        "ru": "Эл. почта", "uk": "Ел. пошта", "tr": "E-posta", "zh": "电子邮件",
        "hi": "ईमेल", "sq": "E-mail", "ar": "البريد الإلكتروني",
    },
    "profile_email": {
        "fr": "E-mail", "es": "Correo electrónico", "it": "E-mail", "pt": "E-mail",
        "ru": "Эл. почта", "uk": "Ел. пошта", "tr": "E-posta", "zh": "电子邮件",
        "hi": "ईमेल", "sq": "E-mail", "ar": "البريد الإلكتروني",
    },
    "reSyncStreams": {
        "fr": "[ RESYNCHRONISER LES FLUX ]",
        "es": "[ RESINCRONIZAR FLUJOS ]",
        "it": "[ RISINCRONIZZA STREAM ]",
        "pt": "[ RESSINCRONIZAR STREAMS ]",
        "ru": "[ ПОВТОРНАЯ СИНХРОНИЗАЦИЯ ПОТОКОВ ]",
        "uk": "[ ПОВТОРНА СИНХРОНІЗАЦІЯ ПОТОКІВ ]",
        "tr": "[ AKIŞLARI YENİDEN SENKRONİZE ET ]",
        "zh": "[ 重新同步流 ]",
        "hi": "[ स्ट्रीम पुनः सिंक करें ]",
        "sq": "[ RISINKRONIZO STREAMS ]",
        "ar": "[ إعادة مزامنة البث ]",
    },
    "settings_section_notifications": {
        "es": "Notificaciones", "it": "Notifiche", "pt": "Notificações",
        "ru": "Уведомления", "uk": "Сповіщення", "tr": "Bildirimler",
        "zh": "通知", "hi": "सूचनाएँ", "sq": "Njoftimet", "ar": "الإشعارات",
    },
    "signalLabel": {
        "fr": "Signal radio", "es": "Señal", "it": "Segnale", "pt": "Sinal",
        "ru": "Сигнал", "uk": "Сигнал", "tr": "Sinyal", "zh": "信号",
        "hi": "सिग्नल", "sq": "Sinjali", "ar": "إشارة",
    },
    "spotify_admin_slider_minutes": {
        "ru": "{minutes} мин.", "uk": "{minutes} хв.", "tr": "{minutes} dk.",
        "zh": "{minutes} 分钟", "hi": "{minutes} मिनट", "ar": "{minutes} د.",
    },
    "time_suffix": {
        "en": "",
        "it": "",
        "ru": "",
        "uk": "",
        "tr": "",
        "zh": "",
        "hi": "",
        "sq": "",
        "ar": "",
    },
    "total_wishes": {
        "fr": "Total des souhaits", "es": "Total de deseos", "it": "Totale desideri",
        "pt": "Total de desejos", "ru": "Всего пожеланий", "uk": "Усього побажань",
        "tr": "Toplam istek", "zh": "愿望总数", "hi": "कुल इच्छाएँ",
        "sq": "Totali i dëshirave", "ar": "إجمالي الطلبات",
    },
    "update_local_label": {
        "it": "Locale", "ru": "Локально", "uk": "Локально", "tr": "Yerel",
        "zh": "本地", "hi": "स्थानीय", "sq": "Lokal", "ar": "محلي",
    },
    "interval_seconds_short": {
        "sq": "Sek.",
    },
    "admin_device_platform": {
        "tr": "Platform",
    },
    "admin_password_change_functions_error": {
        "es": "Error de Cloud Functions al cambiar la contraseña",
    },
}


def set_in_file(path: Path, updates: dict[str, str]) -> int:
    content = path.read_text(encoding="utf-8")
    n = 0
    for key, new_val in updates.items():
        escaped = new_val.replace("\\", "\\\\").replace("'", "\\'")
        pattern = rf"('{re.escape(key)}'\s*:\s*)'(?:\\'|[^'])*'"
        new_content, c = re.subn(pattern, rf"\1'{escaped}'", content, count=1)
        if c:
            content = new_content
            n += 1
    path.write_text(content, encoding="utf-8")
    return n


def main():
    total = 0
    for lang in LANGS:
        path = L10N / f"app_localizations_{lang}.dart"
        updates = {k: v[lang] for k, v in B2.items() if lang in v}
        if updates:
            n = set_in_file(path, updates)
            total += n
            print(f"{lang}: {n} updates")
    print(f"Total: {total}")


if __name__ == "__main__":
    main()
