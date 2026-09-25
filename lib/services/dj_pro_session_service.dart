import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import 'pro_free_check.dart';

/// Session-basierter Pro-Status: eine Quelle für Header, Limits und Feature-Sperren.
class SessionProStatus {
  final bool isActive;
  final DateTime? proUntil;
  final bool isLifetime;
  final ProFreeStatus status;
  final bool isDjB2b;

  const SessionProStatus({
    required this.isActive,
    this.proUntil,
    this.isLifetime = false,
    required this.status,
    this.isDjB2b = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SessionProStatus &&
        isActive == other.isActive &&
        proUntil == other.proUntil &&
        isLifetime == other.isLifetime &&
        status == other.status &&
        isDjB2b == other.isDjB2b;
  }

  @override
  int get hashCode => Object.hash(isActive, proUntil, isLifetime, status, isDjB2b);
}

/// Zentrale Echtzeit-Session: Pro / Trial / Free — überall dieselbe Wahrheit.
///
/// Aktualisiert durch [UserService] bei jedem `users/{uid}`-Snapshot und beim
/// lokalen Trial-Ablauf-Timer. UI und Guards lesen nur hier (nicht `isPro` allein).
class DjProSessionService {
  DjProSessionService._();

  static final DjProSessionService instance = DjProSessionService._();

  final ValueNotifier<SessionProStatus?> sessionProStatus =
      ValueNotifier<SessionProStatus?>(null);

  /// Aktives Pro/Trial/Life laut [ProFreeCheck] (inkl. Store-Pro-Kulanz, **ohne** Trial-Kulanz).
  bool get isProActive => sessionProStatus.value?.isActive == true;

  /// Free-DJ für Feature-Sperren und Limits — Gegenstück zu [isProActive].
  bool get isFreeDj => !isProActive;

  ProFreeStatus get status =>
      sessionProStatus.value?.status ?? ProFreeStatus.FREE;

  void applyFromUser(
    UserModel user,
    List<Map<String, dynamic>> historyEntries,
  ) {
    final result = ProFreeCheck.determineStatus(
      user: user,
      historyEntries: historyEntries,
    );
    final next = SessionProStatus(
      isActive: result.isActive,
      proUntil: result.displayDate,
      isLifetime: result.status == ProFreeStatus.PRO_LIFE,
      status: result.status,
      isDjB2b: result.status == ProFreeStatus.DJ_B2B,
    );
    if (sessionProStatus.value == next) return;
    sessionProStatus.value = next;
  }

  void clear() {
    sessionProStatus.value = null;
  }
}
