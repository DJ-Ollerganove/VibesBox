import re
from pathlib import Path

path = Path(r"c:\Users\Ollerganove\Desktop\dj-og-app\lib\widgets\wish_card.dart")
text = path.read_text(encoding="utf-8")

# Strip l.<getter>(...) ?? 'fallback' or l.<getter> ?? 'fallback'
pat = re.compile(
    r"l\.([a-zA-Z_]\w*)((?:\([^)]*\))?)\s*\?\?\s*'(?:[^'\\]|\\.)*'"
)
pat2 = re.compile(
    r'l\.([a-zA-Z_]\w*)((?:\([^)]*\))?)\s*\?\?\s*"(?:[^"\\]|\\.)*"'
)

prev = None
while prev != text:
    prev = text
    text = pat.sub(r"l.\1\2", text)
    text = pat2.sub(r"l.\1\2", text)

# Multiline: description: l.foo ?? 'line1...',
pat_ml = re.compile(
    r"l\.([a-zA-Z_]\w*)\s*\?\?\s*'(?:[^'\\]|\\.)*'\s*,\s*\n\s*'",
    flags=re.DOTALL,
)
# If still have l.xxx ?? — run once more with multiline for long strings - skip for now

path.write_text(text, encoding="utf-8")
print("done")
