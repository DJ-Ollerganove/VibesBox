"""
Legacy-Dateiname, neue Funktion:
Generiert einen Apple Developer Token und speichert ihn in Firebase Secret Manager
als APPLE_DEVELOPER_TOKEN (kein Firestore mehr).
"""
import subprocess
import sys


def main() -> int:
    print("🔄 Generiere neuen Apple Developer Token...")
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
    if not token or not token.startswith("eyJ"):
        print("❌ Token ungültig oder leer.")
        return 1

    print("✅ Token generiert – speichere in Secret Manager...")
    try:
        secret_set = subprocess.run(
            ["firebase", "functions:secrets:set", "APPLE_DEVELOPER_TOKEN"],
            input=f"{token}\n",
            text=True,
            capture_output=True,
            check=True,
        )
        print(secret_set.stdout.strip())
    except subprocess.CalledProcessError as exc:
        print("❌ Konnte APPLE_DEVELOPER_TOKEN nicht setzen.")
        print(exc.stderr or exc.stdout)
        return 1

    print("✅ Secret aktualisiert: APPLE_DEVELOPER_TOKEN")
    print("➡️ Nächster Schritt: firebase deploy --only functions:shazamProxy")
    return 0


if __name__ == "__main__":
    sys.exit(main())












