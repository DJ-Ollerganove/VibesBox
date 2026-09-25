#!/usr/bin/env python3
"""Fehlende Admin-Keys für Benutzerverwaltung (Sprache, Geräte-Locale)."""
import json
from pathlib import Path

L10N = Path(__file__).resolve().parent.parent / "l10n"

KEYS = [
    "admin_user_app_language_label",
    "admin_user_app_language_not_set",
    "admin_user_app_language_from_device_suffix",
    "admin_device_system_locale",
]

TRANSLATIONS = {
    "de": {
        "admin_user_app_language_label": "App-Sprache",
        "admin_user_app_language_not_set": "nicht gesetzt",
        "admin_user_app_language_from_device_suffix": "(vom Gerät)",
        "admin_device_system_locale": "Systemsprache (Gerät)",
    },
    "en": {
        "admin_user_app_language_label": "App language",
        "admin_user_app_language_not_set": "not set",
        "admin_user_app_language_from_device_suffix": "(from device)",
        "admin_device_system_locale": "Device system locale",
    },
    "fr": {
        "admin_user_app_language_label": "Langue de l'app",
        "admin_user_app_language_not_set": "non définie",
        "admin_user_app_language_from_device_suffix": "(appareil)",
        "admin_device_system_locale": "Langue système (appareil)",
    },
    "es": {
        "admin_user_app_language_label": "Idioma de la app",
        "admin_user_app_language_not_set": "sin definir",
        "admin_user_app_language_from_device_suffix": "(dispositivo)",
        "admin_device_system_locale": "Idioma del sistema (dispositivo)",
    },
    "it": {
        "admin_user_app_language_label": "Lingua app",
        "admin_user_app_language_not_set": "non impostata",
        "admin_user_app_language_from_device_suffix": "(dispositivo)",
        "admin_device_system_locale": "Lingua di sistema (dispositivo)",
    },
    "pt": {
        "admin_user_app_language_label": "Idioma da app",
        "admin_user_app_language_not_set": "não definido",
        "admin_user_app_language_from_device_suffix": "(dispositivo)",
        "admin_device_system_locale": "Idioma do sistema (dispositivo)",
    },
    "nl": {
        "admin_user_app_language_label": "App-taal",
        "admin_user_app_language_not_set": "niet ingesteld",
        "admin_user_app_language_from_device_suffix": "(apparaat)",
        "admin_device_system_locale": "Systeemtaal (apparaat)",
    },
    "pl": {
        "admin_user_app_language_label": "Język aplikacji",
        "admin_user_app_language_not_set": "nie ustawiono",
        "admin_user_app_language_from_device_suffix": "(urządzenie)",
        "admin_device_system_locale": "Język systemu (urządzenie)",
    },
    "cs": {
        "admin_user_app_language_label": "Jazyk aplikace",
        "admin_user_app_language_not_set": "nenastaveno",
        "admin_user_app_language_from_device_suffix": "(zařízení)",
        "admin_device_system_locale": "Systémový jazyk (zařízení)",
    },
    "tr": {
        "admin_user_app_language_label": "Uygulama dili",
        "admin_user_app_language_not_set": "ayarlanmamış",
        "admin_user_app_language_from_device_suffix": "(cihaz)",
        "admin_device_system_locale": "Sistem dili (cihaz)",
    },
    "ru": {
        "admin_user_app_language_label": "Язык приложения",
        "admin_user_app_language_not_set": "не задан",
        "admin_user_app_language_from_device_suffix": "(устройство)",
        "admin_device_system_locale": "Системный язык (устройство)",
    },
    "uk": {
        "admin_user_app_language_label": "Мова застосунку",
        "admin_user_app_language_not_set": "не встановлено",
        "admin_user_app_language_from_device_suffix": "(пристрій)",
        "admin_device_system_locale": "Системна мова (пристрій)",
    },
    "ar": {
        "admin_user_app_language_label": "لغة التطبيق",
        "admin_user_app_language_not_set": "غير محددة",
        "admin_user_app_language_from_device_suffix": "(الجهاز)",
        "admin_device_system_locale": "لغة النظام (الجهاز)",
    },
    "hi": {
        "admin_user_app_language_label": "ऐप भाषा",
        "admin_user_app_language_not_set": "सेट नहीं",
        "admin_user_app_language_from_device_suffix": "(डिवाइस)",
        "admin_device_system_locale": "सिस्टम भाषा (डिवाइस)",
    },
    "ja": {
        "admin_user_app_language_label": "アプリの言語",
        "admin_user_app_language_not_set": "未設定",
        "admin_user_app_language_from_device_suffix": "（端末）",
        "admin_device_system_locale": "システム言語（端末）",
    },
    "zh": {
        "admin_user_app_language_label": "应用语言",
        "admin_user_app_language_not_set": "未设置",
        "admin_user_app_language_from_device_suffix": "（设备）",
        "admin_device_system_locale": "系统语言（设备）",
    },
    "vi": {
        "admin_user_app_language_label": "Ngôn ngữ ứng dụng",
        "admin_user_app_language_not_set": "chưa đặt",
        "admin_user_app_language_from_device_suffix": "(thiết bị)",
        "admin_device_system_locale": "Ngôn ngữ hệ thống (thiết bị)",
    },
    "el": {
        "admin_user_app_language_label": "Γλώσσα εφαρμογής",
        "admin_user_app_language_not_set": "δεν έχει οριστεί",
        "admin_user_app_language_from_device_suffix": "(συσκευή)",
        "admin_device_system_locale": "Γλώσσα συστήματος (συσκευή)",
    },
    "sq": {
        "admin_user_app_language_label": "Gjuha e aplikacionit",
        "admin_user_app_language_not_set": "e papërcaktuar",
        "admin_user_app_language_from_device_suffix": "(pajisje)",
        "admin_device_system_locale": "Gjuha e sistemit (pajisje)",
    },
    "th": {
        "admin_user_app_language_label": "ภาษาแอป",
        "admin_user_app_language_not_set": "ยังไม่ได้ตั้ง",
        "admin_user_app_language_from_device_suffix": "(อุปกรณ์)",
        "admin_device_system_locale": "ภาษาระบบ (อุปกรณ์)",
    },
}


def main() -> None:
    for arb_path in sorted(L10N.glob("app_*.arb")):
        locale = arb_path.stem.replace("app_", "")
        data = json.loads(arb_path.read_text(encoding="utf-8"))
        tr = TRANSLATIONS.get(locale, TRANSLATIONS["en"])
        for key in KEYS:
            data[key] = tr[key]
        arb_path.write_text(
            json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
            encoding="utf-8",
        )
        print(f"OK {arb_path.name}")


if __name__ == "__main__":
    main()
