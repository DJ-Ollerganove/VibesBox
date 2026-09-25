#!/usr/bin/env python3
"""Fehlende Party-Wizard-l10n-Keys in alle ARB-Dateien (DE/EN + party_saved_locations_radio überall)."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N = ROOT / "l10n"

PATCHES: dict[str, dict[str, str]] = {
    "de": {
        "party_saved_locations_radio": "Gespeicherte Orte",
        "party_floor_mode_none": "Keinen Floor angeben",
        "party_floor_mode_select": "Floor wählen",
        "party_dj_fallback": "DJ",
        "party_public_location_badge": "öffentlich",
        "party_venue_overlap_dialog_title": "Überschneidung an diesem Ort",
        "party_venue_overlap_dialog_intro": "Im gewählten Zeitfenster läuft bereits:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Möchtest du auf einem separaten Floor teilnehmen?",
        "party_venue_overlap_decline_hint": "Bitte Start-/Endzeit ändern oder einen anderen Ort wählen.",
        "party_public_location_matched_title": "Bekannter öffentlicher Ort",
        "party_public_location_matched_own_title": "Dein gespeicherter Ort",
        "party_public_location_matched_body": "Für diesen Ort gilt der gespeicherte Fest-Party-Code.",
    },
    "en": {
        "party_saved_locations_radio": "Saved locations",
        "party_floor_mode_none": "No floor specified",
        "party_floor_mode_select": "Choose a floor",
        "party_dj_fallback": "DJ",
        "party_public_location_badge": "public",
        "party_venue_overlap_dialog_title": "Overlap at this venue",
        "party_venue_overlap_dialog_intro": "During the selected time slot there is already:",
        "party_venue_overlap_party_line": "{partyName} ({djName}): {start} – {end}",
        "party_venue_overlap_join_floor_question": "Do you want to join on a separate floor?",
        "party_venue_overlap_decline_hint": "Please change the start/end time or choose another venue.",
        "party_public_location_matched_title": "Known public venue",
        "party_public_location_matched_own_title": "Your saved venue",
        "party_public_location_matched_body": "The saved fixed party code applies for this venue.",
    },
    "fr": {"party_saved_locations_radio": "Lieux enregistrés"},
    "es": {"party_saved_locations_radio": "Ubicaciones guardadas"},
    "it": {"party_saved_locations_radio": "Luoghi salvati"},
    "pt": {"party_saved_locations_radio": "Locais guardados"},
    "nl": {"party_saved_locations_radio": "Opgeslagen locaties"},
    "pl": {"party_saved_locations_radio": "Zapisane lokalizacje"},
    "cs": {"party_saved_locations_radio": "Uložená místa"},
    "el": {"party_saved_locations_radio": "Αποθηκευμένες τοποθεσίες"},
    "hi": {"party_saved_locations_radio": "सहेजे गए स्थान"},
    "vi": {"party_saved_locations_radio": "Địa điểm đã lưu"},
    "sq": {"party_saved_locations_radio": "Vendet e ruajtura"},
    "ja": {"party_saved_locations_radio": "保存済みの場所"},
    "ar": {"party_saved_locations_radio": "المواقع المحفوظة"},
    "ru": {"party_saved_locations_radio": "Сохранённые места"},
    "uk": {"party_saved_locations_radio": "Збережені місця"},
    "tr": {"party_saved_locations_radio": "Kayıtlı mekânlar"},
    "zh": {"party_saved_locations_radio": "已保存的地点"},
    "th": {"party_saved_locations_radio": "ตำแหน่งที่บันทึกไว้"},
}


def main() -> None:
    for arb_path in sorted(L10N.glob("app_*.arb")):
        lang = arb_path.stem.replace("app_", "")
        patch = PATCHES.get(lang)
        if not patch:
            continue
        data = json.loads(arb_path.read_text(encoding="utf-8"))
        changed = False
        for key, value in patch.items():
            if data.get(key) != value:
                data[key] = value
                changed = True
        if changed:
            arb_path.write_text(
                json.dumps(data, ensure_ascii=False, indent="\t") + "\n",
                encoding="utf-8",
            )
            print(f"✓ {arb_path.name}: {len(patch)} keys")


if __name__ == "__main__":
    main()
