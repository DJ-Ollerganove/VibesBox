import re
from pathlib import Path

ROOT = Path(__file__).parent / "lib"
SQ = r"'(?:[^'\\]|\\.)*'"

FILES = list(ROOT.rglob("*.dart"))

# Skip obvious backups / generated if needed
SKIP_PARTS = ("backup", "gespielt_page_old", "settings_page_backup")


def should_skip(p: Path) -> bool:
    s = str(p).lower()
    return any(x in s for x in SKIP_PARTS)


def process(text: str) -> str:
    t = text
    t = t.replace("AppLocalizations.of(context);", "AppLocalizations.of(context)!;")
    t = re.sub(r"AppLocalizations\?\s+l\b", "AppLocalizations l", t)
    t = t.replace("localizations?.", "localizations.")
    t = t.replace("l?.", "l.")
    t = t.replace("loc?.", "loc.")
    for _ in range(2000):
        nt = re.sub(rf"(\bl|loc)\.(\w+)\s*\?\?\s*{SQ}", r"\1.\2", t)
        if nt == t:
            break
        t = nt
    for _ in range(500):
        nt = re.sub(
            rf"(\bl|loc)\.(\w+)\(([^)]*)\)\s*\?\?\s*{SQ}",
            r"\1.\2(\3)",
            t,
        )
        if nt == t:
            break
        t = nt
    return t


def main() -> None:
    for path in FILES:
        if should_skip(path):
            continue
        try:
            orig = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if "l?." not in orig and "localizations?." not in orig and "loc?." not in orig:
            continue
        new = process(orig)
        if new != orig:
            path.write_text(new, encoding="utf-8")
            print("updated", path.relative_to(ROOT.parent))


if __name__ == "__main__":
    main()
