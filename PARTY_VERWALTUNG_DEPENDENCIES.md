# 🌳 Party-Verwaltungsseite: Abhängigkeits-Baumstruktur

```
party_verwaltung_page.dart
│
├── 📦 EXTERNE PACKAGES
│   ├── cloud_firestore (Firebase Firestore)
│   ├── firebase_auth (Firebase Authentication)
│   ├── flutter/material (Flutter UI Framework)
│   └── dart:async (Timer, StreamController)
│
├── 📄 EIGENE MODULE (Settings)
│   ├── settings_party_edit_dialog.dart
│   │   ├── cloud_firestore (Firestore Updates)
│   │   ├── flutter/material
│   │   ├── l10n/app_localizations.dart
│   │   └── utils/formatting_utils.dart
│   │
│   ├── settings_party_card_widget.dart
│   │   ├── flutter/material
│   │   ├── dart:async (Stream<DateTime>)
│   │   ├── l10n/app_localizations.dart
│   │   ├── widgets/party_qr_code_dialog.dart
│   │   └── settings_party_countdown_helper.dart
│   │       └── l10n/app_localizations.dart
│   │
│   ├── settings_party_countdown_helper.dart
│   │   ├── flutter/material
│   │   └── l10n/app_localizations.dart
│   │
│   └── settings_party_delete_dialog.dart
│       ├── cloud_firestore (Firestore Delete)
│       ├── flutter/material
│       ├── l10n/app_localizations.dart
│       └── services/active_party_service.dart
│           └── (clearSeenWishIds)
│
├── 📄 PAGES (Navigation)
│   ├── pages/neue_party_page.dart
│   │   └── (Navigator.push → Neue Party erstellen)
│   │
│   └── pages/beendete_partys_page.dart
│       └── (Navigator.push → Beendete Partys anzeigen)
│
├── 🎨 WIDGETS (UI-Komponenten)
│   ├── widgets/custom_page_header.dart
│   │   └── (Titel-Leiste mit Icon)
│   │
│   ├── widgets/sticky_pagination_layout.dart
│   │   └── (Layout-Wrapper)
│   │
│   └── widgets/party_qr_code_dialog.dart
│       └── (QR-Code Anzeige-Dialog)
│
├── 🛠️ UTILITIES
│   ├── utils/formatting_utils.dart
│   │   └── FormattingUtils.formatDateTime()
│   │
│   └── utils/ui_constants.dart
│       └── UIConstants.kFooterPadding
│
├── 🌐 LOKALISIERUNG
│   └── l10n/app_localizations.dart
│       ├── party_management_title
│       ├── party_status_upcoming
│       ├── party_status_running
│       ├── party_status_ended
│       ├── party_countdown_in
│       ├── party_countdown_still
│       ├── party_edit
│       ├── party_delete
│       ├── party_start
│       ├── party_end
│       ├── no_active_parties
│       ├── party_ended
│       ├── new_party
│       └── (weitere Übersetzungen...)
│
├── ⚙️ SERVICES
│   └── services/active_party_service.dart
│       └── ActivePartyService.clearSeenWishIds()
│
├── ⚙️ CONFIG
│   └── config/app_config.dart
│       └── (App-Konfiguration)
│
└── 🔄 INTERNE LOGIK (party_verwaltung_page.dart)
    │
    ├── State-Management
    │   ├── StreamController<DateTime> (_timeController)
    │   ├── Timer (_timeTimer) → Aktualisierung alle 1 Minute
    │   └── Timer (_refreshTimer) → Rebuild alle 10 Sekunden
    │
    ├── Methoden
    │   ├── _formatDateTime()
    │   │   └── FormattingUtils.formatDateTime()
    │   │
    │   ├── _getPartyStatus()
    │   │   └── AppLocalizations (Status-Text)
    │   │
    │   └── _getPartyStatusColor()
    │       └── Colors (blue/green/grey)
    │
    └── UI-Build
        ├── CustomPageHeader
        ├── StickyPaginationLayout
        ├── StreamBuilder<QuerySnapshot>
        │   └── FirebaseFirestore
        │       └── collection('parties')
        │           └── where('created_by', isEqualTo: user.uid)
        │
        ├── ListView.builder
        │   └── SettingsPartyCard (für jede Party)
        │       ├── onEdit → SettingsPartyEditDialog.show()
        │       ├── onDelete → SettingsPartyDeleteDialog.confirm()
        │       └── onQrCode → PartyQrCodeDialog.show()
        │
        ├── StreamBuilder (Beendete Partys Button)
        └── ElevatedButton (Neue Party)
```

## 🔗 Datenfluss

### 1. **Party-Liste laden**
```
FirebaseAuth.currentUser
  ↓
FirebaseFirestore.collection('parties')
  ↓
.where('created_by', isEqualTo: user.uid)
  ↓
StreamBuilder → QuerySnapshot
  ↓
Filter & Sort → activeParties
  ↓
ListView.builder → SettingsPartyCard
```

### 2. **Party bearbeiten**
```
SettingsPartyCard.onEdit()
  ↓
SettingsPartyEditDialog.show()
  ↓
FirebaseFirestore.update()
  ↓
SnackBar (Erfolg/Fehler)
```

### 3. **Party löschen**
```
SettingsPartyCard.onDelete()
  ↓
SettingsPartyDeleteDialog.confirm()
  ↓
ActivePartyService.clearSeenWishIds()
  ↓
FirebaseFirestore.delete()
  ↓
SnackBar (Erfolg/Fehler)
```

### 4. **Countdown aktualisieren**
```
_timeStream (Timer alle 1 Minute)
  ↓
SettingsPartyCard (StreamBuilder)
  ↓
SettingsPartyCountdownHelper.formatCountdown()
  ↓
UI Update (Live)
```

## 📊 Abhängigkeits-Statistik

- **Externe Packages**: 4
- **Eigene Module**: 4 (Settings-*)
- **Pages**: 2
- **Widgets**: 3
- **Utilities**: 2
- **Services**: 1
- **Lokalisierung**: 1 (mit ~20+ Übersetzungen)

## 🎯 Kern-Funktionalitäten

1. **Party-Liste anzeigen** (Firestore Stream)
2. **Party bearbeiten** (Dialog + Firestore Update)
3. **Party löschen** (Dialog + Firestore Delete)
4. **QR-Code anzeigen** (Dialog)
5. **Countdown live** (Timer + Stream)
6. **Navigation** (Neue Party, Beendete Partys)
