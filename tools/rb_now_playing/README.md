# VibesBox Sync (`rb_now_playing`)

Desktop-Tool: DJ-Library / Now-Playing mit VibesBox verbinden (macOS + Windows).

## Version / Updates

**Eine Quelle:** `tools/rb_now_playing/pubspec.yaml` → Zeile `version:` (z. B. `1.0.3+3`).

Beim Windows-Build/Deploy wird daraus automatisch:
- `lib/tool_version.dart` (`kSyncToolVersion` für den Update-Check im Tool)
- Installer-Dateiname
- `public/sync/index.html` + `firebase.json` Download-Link (beim Deploy)

**Neues Release (Beispiel 1.0.3):**

1. In `pubspec.yaml` Version auf `1.0.3+3` setzen  
2. Windows: `.\build_windows_installer.ps1` dann `.\scripts\deploy_sync_windows.ps1`  
3. In der VibesBox-App (Admin → VibesBox Sync): Windows = `1.0.3`, Download-URL setzen, **Mindestversion** anhaken wenn alte Clients blockiert werden sollen  

Mac-Build vorher: `./scripts/sync_version_from_pubspec.sh`

## Windows: Installer bauen

Auf einem **Windows-PC** (Flutter Windows-Build läuft nicht auf dem Mac).

### Einmalig vorbereiten

1. **Flutter** (wie im Projekt üblich), z. B.  
   `%USERPROFILE%\Downloads\flutter_windows_3.38.4-stable\flutter\bin\flutter.bat`
2. **Visual Studio 2022** mit Workload **„Desktop development with C++“**
3. **Inno Setup 6 oder 7** (für die Setup-`.exe`): https://jrsoftware.org/isdl.php  
   Ohne Inno Setup erzeugt das Skript trotzdem ein **ZIP** (portable).

### Build (ein Befehl)

In **PowerShell**:

```powershell
cd $env:USERPROFILE\dev\VibesBox
git fetch
git checkout restore/v1.1.63-history-paywall
# oder den Branch mit dem Installer-Skript, sobald gemerged

cd tools\rb_now_playing
.\build_windows_installer.ps1
```

Ergebnis unter `tools\rb_now_playing\dist\`:

| Datei | Zweck |
| --- | --- |
| `VibesBoxSync-Setup-<version>.exe` | Installer (Startmenü, Deinstallation) |
| `VibesBoxSync-<version>-windows-x64.zip` | Portable (Ordner entpacken und `VibesBoxSync.exe` starten) |

### Auf vibesbox.app hochladen

Die `.exe` ist gitignored (wie die Mac-`.pkg`). Nach dem Build:

```powershell
cd $env:USERPROFILE\dev\VibesBox
git pull
.\scripts\deploy_sync_windows.ps1
```

Kopiert nach `public\sync\VibesBox-Sync-<version>-windows.exe` und deployt Hosting.  
Seite: https://vibesbox.app/sync/

### Nur Flutter bauen (ohne Setup)

```powershell
cd $env:USERPROFILE\dev\VibesBox\tools\rb_now_playing
& "$env:USERPROFILE\Downloads\flutter_windows_3.38.4-stable\flutter\bin\flutter.bat" pub get
& "$env:USERPROFILE\Downloads\flutter_windows_3.38.4-stable\flutter\bin\flutter.bat" build windows --release
```

Release-Ordner: `build\windows\x64\runner\Release\`  
Zum Testen dort `VibesBoxSync.exe` starten.

### Optionen

```powershell
# Nur ZIP, kein Inno Setup
.\build_windows_installer.ps1 -ZipOnly

# Release schon gebaut → nur packen
.\build_windows_installer.ps1 -SkipFlutterBuild

# Anderer Flutter-Pfad
.\build_windows_installer.ps1 -FlutterBat 'D:\flutter\bin\flutter.bat'
```

## macOS

```bash
cd tools/rb_now_playing
./scripts/sync_version_from_pubspec.sh
flutter build macos --release
```
