#!/usr/bin/env python3
"""Veraltet: Nutze stattdessen tool/apply_public_party_l10n_translations.py für echte Übersetzungen."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

if __name__ == "__main__":
    script = ROOT / "tool" / "apply_public_party_l10n_translations.py"
    sys.exit(subprocess.call([sys.executable, str(script)]))
