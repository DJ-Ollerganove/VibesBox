from pathlib import Path

p = Path(__file__).resolve().parents[1] / "lib/services/user_blocking_service.dart"
lines = p.read_text(encoding="utf-8").splitlines(keepends=True)
out = []
skip_next = 0
for L in lines:
    if "Collection: blocked_guests" in L and "debugLog" in L:
        continue
    if "Document-ID: $documentId" in L and "debugLog" in L:
        continue
    if "blockData: $blockData" in L and "debugLog" in L:
        continue
    out.append(L)
p.write_text("".join(out), encoding="utf-8")
print("ok")
