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
  /// Aus Firestore `language` oder `locale` (Rohwert); UI normalisiert via [LocaleHelper].
  final String? preferredLanguage;

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
    this.preferredLanguage,
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

  /// Rohwert aus `language`, `selected_language` oder `locale` im User-Dokument.
  static String? parsePreferredLanguageFields(Map<String, dynamic>? data) {
    if (data == null) return null;
    final v = data['language'] ?? data['selected_language'] ?? data['locale'];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
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
      preferredLanguage: parsePreferredLanguageFields(data),
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
        preferredLanguage == other.preferredLanguage;
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
        preferredLanguage,
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
    String? preferredLanguage,
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
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}
