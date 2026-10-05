# VibesBox Sync (`rb_now_playing`)

Desktop-Tool: DJ-Library / Now-Playing mit VibesBox verbinden (macOS + Windows).

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

Wie bisher über Xcode / `flutter build macos --release` im Ordner `tools/rb_now_playing`.
