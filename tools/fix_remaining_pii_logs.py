# -*- coding: utf-8 -*-
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "lib"


def subf(rel: str, *patterns: tuple[str, str]) -> None:
    p = root / rel
    t = p.read_text(encoding="utf-8")
    for pat, rep in patterns:
        t = re.sub(pat, rep, t)
    p.write_text(t, encoding="utf-8")
    print("ok", rel)


subf(
    "widgets/wish_card.dart",
    (
        r"Direkte Sperre für \$name \(clientId: \$clientId, partyId: \$partyId\)",
        "Direkte Sperre (ONE-CLICK)",
    ),
)

subf(
    "utils/find_admin_dj_id_helper.dart",
    (
        r"debugLog\('   → User \"\$\{displayName \?\? userId\}\": UID = \$userId, role_id = \$roleId'\);",
        "debugLog('   → Admin-Kandidat gefunden (role_id)');",
    ),
)

subf(
    "services/statistics_service.dart",
    (
        r"\n\s*debugLog\('.*StatisticsService: User UID: \$\{user\.uid\}'\);",
        "",
    ),
    (
        r"\n\s*debugLog\('.*StatisticsService: User Email: \$\{user\.email\}'\);",
        "",
    ),
)

subf(
    "services/global_announcement_popup_service.dart",
    (
        r"für User: \$userId",
        "gestartet",
    ),
)

subf(
    "services/active_party_service.dart",
    (
        r"für UID: \$\{user\.uid\}",
        "",
    ),
)

subf(
    "party_verwaltung_page.dart",
    (
        r"User \$\{user\.uid\} ist nicht der Ersteller \(created_by: \$createdBy\)",
        "nicht der Ersteller",
    ),
    (
        r"von User \$\{user\.uid\}",
        "",
    ),
)

subf(
    "pages/neue_party_page.dart",
    (
        r"\$\{user\.uid\} \(Email: \$\{user\.email\}\)",
        "…",
    ),
    (
        r"DJ UID: \$createdBy",
        "DJ",
    ),
)

subf(
    "pages/history/history_dj.dart",
    (
        r"und djId = \$\{user\.uid\}",
        "",
    ),
    (
        r"Eingeloggte UID ist = \$\{FirebaseAuth\.instance\.currentUser\?\.uid\}",
        "eingeloggt",
    ),
    (
        r"für UID: \$\{user\.uid\}, Party-ID: \$partyId",
        "",
    ),
)

subf(
    "pages/benutzer_verwaltung_page.dart",
    (
        r"für User \$userId",
        "",
    ),
    (
        r"Aktueller User: \$\{user\.email\}",
        "Rolle wird aktualisiert",
    ),
)

subf(
    "config/app_config.dart",
    (
        r"gefunden: \$userId",
        "gefunden",
    ),
)

subf(
    "services/history_provider.dart",
    (
        r"\(uid: \$\{user\?\.uid\}\)\. Firestore blockiert",
        "Firestore blockiert",
    ),
    (
        r"Aktuell: uid=\$\{user\.uid\}",
        "Auth/Session-Abgleich",
    ),
    (
        r"users/\$\{user\.uid\}\.role_id = \$roleId \(Rules nutzen nur auth\.uid \+ djId\)",
        "users.role_id (Rules: auth.uid + djId)",
    ),
)

for backup in ("offen_page_backup_restore.dart", "offen_page_backup.dart"):
    subf(
        backup,
        (
            r"userId=\$userId, clientId=\$clientId, name=\$name, wishId=\$wishId",
            "…",
        ),
        (
            r"mit user_id: \$userId, party_id: \$partyId",
            "(user_id + party_id)",
        ),
        (
            r"finalClientId: \$finalClientId, userId: \$userId, partyId: \$partyId",
            "fehlende Kaskaden-IDs",
        ),
    )

subf(
    "pages/wishes_page.dart",
    (
        r"Fallback clientId: \$fallbackId",
        "Fallback clientId",
    ),
    (
        r"Verwende clientId: \$clientId",
        "clientId gesetzt",
    ),
)

subf(
    "pages/gesperrt_page.dart",
    (
        r"client_id: \$clientId",
        "client_id: (redacted)",
    ),
    (
        r"name: \$name",
        "name: (redacted)",
    ),
)

subf(
    "utils/debug_users_doc_keys.dart",
    (
        r"users/\$uid",
        "users/(uid)",
    ),
    (
        r"users/\$\{uid\}",
        "users/(uid)",
    ),
)

print("fix_remaining_pii_logs done")
