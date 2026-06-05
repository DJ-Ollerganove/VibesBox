import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/floor_occupancy_info.dart';
import '../models/venue_floor.dart';
import '../services/floor_swap_service.dart';
import '../services/public_dj_profile_service.dart';
import '../utils/floor_key_utils.dart';
import '../utils/ui_constants.dart';
import 'party_creation/public_venue_floor_field.dart';

/// Bestätigt und sendet eine Floor-Tausch-Anfrage an den anderen DJ.
Future<bool> showFloorSwapRequestDialog({
  required BuildContext context,
  required String venueId,
  required String fromPartyId,
  required String fromFloorKey,
  required String targetFloorKey,
  required FloorOccupancyInfo targetOccupancy,
  required List<VenueFloor> venueFloors,
}) async {
  final l = AppLocalizations.of(context)!;
  final fromDjId = FirebaseAuth.instance.currentUser?.uid;
  if (fromDjId == null) return false;

  String djName = 'DJ';
  try {
    final profile =
        await PublicDjProfileService().fetchByUid(targetOccupancy.djId);
    final name = profile?.displayName?.trim();
    if (name != null && name.isNotEmpty) djName = name;
  } catch (_) {}

  final targetLabel = PublicVenueFloorField.labelForKey(
    l,
    venueFloors,
    targetFloorKey,
  );
  final yourLabel = PublicVenueFloorField.labelForKey(
    l,
    venueFloors,
    fromFloorKey,
  );

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final body = l.party_floor_swap_dialog_body(djName, targetLabel);
      return AlertDialog(
        backgroundColor: UIConstants.bgGradientEnd,
        title: Text(l.party_floor_swap_dialog_title),
        content: Text(
          '$body\n\n${l.party_floor_swap_dialog_your_floor(yourLabel)}',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: UIConstants.appOrange,
              foregroundColor: Colors.black,
            ),
            child: Text(l.party_floor_swap_request),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return false;

  final requestId = await FloorSwapService.instance.createSwapRequest(
    venueId: venueId,
    fromPartyId: fromPartyId,
    toPartyId: targetOccupancy.partyId,
    fromDjId: fromDjId,
    toDjId: targetOccupancy.djId,
    fromFloorKey: FloorKeyUtils.effectiveFloorKey(fromFloorKey),
    toFloorKey: FloorKeyUtils.effectiveFloorKey(targetFloorKey),
  );

  if (!context.mounted) return requestId != null;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        requestId != null
            ? l.party_floor_swap_sent
            : l.party_floor_swap_failed,
      ),
      backgroundColor: requestId != null ? Colors.green : Colors.red,
    ),
  );
  return requestId != null;
}

/// Eingehende Tausch-Anfrage annehmen oder ablehnen.
Future<void> showFloorSwapIncomingDialog({
  required BuildContext context,
  required String requestId,
  required String fromDjId,
  required String yourFloorKey,
  required String theirFloorKey,
  required List<VenueFloor> venueFloors,
}) async {
  final l = AppLocalizations.of(context)!;

  String djName = 'DJ';
  try {
    final profile = await PublicDjProfileService().fetchByUid(fromDjId);
    final name = profile?.displayName?.trim();
    if (name != null && name.isNotEmpty) djName = name;
  } catch (_) {}

  final yourLabel =
      PublicVenueFloorField.labelForKey(l, venueFloors, yourFloorKey);
  final theirLabel =
      PublicVenueFloorField.labelForKey(l, venueFloors, theirFloorKey);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: UIConstants.bgGradientEnd,
        title: Text(l.party_floor_swap_incoming_title),
        content: Text(
          l.party_floor_swap_incoming_body(djName, yourLabel, theirLabel),
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await FloorSwapService.instance.rejectRequest(requestId);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l.party_floor_swap_reject),
          ),
          FilledButton(
            onPressed: () async {
              await FloorSwapService.instance.acceptRequest(requestId);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l.party_floor_swap_accepted),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: UIConstants.appOrange,
              foregroundColor: Colors.black,
            ),
            child: Text(l.party_floor_swap_accept),
          ),
        ],
      );
    },
  );
}
