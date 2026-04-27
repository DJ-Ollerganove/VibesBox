# Play Store: Deobfuskierungs- und Symboldateien (Version 1.0.25+25)

## Build-Befehl (mit Symbolen)

```powershell
& "$env:USERPROFILE\Downloads\flutter_windows_3.38.4-stable\flutter\bin\flutter.bat" build appbundle --release --build-name=1.0.25 --build-number=25 --obfuscate --split-debug-info=build/app/outputs/symbols
```

Oder das Skript ausführen: `.\build_release_1.0.7.ps1` (nutzt dieselben Optionen).

## Wo liegen die Dateien?

| Zweck | Pfad |
|------|------|
| **Dart-Obfuskierungs-Symbole** (für Play Store / Crash-Berichte) | `build/app/outputs/symbols/` |
| | Enthält z. B.: `app.android-arm64.symbols`, `app.android-arm.symbols`, `app.android-x64.symbols` |
| **AAB (Upload)** | `build/app/outputs/bundle/release/app-release.aab` |
| **R8/ProGuard-Mapping** (nur bei aktiviertem Minify) | `android/app/build/outputs/mapping/release/mapping.txt` |

Hinweis: In diesem Projekt ist `isMinifyEnabled = false`. Daher wird **keine** `mapping.txt` erzeugt. Für die Flutter-/Dart-Deobfuskierung reichen die Dateien unter `build/app/outputs/symbols/`. Diese Ordner beim Upload in der Play Console angeben bzw. die `.symbols`-Dateien hochladen, sofern die Console sie verlangt.

## Hinweis zum Build

Der Build kann mit der Meldung *"Release app bundle failed to strip debug symbols from native libraries"* enden. AAB und Dart-Symbole werden trotzdem erzeugt; die Ausgabe liegt in den oben genannten Pfaden.

Der Befehl `flutter build symbols --out=...` existiert in Flutter nicht. Die Symbole werden durch `--obfuscate --split-debug-info=...` beim AAB-Build erzeugt.
