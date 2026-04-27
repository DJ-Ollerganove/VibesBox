# Icon und App-Name Update Anleitung

## Problem
- Das Icon in der App-Liste ist noch das alte DJ-WB Icon
- Die App wird unter "D" statt "V" sortiert

## Lösung

### 1. Icons neu generieren
Nachdem du die App neu kompiliert hast, führe diesen Befehl aus:

```bash
flutter pub run flutter_launcher_icons
```

Dies generiert die neuen Icons aus `assets/icon/vibesbox-logo.png` für Android und iOS.

### 2. App neu installieren
**WICHTIG:** Die App muss komplett deinstalliert und neu installiert werden, damit:
- Der neue Name "VibesBox" wirksam wird
- Die App unter "V" statt "D" sortiert wird
- Das neue Icon angezeigt wird

**Schritte:**
1. Alte App vom Handy deinstallieren
2. App neu kompilieren und installieren
3. Die App sollte jetzt als "VibesBox" unter "V" erscheinen mit dem neuen Icon

### Warum muss die App neu installiert werden?
Android/iOS speichern den App-Namen beim ersten Installieren. Eine einfache Aktualisierung ändert den Namen in der App-Liste nicht. Nur eine komplette Neuinstallation setzt den Namen zurück.

## Aktuelle Konfiguration
✅ `android/app/src/main/AndroidManifest.xml`: `android:label="VibesBox"`
✅ `ios/Runner/Info.plist`: `CFBundleDisplayName = "VibesBox"`
✅ `pubspec.yaml`: Icon-Pfad auf `assets/icon/vibesbox-logo.png`

Die Konfiguration ist korrekt - es muss nur neu generiert und installiert werden!















