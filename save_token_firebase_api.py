"""
Legacy-Dateiname (kein Firestore mehr):
Setzt APPLE_DEVELOPER_TOKEN über Firebase CLI in Secret Manager.
"""
import subprocess
import sys


def main() -> int:
    try:
        token_result = subprocess.run(
            [sys.executable, "token_generator.py"],
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        print("❌ Fehler bei token_generator.py")
        print(exc.stderr or exc.stdout)
        return 1

    token = token_result.stdout.strip()
    if not token.startswith("eyJ"):
        print("❌ Kein gültiger JWT-Token.")
        return 1

    print("🔐 Setze APPLE_DEVELOPER_TOKEN in Secret Manager ...")
    try:
        result = subprocess.run(
            ["firebase", "functions:secrets:set", "APPLE_DEVELOPER_TOKEN"],
            input=f"{token}\n",
            capture_output=True,
            text=True,
            check=True,
        )
        print(result.stdout.strip())
    except subprocess.CalledProcessError as exc:
        print("❌ Fehler beim Setzen des Secrets.")
        print(exc.stderr or exc.stdout)
        return 1

    print("✅ Secret gesetzt. Jetzt deployen:")
    print("firebase deploy --only functions:shazamProxy")
    return 0


if __name__ == "__main__":
    sys.exit(main())












