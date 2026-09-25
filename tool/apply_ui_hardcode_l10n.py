#!/usr/bin/env python3
"""L10n: hardcodierte Snackbars/Dialoge/Banner → ARB-Keys in allen Sprachen."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
L10N = ROOT / "l10n"

# DE master
DE: dict[str, str] = {
    "pro_promotion_banner_message": "VibesBox Pro für volle Kontrolle",
    "open_wishes_reorder_hint": (
        "Sortieren: weiße Linie = Ablageposition — auch vor dem ersten und nach dem letzten Titel."
    ),
    "mandatory_profile_title": "Profil vervollständigen",
    "mandatory_profile_intro": (
        "Um VibesBox noch besser zu machen und für rein statistische Zwecke, benötigen wir noch "
        "diese Angaben von dir. Deine Daten werden vertraulich behandelt und nirgendwo weiter verwendet."
    ),
    "mandatory_profile_name_hint": "Vor- und Nachname",
    "mandatory_profile_name_required": "Bitte Namen angeben.",
    "mandatory_profile_country_label": "Land",
    "mandatory_profile_country_required": "Bitte Land wählen.",
    "mandatory_profile_pick_birthdate": "Geburtsdatum wählen",
    "mandatory_profile_birthdate_future": "Datum darf nicht in der Zukunft liegen.",
    "mandatory_profile_min_age": "Du musst mindestens 10 Jahre alt sein.",
    "mandatory_profile_birthdate_immutable": (
        "Das Geburtsdatum kann später nicht mehr geändert werden!"
    ),
    "history_save_log_title": "History-Speicher-Log",
    "history_save_log_empty": (
        "Noch keine Einträge. Musikerkennung an, Songs erkennen — dann erscheinen hier Speicherschritte."
    ),
    "history_save_log_empty_session": "Keine History-Logs in dieser Session.",
    "history_save_log_share_subject": "VibesBox History-Log",
    "log_copied_to_clipboard": "Log in Zwischenablage kopiert",
    "diagnostic_log_title": "Diagnose-Log",
    "diagnostic_log_description": (
        "Protokoll auf diesem Gerät (Fehler, SnackBars, Party-Events). Nicht an Server gesendet."
    ),
    "diagnostic_log_settings_subtitle": "Fehler & Ereignisse auf diesem Gerät protokollieren",
    "diagnostic_log_capture_active": "Aufzeichnung aktiv",
    "diagnostic_log_capture_on_hint": "Fehler, rote SnackBars, Party, History und mehr.",
    "diagnostic_log_capture_off_hint": "Pausiert — nur Anzeige alter Einträge",
    "diagnostic_log_empty": "Noch keine Einträge.\nApp nutzen — neue Ereignisse erscheinen hier.",
    "diagnostic_log_share_subject": "VibesBox Diagnose-Log",
    "diagnostic_log_clear_title": "Log leeren?",
    "diagnostic_log_clear_body": "Alle Einträge auf diesem Gerät werden gelöscht.",
    "copy": "Kopieren",
    "share": "Teilen",
    "clear": "Leeren",
    "filter_all": "Alle",
    "location_enable_gps_hint": "Bitte aktiviere GPS in den Einstellungen, um deinen Standort zu nutzen.",
    "location_tap_button_hint": "Tippe auf den Standort-Button, um dich auf der Karte zu zentrieren.",
    "location_fallback_banner": (
        "Dein Standort konnte nicht ermittelt werden. Du kannst die Position manuell auf der Karte setzen."
    ),
    "location_position_label": "Position",
    "location_resolving_address": "Adresse und Zeitzone werden ermittelt...",
    "location_search_label": "Location suchen",
    "location_search_hint": "z.B. Marsa Alam, Club XYZ, Wüste, Strand",
    "music_recognition_settings_title": "Musikerkennung-Einstellungen",
    "music_recognition_info_tooltip": "Informationen zur Musikerkennung",
    "shazam_autostart_label": "Musikerkennung automatisch starten, wenn Party aktiv",
    "shazam_autostart_description": (
        "Startet die Musikerkennung automatisch, sobald eine Party läuft."
    ),
    "vibesbox_status_title": "VibesBox Status",
    "status_enabled": "Aktiviert",
    "status_disabled": "Deaktiviert",
    "not_logged_in": "Nicht eingeloggt",
    "admin_lock_account_title": "Konto sperren (Login)?",
    "admin_unlock_account_title": "Konto entsperren?",
    "admin_lock_account_body": (
        "Soll „{name}“ für Login gesperrt werden? Das Konto kann sich dann nicht mehr anmelden."
    ),
    "admin_unlock_account_body": (
        "Soll „{name}“ wieder normal einloggen können?"
    ),
    "admin_account_locked_snackbar": "Konto gesperrt: {name}",
    "admin_account_unlocked_snackbar": "Konto entsperrt: {name}",
    "admin_lock_action": "Sperren",
    "admin_unlock_action": "Entsperren",
    "password_required": "Bitte Passwort eingeben.",
    "password_min_length_8": "Mindestens 8 Zeichen erforderlich.",
    "admin_otp_no_secret": "Kein Admin-Secret hinterlegt.",
    "admin_otp_invalid": "Code ungültig. Bitte erneut versuchen.",
    "admin_otp_check_failed": "Code-Prüfung fehlgeschlagen.",
    "admin_otp_required": "Authenticator-Code erforderlich",
    "admin_otp_verifying": "Verifiziere Admin-Zugriff...",
    "admin_no_permission": "Keine Admin-Berechtigung.",
    "notification_channel_new_wishes": "Neue Wünsche",
    "notification_channel_new_wishes_desc": "Benachrichtigungen für neue Wünsche",
    "error_loading_prefix": "Fehler beim Laden",
    "music_recognition_none_found": "Noch keine Songs erkannt",
    "device_android_label": "Android-Gerät",
    # AR missing keys (also ensure present everywhere)
    "admin_platform_totals_title": "Plattform-Gesamtzahlen",
    "admin_platform_totals_recount_hint": "Neu zählen",
    "admin_platform_totals_guests": "Gäste",
    "admin_platform_totals_djs_total": "DJs gesamt",
    "admin_platform_totals_djs_free": "DJs Free",
    "admin_platform_totals_djs_pro": "DJs Pro",
    "admin_platform_totals_djs_pro_life": "DJs Pro Life",
    "admin_platform_totals_parties_total": "Partys gesamt",
    "admin_platform_totals_parties_running": "Partys laufend",
    "main_hero_btn_party": "Zur Party",
}

EN: dict[str, str] = {
    "pro_promotion_banner_message": "VibesBox Pro for full control",
    "open_wishes_reorder_hint": (
        "Reordering: white line = drop position — also before first and after last."
    ),
    "mandatory_profile_title": "Complete your profile",
    "mandatory_profile_intro": (
        "To improve VibesBox and for purely statistical purposes, we still need a few details. "
        "Your data is treated confidentially and not used elsewhere."
    ),
    "mandatory_profile_name_hint": "First and last name",
    "mandatory_profile_name_required": "Please enter your name.",
    "mandatory_profile_country_label": "Country",
    "mandatory_profile_country_required": "Please select a country.",
    "mandatory_profile_pick_birthdate": "Select date of birth",
    "mandatory_profile_birthdate_future": "Date must not be in the future.",
    "mandatory_profile_min_age": "You must be at least 10 years old.",
    "mandatory_profile_birthdate_immutable": (
        "The date of birth cannot be changed later!"
    ),
    "history_save_log_title": "History save log",
    "history_save_log_empty": (
        "No entries yet. Turn on music recognition and detect songs — save steps appear here."
    ),
    "history_save_log_empty_session": "No history logs in this session.",
    "history_save_log_share_subject": "VibesBox history log",
    "log_copied_to_clipboard": "Log copied to clipboard",
    "diagnostic_log_title": "Diagnostic log",
    "diagnostic_log_description": (
        "Log on this device (errors, snackbars, party events). Not sent to the server."
    ),
    "diagnostic_log_settings_subtitle": "Log errors & events on this device",
    "diagnostic_log_capture_active": "Recording active",
    "diagnostic_log_capture_on_hint": "Errors, red snackbars, party, history and more.",
    "diagnostic_log_capture_off_hint": "Paused — only showing older entries",
    "diagnostic_log_empty": "No entries yet.\nUse the app — new events appear here.",
    "diagnostic_log_share_subject": "VibesBox diagnostic log",
    "diagnostic_log_clear_title": "Clear log?",
    "diagnostic_log_clear_body": "All entries on this device will be deleted.",
    "copy": "Copy",
    "share": "Share",
    "clear": "Clear",
    "filter_all": "All",
    "location_enable_gps_hint": "Please enable GPS in settings to use your location.",
    "location_tap_button_hint": "Tap the location button to center yourself on the map.",
    "location_fallback_banner": (
        "Your location could not be determined. You can set the position manually on the map."
    ),
    "location_position_label": "Position",
    "location_resolving_address": "Resolving address and time zone...",
    "location_search_label": "Search location",
    "location_search_hint": "e.g. Marsa Alam, Club XYZ, desert, beach",
    "music_recognition_settings_title": "Music recognition settings",
    "music_recognition_info_tooltip": "Music recognition information",
    "shazam_autostart_label": "Start music recognition automatically when a party is active",
    "shazam_autostart_description": (
        "Starts music recognition automatically as soon as a party is running."
    ),
    "vibesbox_status_title": "VibesBox status",
    "status_enabled": "Enabled",
    "status_disabled": "Disabled",
    "not_logged_in": "Not signed in",
    "admin_lock_account_title": "Lock account (login)?",
    "admin_unlock_account_title": "Unlock account?",
    "admin_lock_account_body": (
        'Lock “{name}” from logging in? The account will no longer be able to sign in.'
    ),
    "admin_unlock_account_body": (
        'Allow “{name}” to sign in normally again?'
    ),
    "admin_account_locked_snackbar": "Account locked: {name}",
    "admin_account_unlocked_snackbar": "Account unlocked: {name}",
    "admin_lock_action": "Lock",
    "admin_unlock_action": "Unlock",
    "password_required": "Please enter a password.",
    "password_min_length_8": "At least 8 characters required.",
    "admin_otp_no_secret": "No admin secret configured.",
    "admin_otp_invalid": "Invalid code. Please try again.",
    "admin_otp_check_failed": "Code verification failed.",
    "admin_otp_required": "Authenticator code required",
    "admin_otp_verifying": "Verifying admin access...",
    "admin_no_permission": "No admin permission.",
    "notification_channel_new_wishes": "New wishes",
    "notification_channel_new_wishes_desc": "Notifications for new wishes",
    "error_loading_prefix": "Error loading",
    "music_recognition_none_found": "No songs recognized yet",
    "device_android_label": "Android device",
    "admin_platform_totals_title": "Platform totals",
    "admin_platform_totals_recount_hint": "Recount",
    "admin_platform_totals_guests": "Guests",
    "admin_platform_totals_djs_total": "DJs total",
    "admin_platform_totals_djs_free": "DJs Free",
    "admin_platform_totals_djs_pro": "DJs Pro",
    "admin_platform_totals_djs_pro_life": "DJs Pro Life",
    "admin_platform_totals_parties_total": "Parties total",
    "admin_platform_totals_parties_running": "Parties running",
    "main_hero_btn_party": "Go to party",
}

# Non-EN/DE: use EN as base; override a few Romance/Germanic where easy
OVERRIDES: dict[str, dict[str, str]] = {
    "fr": {
        "pro_promotion_banner_message": "VibesBox Pro pour un contrôle total",
        "mandatory_profile_title": "Compléter le profil",
        "mandatory_profile_name_required": "Veuillez indiquer un nom.",
        "mandatory_profile_country_label": "Pays",
        "mandatory_profile_country_required": "Veuillez choisir un pays.",
        "copy": "Copier",
        "share": "Partager",
        "clear": "Effacer",
        "cancel_already": None,
        "diagnostic_log_title": "Journal de diagnostic",
        "not_logged_in": "Non connecté",
        "status_enabled": "Activé",
        "status_disabled": "Désactivé",
        "main_hero_btn_party": "Vers la soirée",
    },
    "es": {
        "pro_promotion_banner_message": "VibesBox Pro para control total",
        "mandatory_profile_title": "Completar perfil",
        "mandatory_profile_name_required": "Introduce tu nombre.",
        "mandatory_profile_country_label": "País",
        "mandatory_profile_country_required": "Selecciona un país.",
        "copy": "Copiar",
        "share": "Compartir",
        "clear": "Vaciar",
        "diagnostic_log_title": "Registro de diagnóstico",
        "not_logged_in": "No has iniciado sesión",
        "status_enabled": "Activado",
        "status_disabled": "Desactivado",
        "main_hero_btn_party": "Ir a la fiesta",
    },
    "it": {
        "pro_promotion_banner_message": "VibesBox Pro per il controllo completo",
        "mandatory_profile_title": "Completa il profilo",
        "mandatory_profile_country_label": "Paese",
        "copy": "Copia",
        "share": "Condividi",
        "clear": "Svuota",
        "diagnostic_log_title": "Log di diagnostica",
        "main_hero_btn_party": "Vai alla festa",
    },
    "nl": {
        "pro_promotion_banner_message": "VibesBox Pro voor volledige controle",
        "mandatory_profile_title": "Profiel voltooien",
        "mandatory_profile_country_label": "Land",
        "copy": "Kopiëren",
        "share": "Delen",
        "clear": "Wissen",
        "diagnostic_log_title": "Diagnose-log",
        "main_hero_btn_party": "Naar het feest",
    },
    "pt": {
        "pro_promotion_banner_message": "VibesBox Pro para controlo total",
        "mandatory_profile_title": "Completar perfil",
        "mandatory_profile_country_label": "País",
        "copy": "Copiar",
        "share": "Partilhar",
        "clear": "Limpar",
        "main_hero_btn_party": "Ir para a festa",
    },
    "pl": {
        "pro_promotion_banner_message": "VibesBox Pro dla pełnej kontroli",
        "mandatory_profile_title": "Uzupełnij profil",
        "mandatory_profile_country_label": "Kraj",
        "copy": "Kopiuj",
        "share": "Udostępnij",
        "clear": "Wyczyść",
        "main_hero_btn_party": "Do imprezy",
    },
    "ar": {
        "pro_promotion_banner_message": "VibesBox Pro للتحكم الكامل",
        "mandatory_profile_title": "أكمل ملفك الشخصي",
        "mandatory_profile_name_hint": "الاسم الأول والأخير",
        "mandatory_profile_name_required": "يرجى إدخال الاسم.",
        "mandatory_profile_country_label": "البلد",
        "mandatory_profile_country_required": "يرجى اختيار البلد.",
        "mandatory_profile_pick_birthdate": "اختر تاريخ الميلاد",
        "copy": "نسخ",
        "share": "مشاركة",
        "clear": "مسح",
        "main_hero_btn_party": "إلى الحفلة",
        "admin_platform_totals_title": "إجماليات المنصة",
        "admin_platform_totals_recount_hint": "إعادة العد",
        "admin_platform_totals_guests": "الضيوف",
        "admin_platform_totals_djs_total": "إجمالي دي جي",
        "admin_platform_totals_djs_free": "دي جي مجاني",
        "admin_platform_totals_djs_pro": "دي جي Pro",
        "admin_platform_totals_djs_pro_life": "دي جي Pro Life",
        "admin_platform_totals_parties_total": "إجمالي الحفلات",
        "admin_platform_totals_parties_running": "حفلات جارية",
    },
}


def load_arb(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def save_arb(path: Path, data: dict) -> None:
    # Keep tab-indent style like existing files
    lines = ["{"]
    items = list(data.items())
    for i, (k, v) in enumerate(items):
        comma = "," if i < len(items) - 1 else ""
        lines.append(f'\t{json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)}{comma}')
    lines.append("}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    added_total = 0
    for path in sorted(L10N.glob("app_*.arb")):
        lang = path.stem.replace("app_", "")
        data = load_arb(path)
        if lang == "de":
            src = DE
        elif lang == "en":
            src = EN
        else:
            src = dict(EN)
            src.update({k: v for k, v in OVERRIDES.get(lang, {}).items() if v is not None})
        n = 0
        for k, v in src.items():
            if k not in data or data.get(k) in (None, ""):
                # don't overwrite intentional empty main_intro_paragraph2 unless in our set with ""
                if k in data and data[k] == "" and k == "main_intro_paragraph2":
                    continue
                if k not in data:
                    data[k] = v
                    n += 1
                elif data.get(k) == "" and v:
                    data[k] = v
                    n += 1
            # Always fill AR missing keys even if somehow wrong
            if lang == "ar" and (
                k.startswith("admin_platform_totals") or k == "main_hero_btn_party"
            ):
                if k not in data or data.get(k) == DE.get(k):
                    data[k] = src[k]
                    n += 1
        # Force-insert any missing
        for k, v in src.items():
            if k not in data:
                data[k] = v
                n += 1
        if n:
            save_arb(path, data)
            added_total += n
            print(f"{lang}: +{n} keys")
        else:
            print(f"{lang}: ok")
    print(f"Done. inserts~={added_total}")


if __name__ == "__main__":
    main()
