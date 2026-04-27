# Tiefgreifende Analyse: Pegelberechnung (Visualisierung) der Musikerkennung

## Übersicht der relevanten Code-Stellen

| Datei | Zeile(n) | Verantwortung |
|-------|----------|---------------|
| `android/.../MainActivity.kt` | 614-620 | RMS-Berechnung (Rohdaten) |
| `android/.../MainActivity.kt` | 518-519, 569 | Normalisierung (Android → Flutter) |
| `android/.../MainActivity.kt` | 497-509 | Auto-Gain & Smart-Threshold |
| `lib/services/shazam_service.dart` | 121-124 | RMS-Stream (passthrough) |
| `lib/widgets/shazam_footer.dart` | 302-313, 412-418 | Visual Boost (×5) + Anzeige |
| `lib/widgets/audio_settings_card.dart` | 531-540, 737-738 | Visual Boost (×5) + Pegelbalken |
| `lib/pages/profile/widgets/shazam_settings_section.dart` | 436-437 | Visual Boost (×5) |
| `lib/widgets/rms_level_meter.dart` | 56-62, 104-108 | Kein Visual Boost (nur clamp) |

---

## 1. Rohwert-Skalierung (Multiplikatoren)

### Flutter-Seite (UI) – **Visual Boost × 5**

| Datei | Formel | Zweck |
|-------|--------|-------|
| `shazam_footer.dart` | `visualLevel = (rmsValue * 5.0).clamp(0.0, 1.0)` | Footer-Pegellinie |
| `audio_settings_card.dart` | `visualLevel = (rmsValue * 5.0).clamp(0.0, 1.0)` | Pegelbalken in Einstellungen |
| `shazam_settings_section.dart` | `visualLevel = (rmsValue * 5.0).clamp(0.0, 1.0)` | Profil-Pegelbalken |

**Effekt:** Ein RMS von 0.02 wird zu 0.10 (10 % Anzeige). Bei lauter Musik kann der Wert schnell auf 1.0 clippen.

### Android-Seite (Native) – **Normalisierung**

| Stelle | Formel | Erklärung |
|--------|--------|-----------|
| MainActivity.kt ~518 | `normalizedRms = (rms * micSensitivity / 10000.0).coerceIn(0.0, 1.0)` | Roh-RMS wird mit Sensitivity multipliziert und durch 10000 dividiert |

**Wichtiger Faktor:** `10000` – feste Normalisierungskonstante. Kein expliziter „× 5“ auf Android, aber die Division durch 10000 skaliert den Roh-RMS stark nach unten; der Sensitivity-Multiplikator (0.5–2.0) hebt ihn wieder an.

---

## 2. Mikrofon-Wahrnehmung vs. Anzeige

### RMS-Berechnung (Android)

```kotlin
// MainActivity.kt, Zeile 614-620
private fun calculateRMS(buffer: ShortArray, readSize: Int): Double {
    var sum = 0.0
    for (i in 0 until readSize) {
        val sample = buffer[i].toDouble()
        sum += sample * sample
    }
    return Math.sqrt(sum / readSize)
}
```

- **Typ:** RMS (Root Mean Square)
- **Quelle:** PCM-16-Bit (ShortArray)
- **Formel:** `sqrt(sum(sample²) / n)` – Standard-RMS für Audiosignale
- **Kein Peak:** Es wird kein Peak-Wert berechnet

### Normalisierung zur Anzeige

```
Roh-RMS (z.B. 2000) → (2000 * micSensitivity / 10000) → 0.0–1.0
```

- **micSensitivity:** 0.5 bis 2.0 (aus Firestore/Einstellungen)
- **Teiler 10000:** Feste Skalierung, damit typische RMS-Werte in 0.0–1.0 landen
- **Künstliche Anhebung:** Durch Sensitivity und später durch den Visual Boost × 5 in Flutter wird der Pegel optisch verstärkt

---

## 3. Reaktionsverhalten (Dynamic Range)

### Dämpfung / Smoothing

| Schicht | Verhalten |
|---------|-----------|
| **Android** | Keine Dämpfung – jeder RMS-Wert wird sofort an Flutter gesendet |
| **Flutter** | Keine Smoothing-Logik – Werte werden direkt übernommen |
| **Update-Rate** | 50 ms (20 Updates/s) – nur Throttling, kein Glätten |

**Ergebnis:** Die Anzeige reagiert sehr schnell und kann bei variabler Musik „nervös“ flackern.

### Auto-Gain / Smart-Threshold

| Stelle | Logik | Risiko |
|--------|-------|--------|
| MainActivity.kt ~497-509 | In den ersten 2 Sekunden: Durchschnitt der rohen RMS-Werte → optimierte Sensitivity und Threshold | **Passt sich an die leiseste Umgebung an** – bei Stille oder sehr leiser Musik wird Sensitivity hochgefahren; anschließend bei normaler Musik kann sofort „Übersteuerung“ entstehen |

```kotlin
// Auto-Gain Formel (Vereinfacht):
val avgRaw = rawRmsValues.average().coerceAtLeast(1.0)
val targetNormalized = 0.3
val optimizedSens = (targetNormalized * 10000.0 / avgRaw).coerceIn(0.5, 2.0)
```

- Bei niedrigem `avgRaw` (leise Umgebung) wird `optimizedSens` groß (bis 2.0).
- Bei lauter Musik danach → `normalizedRms = rms * 2.0 / 10000` → schnell hohe Werte bis 1.0.

---

## 4. Schwellenwerte und Grenzen

| Variable | Bereich | Datei/Stelle |
|----------|---------|--------------|
| Anzeige-Output | 0.0 bis 1.0 | Überall nach `.clamp(0.0, 1.0)` |
| `recognitionThreshold` | 0.0–1.0 | ShazamService, Firestore |
| `micSensitivity` | 0.5–2.0 | ShazamService, Firestore |
| `normalizedRms` | 0.0–1.0 | MainActivity nach `coerceIn(0.0, 1.0)` |
| `visualLevel` (nach ×5) | 0.0–1.0 | shazam_footer, audio_settings_card, shazam_settings_section |

---

## 5. Gesamt-Formeln (Datenfluss)

```
[PCM 16-Bit] 
    → calculateRMS() = sqrt(Σ(sample²)/n)  →  Roh-RMS (z.B. 0–32767)
    → normalizedRms = (rms * micSensitivity / 10000).coerceIn(0,1)  →  0.0–1.0
    → EventChannel → Flutter
    → visualLevel = (rmsValue * 5.0).clamp(0,1)  →  UI-Anzeige (Footer/Balken)
    → barWidth = screenWidth * visualLevel
```

---

## 6. Vorschläge zur Faktor-Reduktion

### Option A: Visual Boost von 5 auf 2 oder 3 reduzieren

**Dateien anpassen:**
- `lib/widgets/shazam_footer.dart` (Zeile 412)
- `lib/widgets/audio_settings_card.dart` (Zeile 737)
- `lib/pages/profile/widgets/shazam_settings_section.dart` (Zeile 436)

**Änderung:** `* 5.0` → `* 2.0` oder `* 3.0`

| Faktor | 0.02 RMS → Visual | 0.20 RMS → Visual |
|--------|-------------------|-------------------|
| 5 | 0.10 (10 %) | 1.0 (100 %) |
| 3 | 0.06 (6 %) | 0.6 (60 %) |
| 2 | 0.04 (4 %) | 0.4 (40 %) |

### Option B: Zentrale Konstante

Konstante z.B. in `ui_constants.dart` oder `app_config.dart` definieren:

```dart
/// Visual Boost für RMS-Pegelanzeige (Footer, Einstellungen, Profil)
static const double rmsVisualBoostFactor = 2.5;  // Ehemals 5.0
```

Dann in allen drei Widgets `rmsValue * rmsVisualBoostFactor` verwenden.

### Option C: Android-Normalisierung prüfen

Der Teiler `10000` in MainActivity.kt könnte zu aggressiv sein. Wenn typische Roh-RMS z.B. im Bereich 500–5000 liegen, wäre ein höherer Teiler (z.B. 15000) sinnvoll, um generell niedrigere Werte zu erzeugen – dann braucht der Visual Boost in Flutter nicht so stark zu sein.

---

## 7. Zusammenfassung

| Aspekt | Aktuell | Empfehlung |
|--------|---------|------------|
| **Rohwert-Skalierung** | × 5 in 3 Flutter-Widgets | Auf 2–3 reduzieren oder zentrale Konstante |
| **RMS vs. Peak** | RMS | Beibehalten (typisch für Audio) |
| **Normalisierung** | rms * sensitivity / 10000 | Evtl. Teiler erhöhen (15000) |
| **Smoothing** | Keines | Optional: Exponentieller Glättungsfilter in Flutter |
| **Auto-Gain** | Passt sich an leise Umgebung an | Risiko für Übersteuerung bei lauter Musik – ggf. aggressivere Begrenzung oder längere Kalibrierphase |
| **Schwellenwerte** | 0.0–1.0 überall | Keine Änderung nötig |
