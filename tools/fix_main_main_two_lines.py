from pathlib import Path
import re

p = Path(__file__).resolve().parents[1] / "lib/main_main_page.dart"
t = p.read_text(encoding="utf-8")
t = re.sub(r"Cold-Start-Dienste '\);", "Cold-Start-Dienste');", t, count=1)
t = re.sub(r" \(\$\{user\.uid\}\) \u2013 Tab", " \u2013 Tab", t)
p.write_text(t, encoding="utf-8")
print("ok")
