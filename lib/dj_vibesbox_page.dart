import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'l10n/app_localizations.dart';
import 'utils/ui_constants.dart';
import 'services/active_party_service.dart';
import 'services/wish_management_service.dart';
import 'offen_page.dart';
import 'gespielt_page.dart';
import 'abgelehnt_page.dart';
import 'models/song_request.dart';
import 'pages/favoriten_page.dart';
import 'pages/manual_wish_page.dart';
import 'services/user_service.dart';
import 'widgets/free_feature_locked.dart';
import 'widgets/heartbeat_pulse_dot.dart';

/// Zentrale DJ-Wunschverwaltung mit Tab-Navigation (Offen | Gespielt | Abgelehnt)
class DjVibesBoxPage extends StatefulWidget {
  final GlobalKey<OffenPageState> offenPageKey;
  final List<SongRequest> requests;
  final VoidCallback? onPageOpened;
  /// Wenn true, wird beim Anzeigen der Seite der erste Tab (Offen) aktiviert
  final bool isActive;

  const DjVibesBoxPage({
    super.key,
    required this.offenPageKey,
    required this.requests,
    this.onPageOpened,
    this.isActive = true,
  });

  @override
  State<DjVibesBoxPage> createState() => _DjVibesBoxPageState();
}

class _DjVibesBoxPageState extends State<DjVibesBoxPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ValueNotifier<bool> _showOnlyFavoritesNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void didUpdateWidget(covariant DjVibesBoxPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive && _tabController.index != 0) {
      _tabController.animateTo(0);
    }
  }

  @override
  void dispose() {
    _showOnlyFavoritesNotifier.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TabBar (VibesBox-Stil: Orange/Schwarz)
        Container(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Divider(height: 1, color: Colors.black.withValues(alpha: 0.45), thickness: 1),
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  final indicatorColor = _tabController.index == 0
                      ? UIConstants.tabOffenColor
                      : _tabController.index == 1
                          ? UIConstants.tabGespieltColor
                          : UIConstants.tabAbgelehntColor;
                  return Row(
                    textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TabBar(
                          controller: _tabController,
                          indicator: UnderlineTabIndicator(
                            borderSide: BorderSide(color: indicatorColor, width: 3),
                          ),
                          dividerColor: UIConstants.colorWhite.withValues(alpha: 0.3),
                          labelColor: Colors.transparent,
                          unselectedLabelColor: Colors.transparent,
                          tabs: [
                            Tab(
                              child: Text(
                                l.open,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _tabController.index == 0 ? FontWeight.bold : FontWeight.normal,
                                  color: UIConstants.tabOffenColor,
                                ),
                              ),
                            ),
                            Tab(
                              child: Text(
                                l.played,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _tabController.index == 1 ? FontWeight.bold : FontWeight.normal,
                                  color: UIConstants.tabGespieltColor,
                                ),
                              ),
                            ),
                            Tab(
                              child: Text(
                                l.rejected,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _tabController.index == 2 ? FontWeight.bold : FontWeight.normal,
                                  color: UIConstants.tabAbgelehntColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      HeartbeatPulseDot(
                        padding: EdgeInsetsDirectional.only(
                          start: isRtl ? 8 : 0,
                          end: isRtl ? 0 : 8,
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Aktionen für Offen-Tab (Add Wish, Favoriten)
              // Feste Höhe (52px) für alle Tabs, damit die "Keine Party"-Meldung auf allen Tabs exakt dieselbe Position hat
              SizedBox(
                height: 52,
                child: AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    if (_tabController.index != 0) return const SizedBox.shrink();
                    // Plus- und Favoriten-Icon nur aktiv/sichtbar, wenn Session eine aktive Party hat (ActivePartyService.currentPartyId != null)
                    return StreamBuilder<ActivePartyInfo?>(
                      stream: ActivePartyService.getActivePartyInfoStream(FirebaseAuth.instance.currentUser?.uid),
                      builder: (context, partySnapshot) {
                        final info = partySnapshot.data;
                        // Fallback: Beim Tab-Wechsel zurück zu Offen liefert der Stream oft kurz kein data →
                        // dann wäre hasActiveParty false und das Favoriten-Icon inaktiv. Stattdessen
                        // letzte bekannte Party-ID nutzen, damit Icon sofort rot und klickbar bleibt.
                        final fromStream = info != null && info.partyId.isNotEmpty ? info.partyId : null;
                        final fallbackId = ActivePartyService.currentPartyId ?? ActivePartyService.storedSessionNotifier.value?.partyId;
                        final partyId = fromStream ?? (fallbackId != null && fallbackId.isNotEmpty ? fallbackId : null);
                        final hasActiveParty = partyId != null;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                          child: Row(
                            mainAxisAlignment: isRtl ? MainAxisAlignment.start : MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(Icons.add_circle_outline, color: hasActiveParty ? UIConstants.appOrange : Colors.grey),
                                tooltip: l.addManualWish,
                                onPressed: hasActiveParty
                                    ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ManualWishPage(partyId: partyId!),
                                          ),
                                        )
                                    : null,
                              ),
                              ValueListenableBuilder<bool>(
                                valueListenable: _showOnlyFavoritesNotifier,
                                builder: (context, showOnly, _) {
                                  final isFree = UserService().sessionProStatus.value?.isActive != true;
                                  return StreamBuilder<QuerySnapshot>(
                                    stream: partyId != null
                                        ? WishManagementService.getFavoriteWishesStream(partyId, 'pending')
                                        : null,
                                    builder: (context, favSnapshot) {
                                      final isFavoritePresent = favSnapshot.hasData &&
                                          (favSnapshot.data?.docs.isNotEmpty ?? false);
                                      return IconButton(
                                        icon: Icon(
                                          isFavoritePresent ? Icons.favorite : Icons.favorite_border,
                                        ),
                                        color: hasActiveParty
                                            ? (isFavoritePresent ? Colors.red : (isFree ? UIConstants.freeLimitBorderRed : UIConstants.frameNoParty.withValues(alpha: 0.7)))
                                            : UIConstants.frameNoParty.withValues(alpha: 0.4),
                                        tooltip: hasActiveParty
                                            ? (showOnly ? 'Nur Favoriten (aktiv). Lang: Favoriten-Seite' : 'Nur Favoriten anzeigen. Lang: Favoriten-Seite')
                                            : 'Favoriten (keine Party aktiv)',
                                        onPressed: hasActiveParty
                                            ? () {
                                                if (isFree) {
                                                  FreeFeatureLockedDialog.show(context);
                                                  return;
                                                }
                                                _showOnlyFavoritesNotifier.value =
                                                    !_showOnlyFavoritesNotifier.value;
                                              }
                                            : null,
                                        onLongPress: hasActiveParty && !isFree
                                            ? () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => FavoritenPage(
                                                      requests: widget.requests,
                                                    ),
                                                  ),
                                                );
                                              }
                                            : (hasActiveParty && isFree ? () => FreeFeatureLockedDialog.show(context) : null),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Tab-Inhalt
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              OffenPage(
                key: widget.offenPageKey,
                requests: widget.requests,
                onPageOpened: widget.onPageOpened,
                showOnlyFavoritesNotifier: _showOnlyFavoritesNotifier,
              ),
              GespieltPage(requests: widget.requests),
              AbgelehntPage(
                requests: widget.requests,
                onWishRestoredToOpen: () => _tabController.animateTo(0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
