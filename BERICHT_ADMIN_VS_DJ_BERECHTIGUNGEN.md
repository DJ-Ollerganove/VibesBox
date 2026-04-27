# Bericht: Admin vs. DJ-Berechtigungen & Paywall-Zugriff

## 1. Abfragen: `admin`, `roleId`, `role_id`, `isAdmin`

### Firestore/User-Modell
| Datei | Zeile | Fundstelle | Bedeutung |
|-------|-------|------------|-----------|
| **lib/models/user_model.dart** | 11, 30–31, 68, 88, 108, 125–126 | `roleId`, `admin` als Felder; `data['role_id']`, `data['admin']` in fromFirestore/toFirestore/copyWith | UserModel hält `roleId` und `admin` (bool?) aus Firestore. |

### Admin-Check über E-Mail (nicht Firestore `admin`)
| Datei | Zeile | Fundstelle | Bedeutung |
|-------|-------|------------|-----------|
| **lib/config/app_config.dart** | 145–152 | `isAdminEmail(String? email)`, `isAdminUser(String? email)` | Admin = feste Admin-E-Mail (`adminEmail`), **nicht** `user.admin` oder `roleId`. |
| **lib/main_main_page.dart** | 382–386, 400–402, 427–429, 982–985, 1320–1323 | `isRealAdmin = user != null && AppConfig.isAdminEmail(user.email)`; `isAdminMode = isRealAdmin && (_currentViewRole == null \|\| _currentViewRole == 'Admin')` | Echter Admin nur über E-Mail; „Admin-Modus“ nur, wenn Admin-**E-Mail** und View-Rolle Admin. |
| **lib/pages/home_page.dart** | 59–62 | `isRealAdmin = user?.email == 'info@vibesbox.app'`; `isAdmin = isRealAdmin && (viewRole == null \|\| viewRole == 'Admin')` | Gleiche Logik (Admin = feste E-Mail); Anzeige HomeAdmin vs. HomeDj vs. HomeGuestPrivate. |
| **lib/pages/home_page_legacy.dart** | 255–258, 310, 318 | Wie home_page: `isRealAdmin`, `isAdmin`, `isDJ` | Legacy-Variante derselben Logik. |
| **lib/pages/wishes_page.dart** | 446–451, 977 | `_isAdminEmail(user.email)`, `_isAdmin = isAdmin` | Admin-Check für Wishes-Kontext (eigene Hilfsfunktion). |
| **lib/pages/about_page.dart** | 32, 36 | `isAdmin(user)` (von ProFeatureGuard?), `_isDjOrAdmin` | About-Text abhängig von DJ/Admin. |
| **lib/utils/admin_dj_bridge.dart** | 14, 33, 46, 57 | `isAdmin = AppConfig.isAdminEmail(user.email)`; `isAdminUser(user)` | Effektive DJ-ID: Admin nutzt `adminDjId`, sonst `user.uid`. |
| **lib/services/party_statistics_service.dart** | 34–40 | `isAdmin = AppConfig.isAdminEmail(user.email)`; bei Admin wird `adminDjId` verwendet | Statistiken für Admin-DJ-Partys. |
| **lib/services/dj_dashboard_statistics_service.dart** | 33–38 | Gleich wie party_statistics_service | Dashboard-Statistiken. |
| **lib/services/pro_feature_guard.dart** | 26–27, 47 | `isAdmin(User? user)` über E-Mail; `canUseMusicRecognition` (derzeit Test-Modus: immer true) | Pro/Admin-Check für Features. |

### Rollenname aus Firestore (`role_id` → Rolle „Admin“, „DJ“, …)
| Datei | Zeile | Fundstelle | Bedeutung |
|-------|-------|------------|-----------|
| **lib/main_main_page.dart** | 54–84 | `userModel?.roleId` → Abfrage `roles/{roleId}` → `roleName`; Setzen von `_currentViewRole` (Admin/DJ/Gast/Location) | View-Rolle kommt aus Firestore `role_id` + Rollen-Collection, **plus** Admin-E-Mail überschreibt auf Admin. |
| **lib/pages/profil_page.dart** | 1429–1432, 1494–1496, 1580–1587 | `role_id` aus User-Dokument; Anzeige „Admin“ wenn `AppConfig.isAdminEmail(user.email)`; „Admin-Status“-Zeile nur bei Admin-E-Mail | Profil zeigt Rollenname; Admin-Status nur für Admin-E-Mail. |
| **lib/pages/login_page.dart** | 177–196, 224–235 | Beim Login: `role_id` aus Firestore; bei Admin-E-Mail wird `adminRoleId` gesetzt | Rollen-Zuordnung beim Login. |

**Hinweis:** Es wird **nirgends** `user.admin == true` oder `data['admin'] == true` für Berechtigungen verwendet. Maßgeblich sind:
- **AppConfig.isAdminEmail(user.email)** (feste Admin-E-Mail)
- **role_id** → Rollenname („Admin“, „DJ“, „Location“, „Gast“) für View-Rolle und Anzeige.

---

## 2. Unterschied „Admin-Modus“ vs. „DJ-Modus“ (main_main_page / Home)

### Definition (main_main_page.dart)
- **isRealAdmin:** `user != null && AppConfig.isAdminEmail(user.email)` (nur diese eine E-Mail).
- **isAdminMode:** `isRealAdmin && (_currentViewRole == null || _currentViewRole == 'Admin')` (Admin-E-Mail **und** View-Rolle nicht „DJ“).
- **isDJMode:** `_currentViewRole == 'DJ' || (user != null && (roleName == 'DJ' || roleName == 'Location') && _currentViewRole != 'Admin')`.

Ein **normaler DJ** (andere E-Mail, `role_id` = DJ oder Location):
- `isRealAdmin` = false  
- `isAdminMode` = false  
- `isDJMode` = true  

Er bekommt **dieselbe** Bottom-Navigation/Seitenliste wie ein Admin (Indizes 0–9), **ohne** die Admin-only-Seiten (Indizes 10–13).

### Exklusiv für Admins (isAdminMode) – nur im Admin-Modus
| Ort | Zeile (ca.) | Was nur Admins sehen |
|-----|-------------|----------------------|
| **main_main_page.dart** | 1031–1040 | Zusätzliche Seiten: **Spotify** (10), **Test** (11), **Benutzer Verwaltung** (12), **Todo** (13). |
| **main_main_page.dart** | 1065 | **maxIndex:** Admin 14, sonst 10 (DJ hat Indizes 0–9). |
| **main_main_page.dart** | 1645–1692 | Im Drawer: nur bei **isAdminMode** die Menüpunkte Spotify, Test, Benutzer Verwaltung, To-Do Liste. |
| **main_main_page.dart** | 393–402, 426–429 | Timer/Streams für „neue Wünsche“ nur, wenn **isAdminMode** (im DJ-Modus bewusst aus). |

### Gemeinsam für Admin und DJ (isDJMode || isAdminMode)
- **Drawer:** Startseite, Party-Verwaltung, VibesBox, Gesperrt, History, **Profil**, Einstellungen, Social Media, Über, Beendete Partys (Indizes 0–9).
- **Profil** ist für **beide** unter Index 5 erreichbar; es gibt **keine** Einschränkung „nur Admin“ für die Profil-Seite oder die Pro-Status-Karte.

### Home-Inhalt (home_page.dart)
| Bedingung | Angezeigtes Widget |
|-----------|---------------------|
| user == null | HomeGuestPublic |
| isAdmin (Admin-E-Mail + View Admin) | HomeAdmin |
| isDJ (View „DJ“ oder Rolle DJ/Location) | HomeDj (+ optional Admin-Rollen-Umschalter nur bei isRealAdmin) |
| sonst (eingeloggt, z. B. Gast-Rolle) | HomeGuestPrivate |

- **Normaler DJ:** `isRealAdmin` = false → kein Admin-Rollen-Umschalter; er sieht **HomeDj**.
- **Admin im DJ-Modus:** `isRealAdmin` = true, viewRole = 'DJ' → **HomeDj** mit **adminRoleSwitcherBottom** (Umschalter Admin/DJ).

---

## 3. Paywall-Zugriff – wo wird die Paywall geöffnet?

| Stelle | Datei | Zeile (ca.) | Wie geöffnet | Rolle-Check? |
|--------|-------|-------------|--------------|--------------|
| **Profil – Pro-Status-Karte** | lib/pages/profil_page.dart | 972–976 | `Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallPage()))` | **Kein** Admin- oder Rollen-Check. Jeder eingeloggte User mit Profil kann tippen. |
| **Premium-Dialog** | lib/widgets/premium_feature_dialog.dart | 36–38 | `Navigator.pushNamed(context, '/paywall')` | **Kein** Admin-Check. |
| **Route** | lib/main_djog_app.dart | 164 | `'/paywall': (context) => const PaywallPage()` | Globale Route; **keine** Rolle-Prüfung. |

**Fazit Paywall:**  
Es gibt **keine** Stelle im Code, die die Paywall oder den Zugriff darauf nur für Admins freigibt. **Profil** (mit Pro-Karte) und **PremiumFeatureDialog** („VibesBox Pro holen“) sind für jeden Nutzer mit DJ/Admin-Navigation (also auch **normaler DJ**) erreichbar. Ein reiner DJ sieht:
- Im Drawer „Profil“ (Index 5),
- auf der Profil-Seite die Pro-Status-Karte und kann darauf tippen → Paywall öffnet sich.

Mögliche Gründe, warum ein DJ die Paywall „nicht sieht“ oder „nicht öffnen kann“ (ohne Code-Änderung):
- **UI:** Profil wird nicht gefunden / falscher Tab (unwahrscheinlich, da gleiche Drawer-Struktur).
- **Fehler beim Öffnen:** z. B. Route nicht verfügbar (z. B. wenn von einem anderen Navigator-Kontext aus aufgerufen), oder Crash beim Laden der Paywall/RevenueCat – dann in Logs prüfen.
- **Lokale Abweichung:** z. B. anderes Build, anderer Zweig, oder Profil-Seite in einer anderen Navigation nur für Gäste (siehe unten: Gäste haben anderes children-Set, aber **mit** Profil wenn `user != null`).

---

## 4. Alle Stellen: Unterschied „Admin-DJ“ vs. „Normal-DJ“

| # | Datei | Zeile (ca.) | Unterschied |
|---|-------|-------------|-------------|
| 1 | **main_main_page.dart** | 982–985 | **isRealAdmin** (Admin-E-Mail) vs. andere User; **isAdminMode** nur bei Admin + View „Admin“. Normal-DJ: isAdminMode false, isDJMode true. |
| 2 | **main_main_page.dart** | 988–1065 | **children:** Für Admin und DJ gleich 0–9 (inkl. Profil); **nur bei isAdminMode** zusätzlich 10–13 (Spotify, Test, Benutzerverwaltung, Todo). **maxIndex:** Admin 14, DJ 10. |
| 3 | **main_main_page.dart** | 1481 | Drawer-Bereich „DJ/Admin-Menü“: `if (isDJMode || isAdminMode)` – für **beide** sichtbar (Startseite, Party-Verwaltung, VibesBox, Gesperrt, History, Profil, Einstellungen, Social Media, Über, Beendete Partys). |
| 4 | **main_main_page.dart** | 1645–1692 | **Nur isAdminMode:** Zusätzliche Drawer-Einträge: Spotify, Test, Benutzer Verwaltung, To-Do Liste. Normal-DJ sieht diese **nicht**. |
| 5 | **main_main_page.dart** | 381–402, 426–429 | Timer/Stream für neue Wünsche nur bei **isAdminMode**. Normal-DJ hat diese Timer/Streams **nicht** (Akku-Optimierung). |
| 6 | **main_main_page.dart** | 935–939 | Update-Check: `isDJOrAdmin` (Admin-E-Mail oder roleName Admin/DJ/Location) – gleiche Logik für Admin und DJ. |
| 7 | **pages/home_page.dart** | 59–93 | **isRealAdmin** → HomeAdmin oder HomeDj **mit** adminRoleSwitcherBottom. Normal-DJ → HomeDj **ohne** Umschalter. |
| 8 | **pages/home/home_dj.dart** | 26, 32, 155, 832–833 | **currentViewRole** und **adminRoleSwitcherBottom** nur gesetzt, wenn HomePage sie übergibt (nur bei isRealAdmin). Normal-DJ: adminRoleSwitcherBottom = null. |
| 9 | **pages/home/home_admin.dart** | 17–32, 488–491, 567–568 | Wird **nur** bei **isAdmin** (Admin-E-Mail + View Admin) gezeigt. Enthält Admin-Statistiken, LoginCounterCard, HomeAdminRoleSwitcherCard. Normal-DJ sieht **HomeAdmin** nie. |
| 10 | **utils/admin_dj_bridge.dart** | 9–65 | **Admin:** getEffectiveDjId kann **adminDjId** zurückgeben (im DJ-Modus). **Normal-DJ:** immer **user.uid**. |
| 11 | **services/party_statistics_service.dart** | 34–40 | Bei **Admin:** effektive DJ-ID = adminDjId. Bei **Normal-DJ:** user.uid. |
| 12 | **services/dj_dashboard_statistics_service.dart** | 33–40 | Wie party_statistics_service. |
| 13 | **config/app_config.dart** | 39–41, 70–134, 145–160 | **adminDjId**, **adminEmail**, **isAdminEmail** – nur für eine feste Admin-E-Mail. getEffectiveDjId: Admin → adminDjId. |
| 14 | **pages/profil_page.dart** | 1432–1433, 1494–1496, 1580–1587 | Anzeige „Admin“-Rolle und „Admin-Status“-Zeile nur, wenn **AppConfig.isAdminEmail(user.email)**. Normal-DJ sieht normale Rollenbezeichnung, keine Admin-Status-Zeile. |
| 15 | **pages/login_page.dart** | 227–235 | Beim Login: Bei **Admin-E-Mail** wird `role_id` auf Admin-Rolle gesetzt. Sonst geladene role_id. |

---

## 5. Kurzfassung

- **Admin-Erkennung:** Über **AppConfig.isAdminEmail(user.email)** (feste E-Mail), **nicht** über Firestore `user.admin` oder `roleId == 'admin'`.
- **View-Rolle:** Aus Firestore `role_id` + Rollen-Collection („Admin“, „DJ“, „Location“, „Gast“); Admin-E-Mail kann View auf Admin erzwingen.
- **Exklusiv Admin (isAdminMode):** Zusätzliche Seiten (Spotify, Test, Benutzerverwaltung, Todo), entsprechende Drawer-Einträge, Timer/Streams für neue Wünsche; HomeAdmin nur für Admin-View.
- **Gemeinsam Admin & DJ:** Drawer 0–9 inkl. **Profil** und alle Kauf-/Pro-Inhalte; **Paywall** wird aus Profil (Pro-Karte) und Premium-Dialog geöffnet – **ohne** Admin-Check.
- **Paywall für normalen DJ:** Im aktuellen Code ist die Paywall für **normalen DJ** zugänglich (Profil Index 5, Pro-Karte tippen). Wenn ein DJ sie „nicht sieht“ oder „nicht öffnen kann“, liegt es nicht an einer Admin-vs.-DJ-Berechtigungslogik im Code, sondern z. B. an Navigation, Fehlern (RevenueCat/Route) oder Build/Umgebung.
