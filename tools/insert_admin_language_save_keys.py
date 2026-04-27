# -*- coding: utf-8 -*-
from pathlib import Path

L10N = Path(__file__).resolve().parents[1] / "lib" / "l10n"
BLOCK = {
    "de": "    'admin_language_save': 'Sprache speichern',\n    'admin_language_saving': 'Speichern…',\n",
    "en": "    'admin_language_save': 'Save language',\n    'admin_language_saving': 'Saving…',\n",
    "es": "    'admin_language_save': 'Guardar idioma',\n    'admin_language_saving': 'Guardando…',\n",
    "fr": "    'admin_language_save': 'Enregistrer la langue',\n    'admin_language_saving': 'Enregistrement…',\n",
    "it": "    'admin_language_save': 'Salva lingua',\n    'admin_language_saving': 'Salvataggio…',\n",
    "pt": "    'admin_language_save': 'Guardar idioma',\n    'admin_language_saving': 'A guardar…',\n",
    "tr": "    'admin_language_save': 'Dili kaydet',\n    'admin_language_saving': 'Kaydediliyor…',\n",
    "ru": "    'admin_language_save': 'Сохранить язык',\n    'admin_language_saving': 'Сохранение…',\n",
    "uk": "    'admin_language_save': 'Зберегти мову',\n    'admin_language_saving': 'Збереження…',\n",
    "zh": "    'admin_language_save': '保存语言',\n    'admin_language_saving': '正在保存…',\n",
    "ar": "    'admin_language_save': 'حفظ اللغة',\n    'admin_language_saving': 'جاري الحفظ…',\n",
}
NEEDLE = "    'announcement_need_subject_or_message':"


def main() -> None:
    for p in sorted(L10N.glob("app_localizations_*.dart")):
        lang = p.stem.replace("app_localizations_", "")
        if lang not in BLOCK:
            continue
        t = p.read_text(encoding="utf-8")
        if "'admin_language_save':" in t:
            print("skip", p.name)
            continue
        if NEEDLE not in t:
            print("no needle", p.name)
            continue
        t = t.replace(NEEDLE, BLOCK[lang] + NEEDLE, 1)
        p.write_text(t, encoding="utf-8")
        print("ok", p.name)


if __name__ == "__main__":
    main()
