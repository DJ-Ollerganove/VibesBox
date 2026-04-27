# -*- coding: utf-8 -*-
"""
Generiert app_localizations_it.dart / app_localizations_uk.dart und vb/lang/it.js / uk.js
aus den englischen Quellen. Platzhalter und Marken werden geschützt.
Benötigt: pip install deep-translator

Ausführen (Fortschritt live, ungepuffert):
  python -u tools/gen_l10n_mt.py
Nur Meilensteine:
  python tools/gen_l10n_mt.py --quiet

Übersetzung in Batches (translate_batch) über einzigartige englische Texte — deutlich schneller
als Einzelaufrufe pro Key.

Vor der API: translation_glossary.json ersetzt wishbox/wish box/wunschbox durch einen Platzhalter;
nach der Übersetzung wird der Zielbegriff aus wishbox_term eingesetzt.
"""
from __future__ import annotations

import argparse
import json
import re
import time
from pathlib import Path

from deep_translator import GoogleTranslator


def log(msg: str) -> None:
    print(msg, flush=True)

ROOT = Path(__file__).resolve().parents[1]
GLOSSARY_PATH = ROOT / "translation_glossary.json"


def load_glossary() -> dict | None:
    if not GLOSSARY_PATH.is_file():
        return None
    return json.loads(GLOSSARY_PATH.read_text(encoding="utf-8"))


def gloss_normalize_english(s: str, glossary: dict | None) -> str:
    """Ersetzt engl./Marken-Schreibweisen durch Platzhalter vor der Übersetzungs-API."""
    if not glossary:
        return s
    mt = glossary.get("machine_translation") or {}
    ph = mt.get("placeholder", "[[[WISHBOX_GLOSS]]]")
    for rule in mt.get("normalize_english_before_api", []):
        if rule.get("replace_with_placeholder"):
            s = re.sub(rule["pattern"], ph, s)
    return s


def gloss_finalize_translated(s: str, glossary: dict | None, target_lang: str) -> str:
    """Setzt Platzhalter auf den gewünschten Zielbegriff aus wishbox_term."""
    if not glossary:
        return s
    mt = glossary.get("machine_translation") or {}
    if not mt.get("apply_after_translate", True):
        return s
    ph = mt.get("placeholder", "[[[WISHBOX_GLOSS]]]")
    terms = glossary.get("wishbox_term") or {}
    term = terms.get(target_lang)
    if term and ph in s:
        s = s.replace(ph, term)
    return s


SKIP_VALUES = {
    "VibesBox",
    "DJ",
    "QR",
    "PDF",
    "PWA",
    "Spotify",
    "Shazam",
    "Firebase",
    "Email",
    "Cloud Function",
    "MASS_VERIFY_TRIGGER",
}

TOKEN_PATTERN = re.compile(
    r"(\{[a-zA-Z_][a-zA-Z0-9_]*\})|(\$\{[^}]+\})|(%s)|(%\d+\$[sd])|(\n)"
)


def decode_dart_str(raw: str) -> str:
    out: list[str] = []
    i = 0
    while i < len(raw):
        if raw[i] == "\\" and i + 1 < len(raw):
            n = raw[i + 1]
            if n == "n":
                out.append("\n")
                i += 2
                continue
            if n == "t":
                out.append("\t")
                i += 2
                continue
            if n == "'":
                out.append("'")
                i += 2
                continue
            if n == "\\":
                out.append("\\")
                i += 2
                continue
            if n == "r":
                out.append("\r")
                i += 2
                continue
            if n == "$":
                out.append("$")
                i += 2
                continue
        out.append(raw[i])
        i += 1
    return "".join(out)


def encode_dart_str(s: str) -> str:
    # Reihenfolge: zuerst \, dann $ (Dart: $ beginnt String-Interpolation)
    return (
        s.replace("\\", "\\\\")
        .replace("$", r"\$")
        .replace("'", "\\'")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
    )


def protect(s: str) -> tuple[str, dict[str, str]]:
    tokens: dict[str, str] = {}
    idx = 0

    def repl(m: re.Match[str]) -> str:
        nonlocal idx
        t = f"__VBPH{idx}__"
        tokens[t] = m.group(0)
        idx += 1
        return t

    masked = TOKEN_PATTERN.sub(repl, s)
    masked = masked.replace("VibesBox", "__VIBESBOX__")
    return masked, tokens


def unprotect(s: str, tokens: dict[str, str]) -> str:
    out = s.replace("__VIBESBOX__", "VibesBox")
    for t, orig in tokens.items():
        out = out.replace(t, orig)
    return out


def should_skip(text: str) -> bool:
    t = text.strip()
    if not t:
        return True
    if t in SKIP_VALUES:
        return True
    if re.fullmatch(r"[\d\s\W]+", t):
        return True
    return False


def unique_english_in_order(entries: list[tuple[str, str]]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for _k, v in entries:
        if v not in seen:
            seen.add(v)
            out.append(v)
    return out


def translate_unique_strings(
    unique_vals: list[str],
    tr: GoogleTranslator,
    *,
    label: str,
    verbose: bool,
    batch_size: int,
    glossary: dict | None,
    target_lang: str,
) -> dict[str, str]:
    cache: dict[str, str] = {}
    prepared: list[tuple[str, str, dict[str, str]]] = []
    for v in unique_vals:
        if should_skip(v):
            cache[v] = v
        else:
            v_api = gloss_normalize_english(v, glossary)
            masked, tok = protect(v_api)
            prepared.append((v, masked, tok))

    if not prepared:
        log(f"  [{label}] Keine API-Texte (nur Skip-Werte).")
        return cache

    n_batches = (len(prepared) + batch_size - 1) // batch_size
    log(
        f"  [{label}] {len(prepared)} Texte in {n_batches} Batches "
        f"(je max. {batch_size}) …"
    )

    for bi in range(0, len(prepared), batch_size):
        chunk = prepared[bi : bi + batch_size]
        masked_only = [c[1] for c in chunk]
        batch_num = bi // batch_size + 1
        t0 = time.perf_counter()
        try:
            results = tr.translate_batch(masked_only)
        except Exception as e:
            log(f"  ! Batch {batch_num}: translate_batch fehlgeschlagen ({e}) — Einzelaufrufe …")
            results = []
            for m in masked_only:
                try:
                    results.append(tr.translate(m))
                except Exception as e2:
                    log(f"    ! Einzel-Fehler: {e2}")
                    results.append(m)
        if not results or len(results) != len(chunk):
            log(
                f"  ! Batch {batch_num}: falsche Antwortlänge ({len(results or [])} vs {len(chunk)}) — Einzelaufrufe …"
            )
            results = []
            for m in masked_only:
                try:
                    results.append(tr.translate(m))
                except Exception:
                    results.append(m)
        dt = time.perf_counter() - t0
        for (v, _masked, tok), res in zip(chunk, results):
            r = res if res is not None else ""
            out = gloss_finalize_translated(unprotect(r, tok), glossary, target_lang)
            cache[v] = out
        if verbose:
            v0, _, tok0 = chunk[0]
            r0 = cache[v0]
            en_prev = v0.replace("\n", " ")[:70]
            out_prev = r0.replace("\n", " ")[:70]
            log(
                f"  [{label}] Batch {batch_num}/{n_batches}  {len(chunk)} Strings in {dt:.1f}s\n"
                f"      z.B. EN: {en_prev}{'…' if len(v0) > 70 else ''}\n"
                f"          →:  {out_prev}{'…' if len(r0) > 70 else ''}"
            )
        else:
            log(
                f"  [{label}] Batch {batch_num}/{n_batches} fertig ({len(chunk)} Strings, {dt:.1f}s)"
            )
        time.sleep(0.15)

    return cache


def apply_cache(entries: list[tuple[str, str]], cache: dict[str, str]) -> list[tuple[str, str]]:
    missing = [v for _k, v in entries if v not in cache]
    if missing:
        raise SystemExit(f"Interner Fehler: {len(missing)} Werte ohne Cache-Eintrag")
    return [(k, cache[v]) for k, v in entries]


def skip_ws(s: str, i: int) -> int:
    while i < len(s):
        if s[i] in " \t\n\r":
            i += 1
            continue
        if i + 1 < len(s) and s[i : i + 2] == "//":
            while i < len(s) and s[i] != "\n":
                i += 1
            continue
        break
    return i


def parse_string(s: str, i: int) -> tuple[str | None, int]:
    if i >= len(s) or s[i] != "'":
        return None, i
    i += 1
    raw: list[str] = []
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            raw.append(c + s[i + 1])
            i += 2
            continue
        if c == "'":
            return "".join(raw), i + 1
        raw.append(c)
        i += 1
    return None, i


def parse_dart_map(path: Path, marker: str) -> list[tuple[str, str]]:
    content = path.read_text(encoding="utf-8")
    idx = content.find(marker)
    if idx < 0:
        raise SystemExit(f"marker not found in {path}: {marker!r}")
    i = idx + len(marker)
    i = skip_ws(content, i)
    if i >= len(content) or content[i] != "{":
        raise SystemExit("expected { after marker")
    i += 1
    entries: list[tuple[str, str]] = []
    while True:
        i = skip_ws(content, i)
        if i < len(content) and content[i] == "}":
            break
        key_raw, i = parse_string(content, i)
        if key_raw is None:
            raise SystemExit(f"bad key at {i}")
        key = decode_dart_str(key_raw)
        i = skip_ws(content, i)
        if i >= len(content) or content[i] != ":":
            raise SystemExit(f"expected : after key {key}")
        i += 1
        i = skip_ws(content, i)
        val_raw, i = parse_string(content, i)
        if val_raw is None:
            raise SystemExit(f"bad value for {key}")
        val = decode_dart_str(val_raw)
        i = skip_ws(content, i)
        if i < len(content) and content[i] == ",":
            i += 1
        entries.append((key, val))
    return entries


def write_dart_class(
    entries: list[tuple[str, str]], out_path: Path, class_name: str
) -> None:
    lines = [
        f"class {class_name} {{",
        "  static const Map<String, String> translations = {",
    ]
    for k, v in entries:
        ek = encode_dart_str(k)
        ev = encode_dart_str(v)
        lines.append(f"    '{ek}': '{ev}',")
    lines.append("  };")
    lines.append("}")
    lines.append("")
    out_path.write_text("\n".join(lines), encoding="utf-8")


def write_js_window(entries: list[tuple[str, str]], out_path: Path, var_name: str) -> None:
    lines = [
        f"// PWA Übersetzungen: {var_name.split('_')[-1]} (aus en.js, maschinell übersetzt)",
        f"window.{var_name} = {{",
    ]
    for k, v in entries:
        jk = k.replace("\\", "\\\\").replace("'", "\\'")
        jv = v.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "\\r")
        lines.append(f"  '{jk}': '{jv}',")
    lines.append("};")
    lines.append("")
    out_path.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="EN → IT/UK für Dart + vb/lang JS")
    parser.add_argument("--quiet", action="store_true", help="Kürzeres Log (pro Batch eine Zeile)")
    parser.add_argument(
        "--batch-size",
        type=int,
        default=35,
        help="Strings pro translate_batch (Standard: 35)",
    )
    args = parser.parse_args()
    verbose = not args.quiet
    batch_size = max(1, min(args.batch_size, 80))

    glossary = load_glossary()
    if glossary:
        log("Glossar translation_glossary.json geladen (Wishbox-Platzhalter für MT).")

    dart_src = ROOT / "lib" / "l10n" / "app_localizations_en.dart"
    entries = parse_dart_map(dart_src, "static const Map<String, String> translations = ")
    log(f"=== Dart-Map: {len(entries)} Keys, {len(unique_english_in_order(entries))} eindeutige engl. Texte ===")

    for target, suffix, class_name in [
        ("it", "it", "AppLocalizationsIT"),
        ("uk", "uk", "AppLocalizationsUK"),
    ]:
        tr = GoogleTranslator(source="en", target=target)
        label = f"Dart→{target.upper()}"
        log(f"--- {label} ---")
        t_phase = time.perf_counter()
        uniq = unique_english_in_order(entries)
        cache = translate_unique_strings(
            uniq,
            tr,
            label=label,
            verbose=verbose,
            batch_size=batch_size,
            glossary=glossary,
            target_lang=suffix,
        )
        translated = apply_cache(entries, cache)
        log(f"--- {label} fertig in {time.perf_counter() - t_phase:.0f}s — schreibe Datei ---")
        out = ROOT / "lib" / "l10n" / f"app_localizations_{suffix}.dart"
        write_dart_class(translated, out, class_name)
        log(f"Geschrieben: {out}")

    js_src = ROOT / "public" / "vb" / "lang" / "en.js"
    js_content = js_src.read_text(encoding="utf-8")
    m = re.search(r"window\.lang_en\s*=\s*\{", js_content)
    if not m:
        raise SystemExit("window.lang_en not found")
    sub = js_content[m.end() - 1 :]
    entries_js: list[tuple[str, str]] = []
    i = 0
    if sub[i] != "{":
        raise SystemExit("parse js")
    i += 1
    while True:
        i = skip_ws(sub, i)
        if i < len(sub) and sub[i] == "}":
            break
        key_raw, i = parse_string(sub, i)
        if key_raw is None:
            raise SystemExit(f"js bad key {i}")
        key = decode_dart_str(key_raw)
        i = skip_ws(sub, i)
        if i >= len(sub) or sub[i] != ":":
            raise SystemExit("js :")
        i += 1
        i = skip_ws(sub, i)
        val_raw, i = parse_string(sub, i)
        if val_raw is None:
            raise SystemExit(f"js val {key}")
        val = decode_dart_str(val_raw)
        i = skip_ws(sub, i)
        if i < len(sub) and sub[i] == ",":
            i += 1
        entries_js.append((key, val))

    log(
        f"=== PWA JS: {len(entries_js)} Keys, {len(unique_english_in_order(entries_js))} eindeutige Texte ==="
    )

    for target, suffix, var_name in [
        ("it", "it", "lang_it"),
        ("uk", "uk", "lang_uk"),
    ]:
        tr = GoogleTranslator(source="en", target=target)
        label = f"JS→{target.upper()}"
        log(f"--- {label} ---")
        t_phase = time.perf_counter()
        uniq = unique_english_in_order(entries_js)
        cache = translate_unique_strings(
            uniq,
            tr,
            label=label,
            verbose=verbose,
            batch_size=batch_size,
            glossary=glossary,
            target_lang=suffix,
        )
        translated_js = apply_cache(entries_js, cache)
        log(f"--- {label} fertig in {time.perf_counter() - t_phase:.0f}s ---")
        out = ROOT / "public" / "vb" / "lang" / f"{suffix}.js"
        write_js_window(translated_js, out, var_name)
        log(f"Geschrieben: {out}")

    log("=== Alle Sprachen erzeugt. Fertig. ===")


if __name__ == "__main__":
    main()
