# Firestore Collection `users` – Feld-Referenz

Diese Liste entsteht aus dem **Code** (UserModel, set/update/get auf `users/{uid}`).  
Welche Felder **in deiner Datenbank tatsächlich vorkommen**, siehst du per Firebase Console oder mit dem Skript unten.

---

## Top-Level-Felder im User-Dokument (users/{uid})

| Key | Typ / Verwendung | Quelle (z. B. UserModel, Login, Profil, …) |
|-----|------------------|---------------------------------------------|
| `admin` | bool? | UserModel, Benutzerverwaltung |
| `app_version` | string | AppUpdateService (Legacy), Benutzerverwaltung; neuer: siehe `devices` |
| `app_version_updated_at` | Timestamp? | (Legacy, evtl. noch vorhanden) |
| `auto_start_recognition` | bool? | PartyAutostartService, AudioSettingsCard |
| `birthDate` | Timestamp? | UserModel, Profil |
| `country` | string? | UserModel, Profil |
| `created_at` | Timestamp? | UserModel, Login |
| `displayName` | string? | UserModel, Login, Profil, Benutzerverwaltung |
| `devices` | map | AppUpdateService (Geräte-Historie: deviceId → app_version, device_model, os_version, platform, last_seen) |
| `email` | string? | UserModel, Login, Profil, Benutzerverwaltung |
| `email_verified_override` | bool? | FirestoreEmailVerifiedGate: erlaubt Zugang zur MainPage ohne Firebase `emailVerified` (z. B. Bestands-User nach Debug-Migration) |
| `free_period_start` | Timestamp? | UserModel |
| `hasCompletedProfile` | bool | UserModel |
| `isPro` | bool | UserModel, SubscriptionSync |
| `lastLogin` | Timestamp? | UserModel, Login |
| `lastPaymentProvider` | string | UserModel |
| `last_viewed_wishes_at` | Timestamp? | main_main_page (Admin) |
| `loginCount` | int? | UserModel, Login |
| `mic_sensitivity` | number | ShazamService, AudioSettingsCard |
| `myReferralCode` | string? | ReferralService (eigener Code) |
| `photoURL` | string? | UserModel |
| `planType` | string | UserModel, SubscriptionSync (free, pro, trial) |
| `platform` | string? | AppUpdateService (Legacy), Benutzerverwaltung |
| `previousLogin` | Timestamp? | Login |
| `proUntil` | Timestamp? | UserModel, SubscriptionSync |
| `realName` | string? | UserModel, Profil |
| `recognition_threshold` | number | ShazamService, AudioSettingsCard |
| `redeemedCode` | string? | ReferralService (eingelöster Code) |
| `referralCode` | string | UserModel (Referral-Code) |
| `referralDate` | Timestamp? | ReferralService |
| `referredBy` | string? | ReferralService (UID des Werbers) |
| `role_id` | string? | UserModel, Login, Benutzerverwaltung (verweist auf roles/{id}) |
| `shazam_scan_interval_seconds` | number? | ShazamService |
| `show_greeting_translations` | bool? | TranslationSettingsService |
| `smart_threshold_enabled` | bool? | ShazamService, AudioSettingsCard |
| `trialUntil` | Timestamp? | UserModel, SubscriptionSync |
| `trialUsed` | bool | UserModel, SubscriptionSync |

### Zusätzlich gelesen (Profil/Login), evtl. nur in einzelnen Docs

| Key | Verwendung |
|-----|------------|
| `djLogoUrl` / `dj_logo_url` | Logo-URL (Login Preload) |

---

## Subcollections unter users/{uid}

- **history** – Zahlungshistorie (z. B. timestamp, amountGross, type, source)
- **settings** – z. B. results_per_page (eigenes Dokument)

---

## Echte Struktur aus Firestore anzeigen

**Hinweis:** Firebase CLI ist eingeloggt und das Projekt (dj-ollerganove) ist erreichbar (z. B. `firebase firestore:indexes`). Die CLI bietet aber **keinen** Befehl zum Auslesen von Firestore-Dokumenten (nur für Realtime Database). Ohne gcloud oder Service-Account-Key können User-Dokumente von der Kommandozeile aus nicht gelistet werden.

**Option 1 – Firebase Console**  
1. [Firebase Console](https://console.firebase.google.com) → Projekt **dj-ollerganove** → Firestore.  
2. Collection **users** öffnen, ein DJ-Dokument und ein Gast-Dokument öffnen.  
3. Alle angezeigten Feldnamen sind die physisch gespeicherten Keys.

**Option 2 – Debug-Ausgabe in der App**  
In der App einmal (z. B. in der Benutzerverwaltung oder im Profil) ein User-Dokument laden und alle Keys ausgeben:

```dart
final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
if (doc.exists) {
  final data = doc.data()!;
  final keys = data.keys.toList()..sort();
  debugPrint('Users doc keys: $keys');
  for (final k in keys) {
    final v = data[k];
    debugPrint('  $k: ${v.runtimeType}');
  }
}
```

**Option 3 – Hilfs-Screen (einmalig)**  
Siehe `lib/utils/debug_users_doc_keys.dart` – dort kann ein Admin einen Nutzer wählen und sich die Keys + Typen des zugehörigen User-Dokuments anzeigen lassen (oder du führst den obigen Snippet in einem bestehenden Admin-Screen aus).

---

*Stand: aus Code-Scan; DJ- und Gast-Docs können je nach Nutzung unterschiedliche Felder haben (z. B. hat ein Gast oft kein role_id oder kein planType).*
