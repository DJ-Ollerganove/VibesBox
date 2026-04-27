from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]

s = (root / "lib/services/statistics_service.dart").read_text(encoding="utf-8")
s = re.sub(
    r"\n      // Prüfe, ob User authentifiziert ist \(für Debugging\)\n"
    r"      final user = FirebaseAuth\.instance\.currentUser;\n"
    r"      debugLog\('.*StatisticsService: User authentifiziert: \$\{user != null\}'\);\n"
    r"      if \(user != null\) \{\n      \}\n      \n",
    "\n",
    s,
)
(root / "lib/services/statistics_service.dart").write_text(s, encoding="utf-8")

p = (root / "lib/party_verwaltung_page.dart").read_text(encoding="utf-8")
p = re.sub(
    r"debugLog\('.*Party \$partyId erfolgreich gelöscht '\);",
    "debugLog('Party gelöscht');",
    p,
)
(root / "lib/party_verwaltung_page.dart").write_text(p, encoding="utf-8")
print("ok")
