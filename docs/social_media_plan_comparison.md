# Vergleich: Social-Media Filter-Logik PWA vs. Flutter-App

## PWA (`public/vb/app.js`)

### 1. Plan-Speicherung (Zeile 2640–2642)
```javascript
// userData aus users/{createdByUid}
const planType = (userData.planType != null && String(userData.planType).trim() !== '')
  ? String(userData.planType).toLowerCase()
  : 'free';
sessionStorage.setItem('djPlanType', planType);
```
- Jeder Wert außer `null`/leer → wird gespeichert (`'pro'`, `'pro life'`, `'trial'`)
- Keine Liste erlaubter Pläne, nur: „ist es 'free' oder etwas anderes?“

### 2. Pro-Check (Logo, Kontakt, Branding – Zeilen 4297, 4904, 5857, 6669)
```javascript
const planType = (sessionStorage.getItem('djPlanType') || '').toLowerCase();
const isFree = planType === 'free';   // bzw. planType === 'free' ? ... : ...
// → isPro = planType !== 'free'
```
- Es wird **nur** geprüft: `planType === 'free'`. Jeder andere Wert gilt als Pro.

### 3. Social-Media-Seite
- **Kein planType-Filter**: `renderSocialMediaLinks()` prüft den Plan **nicht**. Es werden Links immer angezeigt, wenn sie in `social_media_links` existieren.
- Die PWA filtert Social Media nach Plan aktuell nicht.

### 4. Daten-Pfad
```javascript
const createdByUid = partyDoc.data().created_by;  // NUR created_by!
const socialsRef = firebaseDoc(collection(db, 'social_media_links'), createdByUid);
```
- Quelle: `parties/{partyId}` → `created_by`
- Lese-Pfad: `social_media_links/{created_by}`

---

## Flutter-App (`lib/pages/social_media_page.dart`)

### 1. Plan-Lesen aus Firestore (Zeile 244–252)
```dart
// users/{djId}
final ptRaw = (ud['planType'] as String?) ?? (ud['plan'] as String?) ?? (ud['accountType'] as String?);
final pt = ptRaw?.trim().toLowerCase();
planType = (pt != null && pt.isNotEmpty) ? pt : (isProBool ? 'pro' : 'free');
```
- Reihenfolge: `planType` → `plan` → `accountType`; Fallback über `isPro` (bool)
- **Problem**: Cast `as String?` kann fehlschlagen, wenn Firestore einen anderen Typ speichert (z.B. Zahl).

### 2. Pro-Check (Zeile 258)
```dart
final bool isPro = planType != null && planType.isNotEmpty && planType != 'free';
```
- Logik entspricht PWA: `planType != 'free'` → Pro
- `planType == 'pro life'` → `!= 'free'` → Pro (sollte funktionieren)

### 3. djId / Daten-Pfad (Zeile 242)
```dart
djId = (data['dj_code'] as String?) ?? (data['created_by'] as String?);
// social_media_links/{djId}
```
- PWA nutzt **nur** `created_by`. Flutter bevorzugt `dj_code`. Bei älteren Partys könnte das abweichen.

---

## Zusammenfassung

| Aspekt            | PWA                              | Flutter (aktuell)                     |
|-------------------|----------------------------------|---------------------------------------|
| Pro-Check         | `planType !== 'free'`            | `planType != 'free'` ✓                |
| Plan-Quelle       | `userData.planType` (String)     | `planType`, `plan`, `accountType`      |
| Social-Filter     | Keiner (zeigt immer)             | Nur Pro sieht Links ✓                 |
| djId für Links    | `created_by`                     | `dj_code ?? created_by`               |
| Robustheit        | `String(userData.planType)`      | Cast `as String?` (kann fehlschlagen) |

## Änderungen

1. ** Robust planType**: `planType.toString().toLowerCase() != 'free'` statt striktem String-Cast
2. **djId**: `created_by` priorisieren (wie PWA): `created_by ?? dj_code`
3. **Debug-Print**: `DJ-Plan in App erkannt als: $planType`
