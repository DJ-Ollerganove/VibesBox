from pathlib import Path
import re

p = Path(__file__).resolve().parents[1] / "lib/services/subscription_sync_service.dart"
t = p.read_text(encoding="utf-8")
t = re.sub(
    r"Identität mit Firebase-UID \$uid verknüpft",
    "Identität verknüpft",
    t,
)
t = re.sub(r" \(User \$uid\)", "", t)
t = re.sub(r", User \$uid\)", ")", t)
t = re.sub(r": User \$uid hat Pro Life", ": Pro Life", t)
t = re.sub(r": User \$uid auf Free gesetzt", ": auf Free gesetzt", t)
t = re.sub(r": User \$uid bereits Free mit Stichtag", ": bereits Free mit Stichtag", t)
t = re.sub(r"für \$uid – keine erneute", "– keine erneute", t)
t = re.sub(r"für \$uid bis ", "bis ", t)
p.write_text(t, encoding="utf-8")
print("subscription_sync_service.dart fixed")
