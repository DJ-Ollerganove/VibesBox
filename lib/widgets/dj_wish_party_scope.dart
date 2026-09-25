import 'package:flutter/material.dart';

import '../services/open_wishes_visibility_service.dart';
import 'no_active_party_display.dart';

/// Einzige Party-Abfrage + Anzeige für alle DJ-Tabs (wie [OffenPage]).
///
/// Quelle: [OpenWishesVisibilityService.visibilityNotifier] → `visibility?.partyId`.
/// Ohne Party: [buildNoActivePartyPanel] (rote Karte).
class DjWishPartyScope extends StatelessWidget {
  const DjWishPartyScope({
    super.key,
    required this.builder,
    this.emptyKey = 'none',
    this.onPartyIdChanged,
  });

  final Widget Function(
    BuildContext context,
    String partyId,
    OpenWishesVisibility visibility,
  )
  builder;

  final String emptyKey;
  final ValueChanged<String?>? onPartyIdChanged;

  /// Gleiche „Keine Party“-Anzeige überall — ein Widget, ein Layout.
  static Widget buildNoActivePartyPanel({String emptyKey = 'none'}) {
    return KeyedSubtree(
      key: ValueKey<String>(emptyKey),
      child: const Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Center(child: NoActivePartyDisplay()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OpenWishesVisibility?>(
      valueListenable: OpenWishesVisibilityService.visibilityNotifier,
      builder: (context, visibility, _) {
        final activePartyId = visibility?.partyId;
        if (activePartyId == null || activePartyId.isEmpty) {
          onPartyIdChanged?.call(null);
          return buildNoActivePartyPanel(emptyKey: emptyKey);
        }
        onPartyIdChanged?.call(activePartyId);
        return KeyedSubtree(
          key: ValueKey<String>(activePartyId),
          child: builder(context, activePartyId, visibility!),
        );
      },
    );
  }
}
