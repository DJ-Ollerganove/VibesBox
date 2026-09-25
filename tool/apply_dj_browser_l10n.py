#!/usr/bin/env python3
"""DJ Browser-Zugang: App-ARB + PWA-Locale."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"
PWA_LOCALES = ROOT / "public" / "vb" / "babel" / "locales"
DJ_L10N_OUT = ROOT / "public" / "dj" / "l10n-data.js"
DJ_L10N_BUNDLE = ROOT / "public" / "dj" / "dj-l10n.js"
LIB_L10N = ROOT / "lib" / "l10n"

APP_KEYS = [
    "dj_browser_open_tooltip",
    "dj_browser_dialog_title",
    "dj_browser_dialog_body",
    "dj_browser_dialog_countdown",
    "dj_browser_creating_code",
    "dj_browser_code_copied",
    "dj_browser_error_create",
    "dj_browser_free_locked_title",
    "dj_browser_free_locked_description",
]

PWA_KEYS = [
    "dj_browser_login_title",
    "dj_browser_login_subtitle",
    "dj_browser_login_hint",
    "dj_browser_login_code_label",
    "dj_browser_party_ended",
    "dj_browser_session_replaced",
    "dj_browser_code_invalid",
    "dj_browser_error_rate_limit",
    "dj_browser_error_network",
    "dj_browser_tab_vorab",
    "dj_browser_tab_offen",
    "dj_browser_tab_gespielt",
    "dj_browser_tab_abgelehnt",
    "dj_browser_action_play",
    "dj_browser_action_reject",
    "dj_browser_action_delete",
    "dj_browser_action_publish",
    "dj_browser_pre_wishes_paused",
    "dj_browser_no_wishes",
    "dj_browser_loading",
    "dj_browser_confirm_delete",
    "party_end_label",
    "party_time_at",
    "party_running_still",
    "saved_tracks_bookmark_tooltip",
    "saved_tracks_remove_tooltip",
    "saved_tracks_added_snackbar",
    "saved_tracks_removed_snackbar",
    "saved_tracks_already_saved_snackbar",
    "saved_tracks_save_error",
    "favorite_status_update_error",
    "free_feature_favorites_title",
    "favorites_page_title",
    "back",
    "requested_by",
    "no_name",
    "greeting",
    "wish_anchor_tooltip",
    "wish_anchor_remove_tooltip",
    "wish_anchor_limit_snackbar",
    "wish_anchor_update_error",
    "drag_to_reorder_hint",
    "dj_browser_sort_locked",
    "dj_browser_reorder_save_error",
]

TRANSLATIONS = {
    "de": {
        "dj_browser_open_tooltip": "Im Browser öffnen",
        "dj_browser_dialog_title": "Browser-Zugang",
        "dj_browser_dialog_body": "Gib diesen Code auf www.vibesbox.app/dj ein. Er ist 10 Minuten gültig und nur einmal verwendbar. Schließen macht den Code sofort ungültig.",
        "dj_browser_dialog_countdown": "Gültig noch {time}",
        "dj_browser_creating_code": "Code wird erzeugt…",
        "dj_browser_code_copied": "Code kopiert",
        "dj_browser_error_create": "Code konnte nicht erstellt werden.",
        "dj_browser_free_locked_title": "VibesBox Pro",
        "dj_browser_free_locked_description": "Der Browser-Zugang ist nur mit VibesBox Pro verfügbar.",
        "dj_browser_login_title": "VibesBox",
        "dj_browser_login_subtitle": "DJ-Browser",
        "dj_browser_login_hint": "Erzeuge in der VibesBox-App einen 6-stelligen Code (laufende Party) und gib ihn hier ein.",
        "dj_browser_login_code_label": "6-stelliger Code",
        "dj_browser_party_ended": "Party zu Ende",
        "dj_browser_session_replaced": "Du wurdest abgemeldet — ein anderer Browser ist verbunden.",
        "dj_browser_code_invalid": "Code ungültig oder abgelaufen.",
        "dj_browser_error_rate_limit": "Zu viele Versuche. Bitte kurz warten.",
        "dj_browser_error_network": "Verbindung fehlgeschlagen. Bitte erneut versuchen.",
        "dj_browser_tab_vorab": "Vorab",
        "dj_browser_tab_offen": "Offen",
        "dj_browser_tab_gespielt": "Gespielt",
        "dj_browser_tab_abgelehnt": "Abgelehnt",
        "dj_browser_action_play": "Gespielt",
        "dj_browser_action_reject": "Ablehnen",
        "dj_browser_action_delete": "Löschen",
        "dj_browser_action_publish": "Freigeben",
        "dj_browser_pre_wishes_paused": "VORABWÜNSCHE PAUSIERT",
        "dj_browser_no_wishes": "Keine Wünsche",
        "dj_browser_loading": "Laden…",
        "dj_browser_confirm_delete": "Wunsch wirklich löschen?",
        "dj_browser_sort_locked": "Sortieren ist auf einem anderen Gerät aktiv.",
        "dj_browser_reorder_save_error": "Reihenfolge konnte nicht gespeichert werden.",
    },
    "en": {
        "dj_browser_open_tooltip": "Open in browser",
        "dj_browser_dialog_title": "Browser access",
        "dj_browser_dialog_body": "Enter this code at www.vibesbox.app/dj. It is valid for 10 minutes and can only be used once. Closing invalidates the code immediately.",
        "dj_browser_dialog_countdown": "Valid for {time}",
        "dj_browser_creating_code": "Generating code…",
        "dj_browser_code_copied": "Code copied",
        "dj_browser_error_create": "Could not create code.",
        "dj_browser_free_locked_title": "VibesBox Pro",
        "dj_browser_free_locked_description": "Browser access is available with VibesBox Pro only.",
        "dj_browser_login_title": "VibesBox",
        "dj_browser_login_subtitle": "DJ browser",
        "dj_browser_login_hint": "Generate a 6-digit code in the VibesBox app (active party) and enter it here.",
        "dj_browser_login_code_label": "6-digit code",
        "dj_browser_party_ended": "Party ended",
        "dj_browser_session_replaced": "You were signed out — another browser is connected.",
        "dj_browser_code_invalid": "Invalid or expired code.",
        "dj_browser_error_rate_limit": "Too many attempts. Please wait a moment.",
        "dj_browser_error_network": "Connection failed. Please try again.",
        "dj_browser_tab_vorab": "Pre-wishes",
        "dj_browser_tab_offen": "Open",
        "dj_browser_tab_gespielt": "Played",
        "dj_browser_tab_abgelehnt": "Rejected",
        "dj_browser_action_play": "Played",
        "dj_browser_action_reject": "Reject",
        "dj_browser_action_delete": "Delete",
        "dj_browser_action_publish": "Publish",
        "dj_browser_pre_wishes_paused": "PRE-WISHES PAUSED",
        "dj_browser_no_wishes": "No wishes",
        "dj_browser_loading": "Loading…",
        "dj_browser_confirm_delete": "Delete this wish?",
        "dj_browser_sort_locked": "Sorting is active on another device.",
        "dj_browser_reorder_save_error": "Could not save the new order.",
    },
}


def load_arb(locale: str) -> dict:
    path = L10N / f"app_{locale}.arb"
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def fill_locale(locale: str, en: dict) -> dict:
    base = TRANSLATIONS.get(locale, en)
    out = dict(en)
    out.update(base)
    return out


def patch_arb(locale: str, tr: dict, en: dict) -> None:
    arb_path = L10N / f"app_{locale}.arb"
    if not arb_path.exists():
        return
    data = json.loads(arb_path.read_text(encoding="utf-8"))
    for key in APP_KEYS:
        data[key] = tr.get(key, en[key])
    data["@dj_browser_dialog_countdown"] = {
        "placeholders": {"time": {"type": "String"}}
    }
    arb_path.write_text(
        json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
        encoding="utf-8",
    )
    print(f"ARB OK {arb_path.name}")


def patch_pwa_locale(locale: str, tr: dict, en: dict) -> None:
    path = PWA_LOCALES / f"{locale}.json"
    if not path.exists():
        return
    data = json.loads(path.read_text(encoding="utf-8"))
    for key in PWA_KEYS:
        data[key] = tr.get(key, en.get(key, key))
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"PWA OK {path.name}")


def write_dj_l10n_bundle(all_locales: dict) -> None:
    DJ_L10N_BUNDLE.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(all_locales, ensure_ascii=False, indent=2)
    de = all_locales.get("de") or all_locales.get("en") or {}
    en = all_locales.get("en") or {}
    fallback_de = json.dumps(de, ensure_ascii=False)
    fallback_en = json.dumps(en, ensure_ascii=False)
    DJ_L10N_BUNDLE.write_text(
        f"""window.DJ_BROWSER_L10N = {payload};
(function () {{
  var FALLBACK_DE = {fallback_de};
  var FALLBACK_EN = {fallback_en};
  var LOGIN_IDS = {{
    'login-subtitle': 'dj_browser_login_subtitle',
    'login-title': 'dj_browser_login_title',
    'login-hint': 'dj_browser_login_hint',
    'login-code-label': 'dj_browser_login_code_label',
    'login-loading-text': 'dj_browser_loading',
  }};

  function detectLocale() {{
    if (typeof window.getEffectiveLangForMenu === 'function') {{
      return window.getEffectiveLangForMenu();
    }}
    var L = window.DJ_BROWSER_L10N || {{}};
    var raw = (navigator.language || 'de').slice(0, 2).toLowerCase();
    if (L[raw]) return raw;
    if (L.de) return 'de';
    return 'en';
  }}

  function translate(key, locale) {{
    var L = window.DJ_BROWSER_L10N || {{}};
    var loc = locale || window.djBrowserLocale || 'de';
    var pack = L[loc] || {{}};
    if (pack[key]) return pack[key];
    if (loc === 'de' && FALLBACK_DE[key]) return FALLBACK_DE[key];
    if (L.en && L.en[key]) return L.en[key];
    if (loc !== 'de' && FALLBACK_DE[key]) return FALLBACK_DE[key];
    if (FALLBACK_EN[key]) return FALLBACK_EN[key];
    return FALLBACK_DE[key] || FALLBACK_EN[key] || '';
  }}

  function applyLoginLabels(locale) {{
    var loc = locale || window.djBrowserLocale || detectLocale();
    Object.keys(LOGIN_IDS).forEach(function (id) {{
      var el = document.getElementById(id);
      if (el) el.textContent = translate(LOGIN_IDS[id], loc);
    }});
    document.documentElement.lang = loc;
    document.title = translate('dj_browser_login_title', loc) + ' DJ';
  }}

  window.djBrowserSetLocale = function (code) {{
    window.djBrowserLocale = code;
    applyLoginLabels(code);
  }};
  window.djBrowserLocale = detectLocale();
  window.djBrowserT = function (key) {{
    return translate(key, window.djBrowserLocale);
  }};
  window.djBrowserApplyLoginL10n = applyLoginLabels;
  applyLoginLabels(window.djBrowserLocale);
}})();
""",
        encoding="utf-8",
    )
    print(f"OK {DJ_L10N_BUNDLE.relative_to(ROOT)}")


def write_dj_l10n_js(all_locales: dict) -> None:
    DJ_L10N_OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(all_locales, ensure_ascii=False, indent=2)
    DJ_L10N_OUT.write_text(
        f"window.DJ_BROWSER_L10N = {payload};\n",
        encoding="utf-8",
    )
    print(f"OK {DJ_L10N_OUT.relative_to(ROOT)}")


def patch_app_localizations_base() -> None:
    path = LIB_L10N / "app_localizations.dart"
    text = path.read_text(encoding="utf-8")
    marker = "  String get party_pre_wish_limit_label => translate('party_pre_wish_limit_label');"
    insert = """  String get dj_browser_open_tooltip => translate('dj_browser_open_tooltip');
  String get dj_browser_dialog_title => translate('dj_browser_dialog_title');
  String get dj_browser_dialog_body => translate('dj_browser_dialog_body');
  String dj_browser_dialog_countdown(String time) =>
      translate('dj_browser_dialog_countdown').replaceAll('{time}', time);
  String get dj_browser_code_copied => translate('dj_browser_code_copied');
  String get dj_browser_error_create => translate('dj_browser_error_create');
  String get dj_browser_free_locked_title =>
      translate('dj_browser_free_locked_title');
  String get dj_browser_free_locked_description =>
      translate('dj_browser_free_locked_description');
"""
    if "dj_browser_open_tooltip" not in text and marker in text:
        text = text.replace(marker, insert + marker)
        path.write_text(text, encoding="utf-8")
        print("OK app_localizations.dart")


def patch_locale_dart(locale: str, tr: dict, en: dict) -> None:
    path = LIB_L10N / f"app_localizations_{locale}.dart"
    if not path.exists():
        return
    text = path.read_text(encoding="utf-8")
    if "dj_browser_open_tooltip" in text:
        return
    lines = []
    for key in APP_KEYS:
        val = tr.get(key, en[key]).replace("'", "\\'")
        if key == "dj_browser_dialog_countdown":
            val = val.replace("{time}", "{time}")
        lines.append(f"    '{key}': '{val}',")
    block = "\n".join(lines) + "\n"
    text = text.replace("  };\n}\n", block + "  };\n}\n")
    path.write_text(text, encoding="utf-8")
    print(f"DART OK {path.name}")


def locale_strings(locale: str, en: dict) -> dict:
    out = dict(en)
    out.update(load_arb(locale))
    if locale in TRANSLATIONS:
        out.update(TRANSLATIONS[locale])
    return out


def main() -> None:
    en = locale_strings("en", {**load_arb("en"), **TRANSLATIONS["en"]})
    de_arb = load_arb("de")
    en_arb = load_arb("en")
    all_pwa = {}
    patch_app_localizations_base()
    for arb_path in sorted(L10N.glob("app_*.arb")):
        locale = arb_path.stem.replace("app_", "")
        tr = locale_strings(locale, en)
        patch_arb(locale, tr, en)
        patch_pwa_locale(locale, tr, en)
        patch_locale_dart(locale, tr, en)
        all_pwa[locale] = {k: tr.get(k, en.get(k, k)) for k in PWA_KEYS}
    all_pwa["en"] = {k: en[k] for k in PWA_KEYS}
    write_dj_l10n_js(all_pwa)
    write_dj_l10n_bundle(all_pwa)


if __name__ == "__main__":
    main()
