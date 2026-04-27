# -*- coding: utf-8 -*-
import re
from pathlib import Path

p = Path(__file__).resolve().parents[1] / "lib/services/user_service.dart"
t = p.read_text(encoding="utf-8")
t = t.replace(
    'authStateChanges (distinct UID) – user=${user?.uid ?? "null"}',
    "authStateChanges (distinct UID)",
)
t = t.replace(
    "gleiche UID, Doc-Stream bleibt aktiv (${user.uid})",
    "gleiche UID, Doc-Stream bleibt aktiv",
)
t = t.replace(
    "starte Firestore-Snapshot für uid=${user.uid}",
    "starte Firestore-Snapshot",
)
t = t.replace(
    "currentUser gesetzt für ${user.uid} (exists=${doc.exists})",
    "currentUser gesetzt (exists=${doc.exists})",
)
t = t.replace(
    "User-Dokument: users/${user.uid}, Feld: admin, Wert: ${userModel?.admin == true}",
    "User-Dokument: admin-Feld = ${userModel?.admin == true}",
)
t = re.sub(
    r"Snapshot-Fehler users/\$\{user\.uid\}:",
    "Snapshot-Fehler users:",
    t,
)
t = re.sub(
    r"Permission denied auf users/\$\{user\.uid\}",
    "Permission denied auf users-Doc",
    t,
)
t = t.replace(
    'forceRefresh() – currentAuth=${user?.uid ?? "null"}',
    "forceRefresh()",
)
t = t.replace(
    "forceRefresh – starte Snapshot-Listener für uid=${user.uid}",
    "forceRefresh – starte Snapshot-Listener",
)
t = t.replace(
    "forceRefresh Snapshot-Fehler users/${user.uid}:",
    "forceRefresh Snapshot-Fehler:",
)
t = t.replace(
    "Permission denied bei forceRefresh users/${user.uid}.",
    "Permission denied bei forceRefresh.",
)
t = t.replace(
    "neuer Snapshot-Listener für UID ${user.uid}",
    "neuer Snapshot-Listener aktiv",
)
p.write_text(t, encoding="utf-8")
print("user_service logs ok")
