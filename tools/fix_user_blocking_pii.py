from pathlib import Path
import re

p = Path(__file__).resolve().parents[1] / "lib/services/user_blocking_service.dart"
t = p.read_text(encoding="utf-8")
t = re.sub(
    r"    debugLog\('═+'\);\n    debugLog\('�� blockUser aufgerufen[^']*'\);\n debugLog\('   userId: \$userId'\);\n    debugLog\('   clientId: \$clientId'\);\n    debugLog\('   name: \$name'\);\n    debugLog\('   partyId: \$partyId'\);\n    debugLog\('═+'\);\n    \n",
    "    debugLog('�� blockUser (party-spezifische Sperre)');\n\n",
    t,
)
t = re.sub(
    r"debugLog\('�� Party-Code gefunden: \$partyCode'\);",
    "debug� Party-Code aus Party-Dokument geladen');",
    t,
)
t = re.sub(
    r" debugLog\('�� finalClientId initialisiert: \$finalClientId'\);\n",
    "",
    t,
)
t = re.sub(
    r" debugLog\('�� JA geklickt: Erstelle party-spezifische Sperre für DIESE Party mit ID: \$documentId'\);",
    "     � Erstelle party-spezifische Sperre (blocked_guests)');",
    t,
)
t = re.sub(
    r"      debugLog\('�� Collection: blocked_guests'\);\n      debug� Document-ID: \$documentId'\);\n      debug� blockData: \$blockData'\);\n      \n",
    "",
    t,
)
t = re.sub(
    r"debugLog\('�� Trigger-Wunsch gefunden: \$triggerWishTitle'\);",
    "� Trigger-Wunsch Metadaten geladen');",
    t,
)
t = re.sub(
    r"debugLog\('Device block fusion: blocked_devices/' \+ finalClientId\);",
    "debugLog('Device block fusion: blocked_devices geschrieben');",
    t,
)
t = re.sub(
    r"debug� Aktueller Wunsch \$currentWishId wird als abgelehnt markiert'\);",
    "� Aktueller Wunsch wird als abgelehnt markiert');",
    t,
)
t = re.sub(
    r"debug�️ Aktueller Wunsch \$currentWishId ist bereits abgelehnt'\);",
    "�️ Aktueller Wunsch ist bereits abgelehnt');",
    t,
)
t = re.sub(
    r"debugLog\('��️ Aktueller Wunsch \$currentWishId existiert nicht'\);",
    "debugLog('��️ Aktueller Wunsch existiert nicht');",
    t,
)
t = re.sub(
    r"debug� KASKADIEREND: Suche nach ALLEN pending Wünschen mit client_id: \$finalClientId, party_id: \$partyId'\);",
    "debugLog('�� KASKADIEREND: Suche pending Wünsche (client_id + party_id)');",
    t,
)
t = re.sub(
    r"debugLog\('�� KASKADIEREND: Suche nach ALLEN pending Wünschen mit user_id: \$userId, party_id: \$partyId'\);",
    "debugLog('�� KASKADIEREND: Suche pending Wünsche (user_id + party_id)');",
    t,
)
t = re.sub(
    r"debug� KASKADIEREND: Wunsch-ID: \$\{wishDoc\.id\}, Status: \$currentStatus'\);",
    "debugLog('�� KASKADIEREND: Wunsch geprüft');",
    t,
)
t = re.sub(
    r"debugLog\('�� KASKADIEREND: Wunsch \$\{wishDoc\.id\} wird automatisch abgelehnt \(rejection_reason: user_blocked\)'\);",
    "debugLog('�� KASKADIEREND: Wunsch automatisch abgelehnt');",
    t,
)
t = re.sub(
    r"debugLog\('��️ Wunsch \$\{wishDoc\.id\} hat Status \$currentStatus, überspringe \(nur pending wird abgelehnt\)'\);",
    "debugLog('��️ Wunsch übersprungen (nicht pending)');",
    t,
)
t = re.sub(
    r" debugLog\('��️ Keine client_id/user_id oder party_id verfügbar für kaskadierendes Ablehnen'\);\n          debugLog\('   finalClientId: \$finalClientId, userId: \$userId, partyId: \$partyId'\);",
    "         �️ Keine client_id/user_id oder party_id für kaskadierendes Ablehnen');",
    t,
)
t = re.sub(
    r"    debugLog\('�� showGroupedBlockDialog: Direkte Sperre für \$name \(clientId: \$clientId, partyId: \$partyId\)'\);",
    "    debugLog('�� showGroupedBlockDialog: Direkte Sperre');",
    t,
)
p.write_text(t, encoding="utf-8")
print("user_blocking ok")
