"""
Manuelle Variante für Secret-Workflow:
1) Token generieren
2) Befehl zum Setzen in Firebase Secret Manager ausgeben
"""
import subprocess
import sys


def main() -> int:
    try:
        result = subprocess.run(
            [sys.executable, "token_generator.py"],
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        print("❌ Fehler bei token_generator.py")
        print(exc.stderr or exc.stdout)
        return 1

    token = result.stdout.strip()
    if not token.startswith("eyJ"):
        print("❌ Kein gültiger JWT-Token erzeugt.")
        return 1

    print("=" * 80)
    print("APPLE DEVELOPER TOKEN GENERIERT")
    print("=" * 80)
    print(token)
    print()
    print("Als Secret setzen:")
    print("firebase functions:secrets:set APPLE_DEVELOPER_TOKEN")
    print("Danach deployen:")
    print("firebase deploy --only functions:shazamProxy")
    print("=" * 80)
    return 0


if __name__ == "__main__":
    sys.exit(main())












