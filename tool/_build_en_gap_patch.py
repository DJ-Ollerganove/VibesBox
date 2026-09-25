#!/usr/bin/env python3
"""Build tool/_en_gap_patch_data.py from translation blocks + gap detection."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "tool" / "_en_gap_patch_data.py"

ALL_KEYS = [
    "party_floor_add_dialog_hint", "party_floor_add_dialog_title", "party_floor_add_new",
    "party_floor_default_option", "party_floor_label", "party_floor_mode_none",
    "party_floor_mode_select", "party_floor_name_required", "party_floor_occupied_hint",
    "party_floor_select_hint", "party_floor_swap_accept", "party_floor_swap_accepted",
    "party_floor_swap_after_save_hint", "party_floor_swap_dialog_body",
    "party_floor_swap_dialog_title", "party_floor_swap_dialog_your_floor",
    "party_floor_swap_failed", "party_floor_swap_incoming_body",
    "party_floor_swap_incoming_title", "party_floor_swap_reject", "party_floor_swap_request",
    "party_floor_swap_sent", "party_public_location_coords_required",
    "guest_floor_ended_redirect_message", "guest_floor_main_area", "guest_floor_picker_choose",
    "guest_floor_picker_title", "guest_floor_switch_button", "venue_bookmarks_title",
    "venue_bookmarks_use", "party_wizard_step_number_only",
    "social_hint_account", "social_hint_facebook", "social_hint_instagram",
    "social_hint_soundcloud", "social_hint_spotify", "social_hint_tiktok",
    "social_hint_website", "social_hint_whatsapp", "social_hint_youtube",
    "referral_redeem_body_b2b", "referral_redeem_title_b2b", "referral_code_hint_b2b",
    "referral_code_length_b2b", "referral_code_saved_b2b", "paywall_start_trial_button_b2b",
    "paywall_trial_b2b_hint", "paywall_trial_confirm_title_b2b",
    "paywall_trial_confirm_message_b2b", "paywall_trial_confirm_message_no_b2b",
    "trial_activated_snackbar_b2b",
    "recognition_lock_takeover_button", "invalid_whatsapp_phone", "labelDjId",
    "interval_seconds_short", "spotify_admin_slider_minutes", "audio_format_seconds_only",
    "status_running", "update_local_label", "announcement_progress_original",
    "main_social_title", "main_social_intro", "main_feature_auto_body", "main_feature_dj_title",
    "main_features_title", "main_philosophy_title", "main_feature_guest_body",
    "main_feature_guest_title", "main_features_accent", "main_feature_dj_body",
    "main_feature_auto_title", "main_philosophy_body", "profile_email",
    "dj_home_stats_row_total", "no", "permanent", "dj_wish_tab_rejected", "contact_label",
    "admin_device_platform", "party_pdf_poster_a4", "start_label_new", "party_begin",
    "main_hero_title", "main_hero_btn_code", "main_hero_tagline", "main_intro_title",
    "label_role", "party_delete_confirm_anyway", "admin_role_label", "admin_user_section_data",
    "paywall_tip_badge", "live_party", "admin_start_view_saved", "snackbar_error_details",
    "error", "party_error", "error_with_message", "contact_error_title", "history_error_prefix",
    "update_save_error", "todo_stream_error", "error_updating", "contact", "party_minute",
    "connectionStable", "announcement_field_message_label", "history_page", "party_type_public",
    "label_date", "pre_wishes_pause", "label_message", "settings_grace_period_minutes",
    "dj_quickstart_h1_notifications", "party_public_location_badge", "party_minutes",
    "contact_message_label", "settings_section_notifications", "login_password_label",
    "change_password_short", "password_strength_medium", "later_button", "dj_wish_tab_open",
    "admin_user_shazam_interval_s", "open", "open_songs_label", "was_blocked", "latencyLabel",
    "databaseLabel", "period_week_singular", "referral_redeem_action", "email",
    "profile_alternative_email_dialog_email", "contact_email_label", "pdf_checkbox_email",
]

LOCALES = ["ar", "cs", "el", "es", "fr", "hi", "it", "ja", "nl", "pl", "pt", "ru", "sq", "th", "tr", "uk", "vi", "zh"]


def load_arb(path: Path) -> dict[str, str]:
    content = path.read_text(encoding="utf-8")
    data: dict[str, str] = {}
    for m in re.finditer(r'"([^"@][^"]*)"\s*:\s*"((?:[^"\\]|\\.)*)"', content):
        data[m.group(1)] = m.group(2)
    return data


def gaps_for_locale(en: dict[str, str], loc: str) -> set[str]:
    loc_data = load_arb(ROOT / "l10n" / f"app_{loc}.arb")
    return {k for k in ALL_KEYS if en.get(k) and loc_data.get(k) == en.get(k)}


# --- translation blocks (imported from generated data) ---
exec((ROOT / "tool" / "_en_gap_patch_translations.py").read_text(encoding="utf-8"), globals())

# FULL expected from _en_gap_patch_translations.py
FULL: dict[str, dict[str, str]] = {}
for loc in LOCALES:
    merged: dict[str, str] = {}
    for block in (FLOOR, SOCIAL, B2B, RECOGNITION, MAIN, EXTRA):
        if loc in block:
            merged.update(block[loc])
    FULL[loc] = merged

en = load_arb(ROOT / "l10n" / "app_en.arb")
PATCH: dict[str, dict[str, str]] = {}
for loc in LOCALES:
    gap_keys = gaps_for_locale(en, loc)
    PATCH[loc] = {k: FULL[loc][k] for k in sorted(gap_keys) if k in FULL[loc]}

lines = ["PATCH = {"]
for loc in LOCALES:
    lines.append(f'    "{loc}": {{')
    for k, v in sorted(PATCH[loc].items()):
        lines.append(f'        {k!r}: {v!r},')
    lines.append("    },")
lines.append("}")
lines.append("")
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"Wrote {OUT} ({sum(len(v) for v in PATCH.values())} entries)")
