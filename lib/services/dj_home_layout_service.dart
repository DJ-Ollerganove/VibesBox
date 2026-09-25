import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../l10n/app_localizations.dart';
import 'dj_pro_session_service.dart';

/// IDs der konfigurierbaren DJ-Startseiten-Widgets.
abstract final class DjHomeWidgetId {
  static const welcome = 'welcome';
  static const partyStatus = 'party_status';
  static const statsLive = 'stats_live';
  static const statsLast = 'stats_last';
  static const statsUpcoming = 'stats_upcoming';
  static const statsLogins = 'stats_logins';
  static const statsTotal = 'stats_total';
  static const partyCarousel = 'party_carousel';
  static const partyHistoryCarousel = 'party_history_carousel';
  static const historyRecent = 'history_recent';
  static const openWishesCount = 'open_wishes_count';
  static const preWishesCount = 'pre_wishes_count';
  static const proTrialBanner = 'pro_trial_banner';
  static const proPromotion = 'pro_promotion';
  static const proComparison = 'pro_comparison';

  /// Entfernte Widgets (Migration aus gespeicherten Layouts).
  static const _deprecated = {
    'next_party_countdown',
    'quick_actions',
    'wishes_recent',
  };

  static const all = [
    welcome,
    partyStatus,
    statsLive,
    statsLast,
    statsUpcoming,
    statsLogins,
    statsTotal,
    partyCarousel,
    partyHistoryCarousel,
    historyRecent,
    openWishesCount,
    preWishesCount,
    proTrialBanner,
    proPromotion,
    proComparison,
  ];

  /// Begrüßung: fest oben, nie im Bearbeiten-Fenster.
  static const Set<String> fixedOutsideEdit = {welcome};

  /// Free-only Widgets (Pro/Pro-Life: weder Startseite noch Bearbeiten).
  static const Set<String> freeOnlyWidgets = {
    proPromotion,
    proTrialBanner,
    proComparison,
  };

  static bool showProTrialBannerOnHome({
    required bool isFreeDj,
    required bool trialUsed,
  }) =>
      isFreeDj && !trialUsed;

  static bool showProComparisonOnHome(bool isFreeDj) => isFreeDj;

  /// Nicht per Schalter deaktivierbar (Free: immer an wenn sichtbar).
  static bool isToggleLocked(String id) =>
      id == proPromotion ||
      id == proTrialBanner ||
      id == statsLogins;

  /// Widgets, die im Bearbeiten-Fenster nicht erscheinen.
  static Set<String> hiddenInEditSheet({
    required bool isFreeDj,
    required bool trialUsed,
  }) {
    final hidden = Set<String>.from(fixedOutsideEdit);
    if (!isFreeDj) {
      hidden.addAll(freeOnlyWidgets);
    } else if (trialUsed) {
      hidden.add(proTrialBanner);
    }
    return hidden;
  }

  static String label(AppLocalizations l, String id) {
    switch (id) {
      case welcome:
        return l.dj_home_widget_welcome;
      case partyStatus:
        return l.dj_home_widget_party_status;
      case statsLive:
        return l.dj_home_widget_stats_live;
      case statsLast:
        return l.dj_home_widget_stats_last;
      case statsUpcoming:
        return l.dj_home_widget_stats_upcoming;
      case statsLogins:
        return l.dj_home_widget_stats_logins;
      case statsTotal:
        return l.dj_home_widget_stats_total;
      case partyCarousel:
        return l.dj_home_widget_party_carousel;
      case partyHistoryCarousel:
        return l.dj_home_widget_party_history_carousel;
      case historyRecent:
        return l.dj_home_widget_history_recent;
      case openWishesCount:
        return l.dj_home_widget_open_wishes_count;
      case preWishesCount:
        return l.dj_home_widget_pre_wishes_count;
      case proTrialBanner:
        return l.dj_home_widget_pro_trial_banner;
      case proPromotion:
        return l.dj_home_widget_pro_promotion;
      case proComparison:
        return l.dj_home_widget_pro_comparison;
      default:
        return id;
    }
  }

  /// Graue Unterzeile im Bearbeiten-Fenster (optional).
  static String? editSubtitle(AppLocalizations l, String id) {
    switch (id) {
      case partyStatus:
        return l.dj_home_widget_party_status_sub;
      case statsLive:
        return l.dj_home_widget_stats_live_sub;
      case preWishesCount:
        return l.dj_home_widget_pre_wishes_count_sub;
      default:
        return null;
    }
  }
}

/// Gespeichertes Layout: Reihenfolge + Sichtbarkeit pro Widget.
class DjHomeLayoutConfig {
  const DjHomeLayoutConfig({
    required this.order,
    required this.enabled,
  });

  final List<String> order;
  final Map<String, bool> enabled;

  List<String> get visibleOrder =>
      order.where((id) => enabled[id] == true).toList(growable: false);

  /// Modulare Widgets (ohne feste Begrüßung) für die Startseite.
  List<String> modularVisibleOrderForSession({
    required bool isFreeDj,
    required bool trialUsed,
    bool showPreWishesWidget = false,
    bool showLiveStatsWidget = false,
  }) =>
      order.where((id) {
        if (DjHomeWidgetId.fixedOutsideEdit.contains(id)) return false;
        if (id == DjHomeWidgetId.statsLogins) return true;
        if (enabled[id] != true) return false;
        if (id == DjHomeWidgetId.preWishesCount && !showPreWishesWidget) {
          return false;
        }
        if (id == DjHomeWidgetId.statsLive && !showLiveStatsWidget) {
          return false;
        }
        if (id == DjHomeWidgetId.proPromotion && !isFreeDj) return false;
        if (id == DjHomeWidgetId.proTrialBanner &&
            !DjHomeWidgetId.showProTrialBannerOnHome(
              isFreeDj: isFreeDj,
              trialUsed: trialUsed,
            )) {
          return false;
        }
        if (id == DjHomeWidgetId.proComparison &&
            !DjHomeWidgetId.showProComparisonOnHome(isFreeDj)) {
          return false;
        }
        return true;
      }).toList(growable: false);

  /// Reihenfolge im Bearbeiten-Fenster.
  List<String> editableOrderForSession({
    required bool isFreeDj,
    required bool trialUsed,
  }) {
    final hidden =
        DjHomeWidgetId.hiddenInEditSheet(isFreeDj: isFreeDj, trialUsed: trialUsed);
    return order.where((id) => !hidden.contains(id)).toList(growable: false);
  }

  /// Nach Wechsel Pro → Free: Pro-Werbung als erstes modulares Widget.
  DjHomeLayoutConfig withProPromotionPinnedToTop() {
    final o = List<String>.from(order);
    o.remove(DjHomeWidgetId.proPromotion);
    final welcomeIdx = o.indexOf(DjHomeWidgetId.welcome);
    final insertAt = welcomeIdx >= 0 ? welcomeIdx + 1 : 0;
    o.insert(insertAt.clamp(0, o.length), DjHomeWidgetId.proPromotion);
    final en = Map<String, bool>.from(enabled);
    en[DjHomeWidgetId.proPromotion] = true;
    return copyWith(order: o, enabled: en);
  }

  /// Speichern: Free-Widgets mit festem An-Status; Login-Statistik immer an.
  DjHomeLayoutConfig normalizedForSave({
    required bool isFreeDj,
    required bool trialUsed,
  }) {
    final en = Map<String, bool>.from(enabled);
    en[DjHomeWidgetId.statsLogins] = true;
    if (!isFreeDj) return copyWith(enabled: en);
    en[DjHomeWidgetId.proPromotion] = true;
    if (!trialUsed) {
      en[DjHomeWidgetId.proTrialBanner] = true;
    }
    return copyWith(enabled: en);
  }

  /// Drag & Drop im Bearbeiten-Fenster (sichtbare Zeilen).
  DjHomeLayoutConfig withEditableReorder({
    required bool isFreeDj,
    required bool trialUsed,
    required int oldIndex,
    required int newIndex,
  }) {
    final hidden =
        DjHomeWidgetId.hiddenInEditSheet(isFreeDj: isFreeDj, trialUsed: trialUsed);
    final editable = order.where((id) => !hidden.contains(id)).toList();
    final work = List<String>.from(editable);
    var target = newIndex;
    if (target > oldIndex) target--;
    final item = work.removeAt(oldIndex);
    work.insert(target, item);

    final merged = <String>[];
    var ei = 0;
    for (final id in order) {
      if (hidden.contains(id)) {
        merged.add(id);
      } else {
        merged.add(work[ei++]);
      }
    }
    return copyWith(order: merged);
  }

  DjHomeLayoutConfig copyWith({
    List<String>? order,
    Map<String, bool>? enabled,
  }) =>
      DjHomeLayoutConfig(
        order: order ?? List<String>.from(this.order),
        enabled: enabled ?? Map<String, bool>.from(this.enabled),
      );

  Map<String, dynamic> toFirestore() => {
        'widget_order': order,
        'widget_enabled': enabled,
      };

  static DjHomeLayoutConfig defaults() {
    final enabled = {
      for (final id in DjHomeWidgetId.all) id: true,
    };
    return DjHomeLayoutConfig(
      order: List<String>.from(DjHomeWidgetId.all),
      enabled: enabled,
    );
  }

  static DjHomeLayoutConfig? fromFirestore(Map<String, dynamic>? data) {
    if (data == null) return null;
    final rawOrder = data['widget_order'];
    final rawEnabled = data['widget_enabled'];
    if (rawOrder is! List || rawEnabled is! Map) return null;

    final order = <String>[];
    for (final e in rawOrder) {
      final id = e?.toString();
      if (id == null ||
          DjHomeWidgetId._deprecated.contains(id) ||
          !DjHomeWidgetId.all.contains(id) ||
          order.contains(id)) {
        continue;
      }
      order.add(id);
    }
    for (final id in DjHomeWidgetId.all) {
      if (!order.contains(id)) order.add(id);
    }

    final enabled = <String, bool>{};
    for (final id in DjHomeWidgetId.all) {
      final v = rawEnabled[id];
      enabled[id] = v is bool ? v : defaults().enabled[id] ?? false;
    }
    enabled[DjHomeWidgetId.statsLogins] = true;
    return DjHomeLayoutConfig(order: order, enabled: enabled);
  }
}

/// Lädt/speichert DJ-Startseiten-Layout unter `users/{uid}/settings/dj_home_layout`.
class DjHomeLayoutService {
  DjHomeLayoutService._();

  static final DjHomeLayoutService instance = DjHomeLayoutService._();

  final ValueNotifier<DjHomeLayoutConfig> configNotifier =
      ValueNotifier(DjHomeLayoutConfig.defaults());

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('dj_home_layout');

  void startForUid(String uid) {
    if (_uid == uid && _sub != null) return;
    _sub?.cancel();
    _uid = uid;
    _sub = _ref(uid).snapshots().listen((snap) {
      final parsed = DjHomeLayoutConfig.fromFirestore(snap.data());
      configNotifier.value = parsed ?? DjHomeLayoutConfig.defaults();
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _uid = null;
    configNotifier.value = DjHomeLayoutConfig.defaults();
  }

  Future<void> save(
    DjHomeLayoutConfig config, {
    bool? isFreeDj,
    bool trialUsed = true,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? _uid;
    if (uid == null) return;
    final free = isFreeDj ?? !DjProSessionService.instance.isProActive;
    final normalized = config.normalizedForSave(
      isFreeDj: free,
      trialUsed: trialUsed,
    );
    configNotifier.value = normalized;
    await _ref(uid).set(normalized.toFirestore(), SetOptions(merge: true));
  }

  /// Pro → Free: Pro-Werbung oben einfügen und speichern.
  Future<void> applyProToFreePromotionPin() async {
    final next = configNotifier.value.withProPromotionPinnedToTop();
    await save(next, isFreeDj: true);
  }

  Future<void> ensureStarted() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    startForUid(uid);
  }
}
