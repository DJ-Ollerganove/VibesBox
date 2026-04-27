from pathlib import Path
import re

p = Path(__file__).resolve().parents[1] / "lib/widgets/wish_card.dart"
t = p.read_text(encoding="utf-8")
t = re.sub(r"debugLog\('\U0001f4e1\s+ONE-CLICK:", "debugLog('\U0001f4e1 ONE-CLICK:", t)
p.write_text(t, encoding="utf-8")
print("ok")
