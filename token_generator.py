import os
import sys
import time

import jwt


def _required_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise ValueError(f"Umgebungsvariable fehlt: {name}")
    return value


def _read_private_key() -> str:
    raw = os.getenv("APPLE_PRIVATE_KEY", "").strip()
    if raw:
        return raw.replace("\\n", "\n")

    key_path = os.getenv("APPLE_PRIVATE_KEY_PATH", "").strip()
    if key_path:
        with open(key_path, "r", encoding="utf-8") as f:
            return f.read().strip()

    raise ValueError(
        "Privater Schlüssel fehlt. Setze APPLE_PRIVATE_KEY oder APPLE_PRIVATE_KEY_PATH."
    )


def generate_token() -> str:
    key_id = _required_env("APPLE_KEY_ID")
    team_id = _required_env("APPLE_TEAM_ID")
    private_key = _read_private_key()

    now = int(time.time())
    payload = {
        "iss": team_id,
        "iat": now,
        "exp": now + (180 * 24 * 60 * 60),
    }

    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id})


if __name__ == "__main__":
    try:
        print(generate_token())
    except Exception as exc:
        print(f"Fehler bei Token-Generierung: {exc}", file=sys.stderr)
        sys.exit(1)












