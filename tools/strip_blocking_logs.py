# -*- coding: utf-8 -*-
import re
from pathlib import Path

p = Path(__file__).resolve().parents[1] / "lib/services/user_blocking_service.dart"
lines = p.read_text(encoding="utf-8").splitlines()
out: list[str] = []
i = 0
while i < len(lines):
    line = lines[i]
    if line.strip() == "]) async {" and i + 1 < len(lines) and "\u2550" in lines[i + 1]:
        out.append(line)
        i += 1
        out.append("    debugLog('\U0001f512 blockUser (party-spezifische Sperre)');")
        while i < len(lines) and not lines[i].strip().startswith("try {"):
            i += 1
        continue
    if "debugLog('   userId:" in line or "debugLog('   clientId:" in line:
        i += 1
        continue
    if "debugLog('   name:" in line or "debugLog('   partyId:" in line:
        i += 1
        continue
    if "debugLog('" in line and "blockUser aufgerufen (party-spezifische Sperre):" in line:
        i += 1
        continue
    if "debugLog('" in line and "\u2550" in line:
        i += 1
        continue
    out.append(line)
    i += 1

text = "\n".join(out) + "\n"

text = re.sub(
    r"Party-Code gefunden: \$partyCode",
    "Party-Code geladen",
    text,
)
text = re.sub(
    r"\n      debugLog\('.*finalClientId initialisiert: \$finalClientId'\);",
    "",
    text,
)
text = re.sub(
    r"debugLog\('.*JA geklickt: Erstelle party-spezifische Sperre für DIESE Party mit ID: \$documentId'\);",
    "debugLog('\U0001f4e1 Erstelle party-spezifische Sperre');",
    text,
)
text = re.sub(
    r"\n      debugLog\('\\U0001f4e1 Collection: blocked_guests'\);\n"
    r"      debugLog\('\\U0001f4e1 Document-ID: \$documentId'\);\n"
    r"      debugLog\('\\U0001f4e1 blockData: \$blockData'\);",
    "",
    text,
)
text = re.sub(
    r"Trigger-Wunsch gefunden: \$triggerWishTitle",
    "Trigger-Wunsch-Metadaten geladen",
    text,
)
text = re.sub(
    r"Device block fusion: blocked_devices/' \+ finalClientId",
    "Device block fusion: blocked_devices",
    text,
)
text = re.sub(
    r"Aktueller Wunsch \$currentWishId wird als abgelehnt markiert",
    "Aktueller Wunsch wird abgelehnt markiert",
    text,
)
text = re.sub(
    r"Aktueller Wunsch \$currentWishId ist bereits abgelehnt",
    "Aktueller Wunsch ist bereits abgelehnt",
    text,
)
text = re.sub(
    r"Aktueller Wunsch \$currentWishId existiert nicht",
    "Aktueller Wunsch existiert nicht",
    text,
)
text = re.sub(
    r"Suche nach ALLEN pending Wünschen mit client_id: \$finalClientId, party_id: \$partyId",
    "KASKADIEREND: pending (client_id + party_id)",
    text,
)
text = re.sub(
    r"Suche nach ALLEN pending Wünschen mit user_id: \$userId, party_id: \$partyId",
    "KASKADIEREND: pending (user_id + party_id)",
    text,
)
text = re.sub(
    r"Wunsch-ID: \$\{wishDoc\.id\}, Status: \$currentStatus",
    "KASKADIEREND: Wunsch geprüft",
    text,
)
text = re.sub(
    r"Wunsch \$\{wishDoc\.id\} wird automatisch abgelehnt \(rejection_reason: user_blocked\)",
    "KASKADIEREND: Wunsch abgelehnt",
    text,
)
text = re.sub(
    r"Wunsch \$\{wishDoc\.id\} hat Status \$currentStatus, überspringe \(nur pending wird abgelehnt\)",
    "KASKADIEREND: Wunsch übersprungen (nicht pending)",
    text,
)
text = re.sub(
    r"\n          debugLog\('.*Keine client_id/user_id oder party_id verfügbar für kaskadierendes Ablehnen'\);\n"
    r"          debugLog\('   finalClientId: \$finalClientId, userId: \$userId, partyId: \$partyId'\);",
    "\n          debugLog('\u26a0\ufe0f Keine client_id/user_id oder party_id für kaskadierendes Ablehnen');",
    text,
)
text = re.sub(
    r"Direkte Sperre für \$name \(clientId: \$clientId, partyId: \$partyId\)",
    "Direkte Sperre (showGroupedBlockDialog)",
    text,
)

p.write_text(text, encoding="utf-8")
print("strip_blocking_logs: done")
