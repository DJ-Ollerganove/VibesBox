import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Modell für User-Dokumente in der Firestore users-Collection (users/{uid}).
class UserModel {
  final String id;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final String? roleId;
  /// Rollenname aus dem User-Dokument (z. B. 'admin', 'dj', 'guest') für RBAC.
  final String? role;
  final bool? admin;
  final Timestamp? createdAt;
  final Timestamp? lastLogin;
  final int? loginCount;
  /// Eingeloggter Gast: abgeschickte Musikwünsche (Firestore: guestWishesSubmittedCount).
  final int guestWishesSubmittedCount;
  // Pro-/Subscription-Felder
  final Timestamp? proUntil;
  final bool isPro;
  final String referralCode;
  final String lastPaymentProvider;
  // 2-Tage-Trial
  final Timestamp? trialUntil;
  final bool trialUsed;
  // Free-DJ / Plan
  final String planType;
  final DateTime? freePeriodStart;
  // Pflicht-Profil (DJ)
  final String? realName;
  final String? country;
  final DateTime? birthDate;
  final bool hasCompletedProfile;
  // Alternative E-Mail für Kontaktformular
  final String? alternativeEmail;
  final bool useAlternativeEmail;
  /// Telefonnummer
  final String? phoneNumber;
  // PDF-Anzeige-Optionen (beim Export)
  final bool showLocationOnPdf;
  final bool showPhoneOnPdf;
  final bool showEmailOnPdf;
  final bool showAltEmailOnPdf;
  /// Free-DJ: Perioden-Slots (Format "YYYY-MM-DD" = Stichtag period.start), in denen bereits eine Party durchgeführt wurde.
  /// Fälschungssicher: Löschen einer gestarteten Party setzt das Limit nicht zurück.
  final List<String> usedPartySlots;
  /// Musikerkennung automatisch starten (Firestore: auto_start_recognition) – nur aus UserService-Cache lesen.
  final bool autoStartRecognition;
  /// VibesBox Sync statt Mikrofon (Firestore: vibesbox_sync_enabled).
  final bool vibesboxSyncEnabled;
  /// Ob `vibesbox_sync_enabled` im User-Dokument vorkommt (fehlt ≠ false).
  final bool hasVibesboxSyncEnabledField;
  /// Aus Firestore `language` oder `locale` (Rohwert); UI normalisiert via [LocaleHelper].
  final String? preferredLanguage;
  /// DJ: lokale Push bei neuen Wünschen (Firestore: notifyNewWishes).
  final bool notifyNewWishes;
  /// DJ: VibesBox-Ton für Wunsch-Benachrichtigungen (Firestore: enableNotificationSound).
  final bool enableNotificationSound;
  /// DJ: Statusleiste / Musikerkennung (Firestore: show_status_notification; kann per Gerät überschrieben werden).
  final bool showStatusNotification;
  /// DJ: Quickstart-Onboarding-Popup wurde bestätigt (Firestore: hasSeenQuickstart).
  final bool hasSeenQuickstart;
  /// DJ: automatische Wortvorschläge in der Wunschbox (Firestore: wishbox_suggestions_enabled).
  final bool wishboxSuggestionsEnabled;
  /// DJ: Vorschlags-KI in users/{uid} gespeichert (mindestens ein song_rec_* Feld).
  final bool songRecStored;
  /// DJ: Vorschlags-KI ein/aus (Firestore: song_rec_enabled).
  final bool songRecEnabled;
  /// DJ: Musikraum (Firestore: song_rec_scope).
  final String songRecScope;
  /// DJ: Tempo-Fenster (Firestore: song_rec_tempo).
  final String songRecTempo;
  /// DJ: Bekanntheit (Firestore: song_rec_familiarity).
  final String songRecFamiliarity;
  /// DJ: gleicher Interpret in Vorschlägen erlaubt (Firestore: song_rec_same_artist).
  final bool songRecSameArtist;
  /// DJ: Anzahl Folgevorschläge 1–20 (Firestore: song_rec_count).
  final int songRecCount;
  /// DJ B2B Werber-Code (Firestore: djB2bCode).
  final String? djB2bCode;
  final int djB2bDaysAvailable;
  final int djB2bDaysPendingHold;
  final int djB2bDaysLifetimeEarned;
  final bool djB2bDaysConsumptionActive;
  final String? referredByCode;

  UserModel({
    required this.id,
    this.email,
    this.displayName,
    this.photoURL,
    this.roleId,
    this.role,
    this.admin,
    this.createdAt,
    this.lastLogin,
    this.loginCount,
    this.guestWishesSubmittedCount = 0,
    this.proUntil,
    this.isPro = false,
    String? referralCode,
    this.lastPaymentProvider = 'none',
    this.trialUntil,
    this.trialUsed = false,
    this.planType = 'free',
    this.freePeriodStart,
    this.realName,
    this.country,
    this.birthDate,
    this.hasCompletedProfile = false,
    this.alternativeEmail,
    this.useAlternativeEmail = false,
    this.phoneNumber,
    this.showLocationOnPdf = false,
    this.showPhoneOnPdf = false,
    this.showEmailOnPdf = false,
    this.showAltEmailOnPdf = false,
    List<String>? usedPartySlots,
    this.autoStartRecognition = false,
    this.vibesboxSyncEnabled = false,
    this.hasVibesboxSyncEnabledField = false,
    this.preferredLanguage,
    this.notifyNewWishes = false,
    this.enableNotificationSound = true,
    this.showStatusNotification = false,
    this.hasSeenQuickstart = false,
    this.wishboxSuggestionsEnabled = true,
    this.songRecStored = false,
    this.songRecEnabled = true,
    this.songRecScope = 'similar',
    this.songRecTempo = 'exact',
    this.songRecFamiliarity = 'hits',
    this.songRecSameArtist = true,
    this.songRecCount = 5,
    this.djB2bCode,
    this.djB2bDaysAvailable = 0,
    this.djB2bDaysPendingHold = 0,
    this.djB2bDaysLifetimeEarned = 0,
    this.djB2bDaysConsumptionActive = false,
    this.referredByCode,
  }) : referralCode = (referralCode != null && referralCode.trim().isNotEmpty)
            ? referralCode.trim()
            : '',
       usedPartySlots = usedPartySlots ?? const [];

  /// True, wenn der User Pro ist ODER sich im aktiven Trial befindet (trialUntil in der Zukunft).
  bool get isPremiumActive {
    if (isPro) return true;
    final until = trialUntil?.toDate();
    return until != null && until.isAfter(DateTime.now());
  }

  /// True, wenn proUntil im Jahr 2099 oder später liegt (Lebenslang / Pro Life).
  bool get isLifetime =>
      proUntil != null && proUntil!.toDate().year >= 2099;

  /// Aktiver DJ-B2B-Verbrauch (Pro über gesammelte Tage).
  bool get isDjB2bActive =>
      planType == 'dj_b2b' &&
      djB2bDaysConsumptionActive &&
      djB2bDaysAvailable > 0 &&
      isPro;

  /// True, wenn der User Free-DJ ist. False, wenn isLifetime oder isPremiumActive (Pro/Trial).
  bool get isFree {
    if (isLifetime || isPremiumActive) return false;
    return planType == 'free';
  }

  /// Parst usedPartySlots aus Firestore (Liste oder null). Öffentlich für LimitService.
  static List<String> parseUsedPartySlots(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
    }
    return const [];
  }

  /// Rohwert aus bekannten Sprach-Feldern im User-Dokument (inkl. ältere / alternative Keys).
  static String? parsePreferredLanguageFields(Map<String, dynamic>? data) {
    if (data == null) return null;
    final v = data['language'] ??
        data['selected_language'] ??
        data['locale'] ??
        data['language_code'] ??
        data['languageCode'] ??
        data['app_language'] ??
        data['preferred_language'];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String _songRecStringField(dynamic value, String fallback) {
    if (value is! String) return fallback;
    final t = value.trim();
    return t.isEmpty ? fallback : t;
  }

  static int _songRecCountField(dynamic value) {
    final n = value is int
        ? value
        : value is num
            ? value.round()
            : int.tryParse('$value');
    if (n == null) return 5;
    if (n < 1) return 1;
    if (n > 20) return 20;
    return n;
  }

  static String _generateReferralCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Ohne 0, O, 1, I
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// Erstellt UserModel aus Firestore-Dokument
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final refCode = data['referralCode'] as String?;
    final referralCode = (refCode != null && refCode.trim().isNotEmpty) ? refCode.trim() : '';
    return UserModel(
      id: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
      roleId: data['role_id'] as String?,
      role: data['role'] as String?,
      admin: data['admin'] == true,
      createdAt: data['created_at'] as Timestamp?,
      lastLogin: data['lastLogin'] as Timestamp?,
      loginCount: (data['loginCount'] as num?)?.toInt(),
      guestWishesSubmittedCount:
          (data['guestWishesSubmittedCount'] as num?)?.toInt() ?? 0,
      proUntil: data['proUntil'] as Timestamp?,
      isPro: data['isPro'] == true,
      referralCode: referralCode,
      lastPaymentProvider: data['lastPaymentProvider'] as String? ?? 'none',
      trialUntil: data['trialUntil'] as Timestamp?,
      trialUsed: data['trialUsed'] == true,
      planType: (data['planType'] as String?)?.trim().isNotEmpty == true
          ? (data['planType'] as String).trim().toLowerCase()
          : 'free',
      freePeriodStart: (data['free_period_start'] as Timestamp?)?.toDate(),
      realName: data['realName'] as String?,
      country: data['country'] as String?,
      birthDate: (data['birthDate'] as Timestamp?)?.toDate(),
      hasCompletedProfile: data['hasCompletedProfile'] == true,
      alternativeEmail: () {
        final s = data['alternativeEmail'] as String?;
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }(),
      useAlternativeEmail: data['useAlternativeEmail'] == true,
      phoneNumber: () {
        final s = data['phoneNumber'] as String?;
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }(),
      showLocationOnPdf: data['showLocationOnPdf'] == true,
      showPhoneOnPdf: data['showPhoneOnPdf'] == true,
      showEmailOnPdf: data['showEmailOnPdf'] == true,
      showAltEmailOnPdf: data['showAltEmailOnPdf'] == true,
      usedPartySlots: parseUsedPartySlots(data['usedPartySlots']),
      autoStartRecognition: data['auto_start_recognition'] == true,
      vibesboxSyncEnabled: data['vibesbox_sync_enabled'] == true,
      hasVibesboxSyncEnabledField: data.containsKey('vibesbox_sync_enabled'),
      preferredLanguage: parsePreferredLanguageFields(data),
      notifyNewWishes: data['notifyNewWishes'] == true,
      enableNotificationSound: data['enableNotificationSound'] != false,
      showStatusNotification: data['show_status_notification'] == true,
      hasSeenQuickstart: data['hasSeenQuickstart'] == true,
      wishboxSuggestionsEnabled:
          data['wishbox_suggestions_enabled'] != false,
      songRecStored: data.containsKey('song_rec_enabled') ||
          data.containsKey('song_rec_scope') ||
          data.containsKey('song_rec_tempo') ||
          data.containsKey('song_rec_familiarity') ||
          data.containsKey('song_rec_same_artist') ||
          data.containsKey('song_rec_count'),
      songRecEnabled: data['song_rec_enabled'] != false,
      songRecScope: _songRecStringField(data['song_rec_scope'], 'similar'),
      songRecTempo: _songRecStringField(data['song_rec_tempo'], 'exact'),
      songRecFamiliarity:
          _songRecStringField(data['song_rec_familiarity'], 'hits'),
      songRecSameArtist: data['song_rec_same_artist'] != false,
      songRecCount: _songRecCountField(data['song_rec_count']),
      djB2bCode: () {
        final s = data['djB2bCode'] as String?;
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }(),
      djB2bDaysAvailable: (data['djB2bDaysAvailable'] as num?)?.toInt() ?? 0,
      djB2bDaysPendingHold: (data['djB2bDaysPendingHold'] as num?)?.toInt() ?? 0,
      djB2bDaysLifetimeEarned:
          (data['djB2bDaysLifetimeEarned'] as num?)?.toInt() ?? 0,
      djB2bDaysConsumptionActive: data['djB2bDaysConsumptionActive'] == true,
      referredByCode: () {
        final s = data['referredByCode'] as String?;
        if (s == null) return null;
        final t = s.trim();
        return t.isEmpty ? null : t;
      }(),
    );
  }

  /// Konvertiert UserModel zu Firestore-Daten (für merge/set)
  Map<String, dynamic> toFirestore() {
    return {
      if (email != null) 'email': email,
      if (displayName != null) 'displayName': displayName,
      if (photoURL != null) 'photoURL': photoURL,
      if (roleId != null) 'role_id': roleId,
      if (role != null) 'role': role,
      if (admin != null) 'admin': admin,
      if (createdAt != null) 'created_at': createdAt,
      if (lastLogin != null) 'lastLogin': lastLogin,
      if (loginCount != null) 'loginCount': loginCount,
      'proUntil': proUntil,
      'isPro': isPro,
      'referralCode': referralCode.isEmpty ? _generateReferralCode() : referralCode,
      'lastPaymentProvider': lastPaymentProvider,
      'trialUntil': trialUntil,
      'trialUsed': trialUsed,
      'planType': planType,
      if (freePeriodStart != null) 'free_period_start': Timestamp.fromDate(freePeriodStart!),
      if (realName != null) 'realName': realName,
      if (country != null) 'country': country,
      if (birthDate != null) 'birthDate': Timestamp.fromDate(birthDate!),
      'hasCompletedProfile': hasCompletedProfile,
      if (alternativeEmail != null && alternativeEmail!.isNotEmpty) 'alternativeEmail': alternativeEmail,
      'useAlternativeEmail': useAlternativeEmail,
      if (phoneNumber != null && phoneNumber!.isNotEmpty) 'phoneNumber': phoneNumber,
      'showLocationOnPdf': showLocationOnPdf,
      'showPhoneOnPdf': showPhoneOnPdf,
      'showEmailOnPdf': showEmailOnPdf,
      'showAltEmailOnPdf': showAltEmailOnPdf,
      if (usedPartySlots.isNotEmpty) 'usedPartySlots': usedPartySlots,
      'auto_start_recognition': autoStartRecognition,
      if (hasVibesboxSyncEnabledField)
        'vibesbox_sync_enabled': vibesboxSyncEnabled,
      'notifyNewWishes': notifyNewWishes,
      'enableNotificationSound': enableNotificationSound,
      'show_status_notification': showStatusNotification,
      'hasSeenQuickstart': hasSeenQuickstart,
    };
  }

  /// Gleichheit nach Firestore-Daten (verhindert unnötige ValueNotifier-Updates bei identischen Snapshots).
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        id == other.id &&
        email == other.email &&
        displayName == other.displayName &&
        photoURL == other.photoURL &&
        roleId == other.roleId &&
        role == other.role &&
        admin == other.admin &&
        createdAt == other.createdAt &&
        lastLogin == other.lastLogin &&
        loginCount == other.loginCount &&
        guestWishesSubmittedCount == other.guestWishesSubmittedCount &&
        proUntil == other.proUntil &&
        isPro == other.isPro &&
        referralCode == other.referralCode &&
        lastPaymentProvider == other.lastPaymentProvider &&
        trialUntil == other.trialUntil &&
        trialUsed == other.trialUsed &&
        planType == other.planType &&
        freePeriodStart == other.freePeriodStart &&
        realName == other.realName &&
        country == other.country &&
        birthDate == other.birthDate &&
        hasCompletedProfile == other.hasCompletedProfile &&
        alternativeEmail == other.alternativeEmail &&
        useAlternativeEmail == other.useAlternativeEmail &&
        phoneNumber == other.phoneNumber &&
        showLocationOnPdf == other.showLocationOnPdf &&
        showPhoneOnPdf == other.showPhoneOnPdf &&
        showEmailOnPdf == other.showEmailOnPdf &&
        showAltEmailOnPdf == other.showAltEmailOnPdf &&
        listEquals(usedPartySlots, other.usedPartySlots) &&
        autoStartRecognition == other.autoStartRecognition &&
        vibesboxSyncEnabled == other.vibesboxSyncEnabled &&
        hasVibesboxSyncEnabledField == other.hasVibesboxSyncEnabledField &&
        preferredLanguage == other.preferredLanguage &&
        notifyNewWishes == other.notifyNewWishes &&
        enableNotificationSound == other.enableNotificationSound &&
        showStatusNotification == other.showStatusNotification &&
        hasSeenQuickstart == other.hasSeenQuickstart &&
        wishboxSuggestionsEnabled == other.wishboxSuggestionsEnabled &&
        songRecStored == other.songRecStored &&
        songRecEnabled == other.songRecEnabled &&
        songRecScope == other.songRecScope &&
        songRecTempo == other.songRecTempo &&
        songRecFamiliarity == other.songRecFamiliarity &&
        songRecSameArtist == other.songRecSameArtist &&
        songRecCount == other.songRecCount;
  }

  @override
  int get hashCode => Object.hashAll([
        id,
        email,
        displayName,
        photoURL,
        roleId,
        role,
        admin,
        createdAt,
        lastLogin,
        loginCount,
        guestWishesSubmittedCount,
        proUntil,
        isPro,
        referralCode,
        lastPaymentProvider,
        trialUntil,
        trialUsed,
        planType,
        freePeriodStart,
        realName,
        country,
        birthDate,
        hasCompletedProfile,
        alternativeEmail,
        useAlternativeEmail,
        phoneNumber,
        showLocationOnPdf,
        showPhoneOnPdf,
        showEmailOnPdf,
        showAltEmailOnPdf,
        Object.hashAll(usedPartySlots),
        autoStartRecognition,
        vibesboxSyncEnabled,
        hasVibesboxSyncEnabledField,
        preferredLanguage,
        notifyNewWishes,
        enableNotificationSound,
        showStatusNotification,
        hasSeenQuickstart,
        wishboxSuggestionsEnabled,
        songRecStored,
        songRecEnabled,
        songRecScope,
        songRecTempo,
        songRecFamiliarity,
        songRecSameArtist,
        songRecCount,
      ]);

  /// Erstellt eine Kopie mit geänderten Feldern
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoURL,
    String? roleId,
    String? role,
    bool? admin,
    Timestamp? createdAt,
    Timestamp? lastLogin,
    int? loginCount,
    int? guestWishesSubmittedCount,
    Timestamp? proUntil,
    bool? isPro,
    String? referralCode,
    String? lastPaymentProvider,
    Timestamp? trialUntil,
    bool? trialUsed,
    String? planType,
    DateTime? freePeriodStart,
    String? realName,
    String? country,
    DateTime? birthDate,
    bool? hasCompletedProfile,
    String? alternativeEmail,
    bool? useAlternativeEmail,
    String? phoneNumber,
    bool? showLocationOnPdf,
    bool? showPhoneOnPdf,
    bool? showEmailOnPdf,
    bool? showAltEmailOnPdf,
    List<String>? usedPartySlots,
    bool? autoStartRecognition,
    bool? vibesboxSyncEnabled,
    bool? hasVibesboxSyncEnabledField,
    String? preferredLanguage,
    bool? notifyNewWishes,
    bool? enableNotificationSound,
    bool? showStatusNotification,
    bool? hasSeenQuickstart,
    bool? wishboxSuggestionsEnabled,
    bool? songRecStored,
    bool? songRecEnabled,
    String? songRecScope,
    String? songRecTempo,
    String? songRecFamiliarity,
    bool? songRecSameArtist,
    int? songRecCount,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      roleId: roleId ?? this.roleId,
      role: role ?? this.role,
      admin: admin ?? this.admin,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      loginCount: loginCount ?? this.loginCount,
      guestWishesSubmittedCount:
          guestWishesSubmittedCount ?? this.guestWishesSubmittedCount,
      proUntil: proUntil ?? this.proUntil,
      isPro: isPro ?? this.isPro,
      referralCode: referralCode ?? this.referralCode,
      lastPaymentProvider: lastPaymentProvider ?? this.lastPaymentProvider,
      trialUntil: trialUntil ?? this.trialUntil,
      trialUsed: trialUsed ?? this.trialUsed,
      planType: planType ?? this.planType,
      freePeriodStart: freePeriodStart ?? this.freePeriodStart,
      realName: realName ?? this.realName,
      country: country ?? this.country,
      birthDate: birthDate ?? this.birthDate,
      hasCompletedProfile: hasCompletedProfile ?? this.hasCompletedProfile,
      alternativeEmail: alternativeEmail ?? this.alternativeEmail,
      useAlternativeEmail: useAlternativeEmail ?? this.useAlternativeEmail,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      showLocationOnPdf: showLocationOnPdf ?? this.showLocationOnPdf,
      showPhoneOnPdf: showPhoneOnPdf ?? this.showPhoneOnPdf,
      showEmailOnPdf: showEmailOnPdf ?? this.showEmailOnPdf,
      showAltEmailOnPdf: showAltEmailOnPdf ?? this.showAltEmailOnPdf,
      usedPartySlots: usedPartySlots ?? this.usedPartySlots,
      autoStartRecognition: autoStartRecognition ?? this.autoStartRecognition,
      vibesboxSyncEnabled: vibesboxSyncEnabled ?? this.vibesboxSyncEnabled,
      hasVibesboxSyncEnabledField:
          hasVibesboxSyncEnabledField ?? this.hasVibesboxSyncEnabledField,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      notifyNewWishes: notifyNewWishes ?? this.notifyNewWishes,
      enableNotificationSound:
          enableNotificationSound ?? this.enableNotificationSound,
      showStatusNotification:
          showStatusNotification ?? this.showStatusNotification,
      hasSeenQuickstart: hasSeenQuickstart ?? this.hasSeenQuickstart,
      wishboxSuggestionsEnabled:
          wishboxSuggestionsEnabled ?? this.wishboxSuggestionsEnabled,
      songRecStored: songRecStored ?? this.songRecStored,
      songRecEnabled: songRecEnabled ?? this.songRecEnabled,
      songRecScope: songRecScope ?? this.songRecScope,
      songRecTempo: songRecTempo ?? this.songRecTempo,
      songRecFamiliarity: songRecFamiliarity ?? this.songRecFamiliarity,
      songRecSameArtist: songRecSameArtist ?? this.songRecSameArtist,
      songRecCount: songRecCount ?? this.songRecCount,
    );
  }
}
