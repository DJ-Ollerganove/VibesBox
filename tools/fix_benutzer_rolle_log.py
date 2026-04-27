from pathlib import Path

p = Path(__file__).resolve().parents[1] / "lib/pages/benutzer_verwaltung_page.dart"
t = p.read_text(encoding="utf-8")
t = t.replace(
    "debugLog('\U0001f527 Aktualisiere Rolle ');",
    "debugLog('\U0001f527 Aktualisiere Rolle');",
)
p.write_text(t, encoding="utf-8")
print("ok")
