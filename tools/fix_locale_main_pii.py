from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]

loc = root / "lib/l10n/locale_helper.dart"
t = loc.read_text(encoding="utf-8")
t = re.sub(
    r" \(user=\$\{user\?\.uid \?\? \"none\"\}\)",
    "",
    t,
)
t = re.sub(
    r"users/\$\{user\.uid\}: language/selected_language = \$code",
    "Sprache gespeichert ($code)",
    t,
)
loc.write_text(t, encoding="utf-8")

mp = root / "lib/main_main_page.dart"
t = mp.read_text(encoding="utf-8")
t = re.sub(
    r"für uid=\$\{user\.uid\} bereits erledigt",
    "bereits erledigt",
    t,
)
t = re.sub(
    r"für uid=\$\{user\.uid\}",
    "",
    t,
)
t = re.sub(
    r"registriere authStateChanges \(distinct UID\)",
    "registriere authStateChanges",
    t,
)
t = re.sub(
    r"auth – UID/Login geändert \(accountSwitched\) user=\$\{user\?\.uid \?\? \"null\"\}",
    "auth – Login/Account gewechselt",
    t,
)
mp.write_text(t, encoding="utf-8")
print("ok")
