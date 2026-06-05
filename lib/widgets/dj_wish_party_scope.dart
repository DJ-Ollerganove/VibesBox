import 'package:flutter/material.dart';

import '../services/open_wishes_visibility_service.dart';
import 'no_active_party_display.dart';

/// Party-Kontext für DJ-Wunschlisten: läuft + Nachlaufzeit (Einstellung des DJs).
class DjWishPartyScope extends StatelessWidget {
  const DjWishPartyScope({
    super.key,
    required this.builder,
    this.emptyKey = 'none',
  });

  final Widget Function(BuildContext context, String partyId) builder;
  final String emptyKey;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OpenWishesVisibility?>(
      stream: OpenWishesVisibilityService.watch(),
      builder: (context, snapshot) {
        final partyId = snapshot.data?.partyId;
        if (partyId == null || partyId.isEmpty) {
          return KeyedSubtree(
            key: ValueKey<String>(emptyKey),
            child: const Stack(
              children: [
                Positioned.fill(
                  child: Center(child: NoActivePartyDisplay()),
                ),
              ],
            ),
          );
        }
        return KeyedSubtree(
          key: ValueKey<String>(partyId),
          child: builder(context, partyId),
        );
      },
    );
  }
}
