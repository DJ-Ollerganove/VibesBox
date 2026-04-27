"""Entfernt/reduziert PII in debugLog-Ausgaben (UID, E-Mail, Namen in Strings)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "lib"


def sub_file(rel: str, patterns: list[tuple[str, str]]) -> None:
    p = LIB / rel
    t = p.read_text(encoding="utf-8")
    orig = t
    for a, b in patterns:
        t = re.sub(a, b, t)
    if t != orig:
        p.write_text(t, encoding="utf-8")
        print("updated", rel)


def main() -> None:
    sub_file(
        "l10n/locale_helper.dart",
        [
            (r"debug�� initializeAppLocale → \$code \(user=\$\{user\?\.uid[^)]*\)\)'\)",
 "debugLog('��� initializeAppLocale → $code')"),
            (
                r"debugLog\('��� Firestore users/\$\{user\.uid\}: language/selected_language = \$code'\)",
                "�� Firestore: Sprache gespeichert ($code)')",
            ),
        ],
    )

    sub_file(
        "main_main_page.dart",
        [
            (
                r"debug� MainPage: Cold-Start-Dienste für uid=\$\{user\.uid\}'\)",
                "� MainPage: Cold-Start-Dienste')",
            ),
        ],
    )

    sub_file(
        "pages/neue_party_page.dart",
        [
            (
                r"debugLog\('�� Lade Locations für User: \$\{user\.uid\} \(Email: \$\{user\.email\}\)'\)",
                "� Lade Locations für User')",
            ),
            (
                r"debug� Speichere Party - DJ UID: \$createdBy'\)",
                "debugLog('�� Speichere Party')",
            ),
            (
                r"debug� Permission Denied - DJ UID: \$createdBy'\)",
                "debugLog('�� Permission Denied (Party speichern)')",
            ),
        ],
    )

    sub_file(
        "pages/wishes_page.dart",
        [
            (
                r"debugLog\('��️ Verwende Fallback clientId: \$fallbackId'\)",
                "debugLog('��️ Verwende Fallback clientId')",
            ),
            (
                r"debug� _addWish: Verwende clientId: \$clientId'\)",
                "debugLog('�� _addWish: clientId gesetzt')",
            ),
        ],
    )

    sub_file(
        "party_verwaltung_page.dart",
        [
            (
                r"debugLog\('�� Löschung verweigert: User \$\{user\.uid\} ist nicht der Ersteller \(created_by: \$createdBy\)'\)",
                "� Löschung verweigert: nicht der Ersteller')",
            ),
            (
                r"debugLog\('�� Party \$partyId erfolgreich gelöscht von User \$\{user\.uid\}'\)",
                "debugLog('�� Party gelöscht')",
            ),
        ],
    )

    sub_file(
        "pages/history/history_dj.dart",
        [
            (
                r"debugLog\('ANALYSE \[History-Fetch\]: Suche mit party_id = \$partyId und djId = \$\{user\.uid\}'\)",
                "debugLog('ANALYSE [History-Fetch]: Suche mit party_id')",
            ),
            (
                r"debugLog\('ANALYSE \[Auth\]: Eingeloggte UID ist = \$\{FirebaseAuth\.instance\.currentUser\?\.uid\}'\)",
                "debugLog('ANALYSE [Auth]: currentUser gesetzt')",
            ),
            (
                r"debugLog\('\[DEBUG-UI\] Lade music_history Sessions für UID: \$\{user\.uid\}, Party-ID: \$partyId'\)",
                "debugLog('[DEBUG-UI] Lade music_history Sessions')",
            ),
        ],
    )

    sub_file(
        "pages/benutzer_verwaltung_page.dart",
        [
            (
                r"debugLog\('�� Aktualisiere Rolle für User \$userId'\)",
                "debugLog('�� Aktualisiere Rolle')",
            ),
            (
                r"debugLog\('   Aktueller User: \$\{user\.email\}'\)",
                "debugLog('   Rolle aktualisieren (Admin)')",
            ),
        ],
    )

    sub_file(
        "pages/gesperrt_page.dart",
        [
            (r"debugLog\('   client_id: \$clientId'\)", "debugLog('   client_id: (redacted)')"),
            (r"debugLog\('   name: \$name'\)", "debugLog('   name: (redacted)')"),
        ],
    )

    sub_file(
        "widgets/wish_card.dart",
        [
            (
                r"debugLog\('�� ONE-CLICK: Direkte Sperre für \$name \(clientId: \$clientId, partyId: \$partyId\)'\)",
                "debugLog('�� ONE-CLICK: Direkte Sperre')",
            ),
        ],
    )

    sub_file(
        "services/statistics_service.dart",
        [
            (r"debugLog\('�� StatisticsService: User UID: \$\{user\.uid\}'\)", ""),
            (r"debugLog\('�� StatisticsService: User Email: \$\{user\.email\}'\)", ""),
        ],
    )

    sub_file(
        "services/active_party_service.dart",
        [
            (
                r"debugLog\('\[ACTIVE-PARTY-SERVICE\] Initialisiere Service für UID: \$\{user\.uid\}'\)",
                "debugLog('[ACTIVE-PARTY-SERVICE] Initialisiere Service')",
            ),
        ],
    )

    sub_file(
        "config/app_config.dart",
        [
            (
                r'debugLog\(\'��️ AppConfig: Oder in der Firebase Console nach einem User mit E-Mail "\$adminEmail" suchen, der Partys erstellt hat\.\'\)',
                "debugLog('��️ AppConfig: Oder in der Firebase Console nach dem Admin-Account suchen.')",
            ),
        ],
    )

    # history_provider: mehrzeilige / uid-haltige Debug-Zeilen
    hp = LIB / "services/history_provider.dart"
    ht = hp.read_text(encoding="utf-8")
    ht = re.sub(
        r"debugLog\('�� HistoryProvider: ABBRUCH – Kein eingeloggter User \(uid: \$\{user\?\.uid\}\)[^']*'\)",
        "debugLog('�� HistoryProvider: ABBRUCH – Kein eingeloggter User')",
        ht,
    )
    ht = re.sub(
        r"debugLog\('   → Debug: users/\$\{user\.uid\}\.role_id = \$roleId[^']*'\)",
        "debugLog('   → Debug: role_id aus users-Doc')",
        ht,
    )
    ht = re.sub(
        r"debugLog\('   → Regel prüft: request\.auth\.uid == session\.djId\. Aktuell: uid=\$\{user\.uid\}'\)",
        "debugLog('   → Regel prüft: request.auth.uid == session.djId')",
        ht,
    )
    hp.write_text(ht, encoding="utf-8")
    print("updated history_provider.dart")

    print("done.")


if __name__ == "__main__":
    main()
