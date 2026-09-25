import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/party_qr_code_dialog.dart';
import '../utils/party_location_export_helper.dart';

/// Öffnet den Party-QR-Dialog mit Ort und DJ-Kontaktdaten (wie Party-Verwaltung).
abstract final class PartyQrLaunchHelper {
  static Future<void> showForPartyData({
    required BuildContext context,
    required String partyId,
    required Map<String, dynamic> data,
  }) async {
    final partyName = data['party_name'] as String? ?? '';
    final startTs = data['start_date'] as Timestamp?;
    final endTs = data['end_date'] as Timestamp?;
    final partyCode = data['party_code'] as String?;
    if (startTs == null ||
        endTs == null ||
        partyCode == null ||
        partyCode.isEmpty) {
      return;
    }

    final mapLabel = AppLocalizations.of(context)?.location_on_map;
    final locationParts = PartyLocationExportHelper.fromPartyData(
      data,
      mapOnlyLabel: mapLabel,
    );

    String? djLogoUrl;
    String? profileImageUrl;
    String? djEmail;
    String? djPhone;
    String? djAlternativeEmail;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data();
        djLogoUrl = userData?['djLogoUrl'] as String?;
        profileImageUrl =
            userData?['profileImageUrl'] as String? ?? user.photoURL;
        djEmail = user.email ?? userData?['email'] as String?;
        djPhone = userData?['phoneNumber'] as String?;
        if (userData?['useAlternativeEmail'] == true) {
          djAlternativeEmail = userData?['alternativeEmail'] as String?;
        }
      }
    } catch (_) {}

    if (!context.mounted) return;
    await PartyQrCodeDialog.show(
      context: context,
      party: Party(
        partyName: partyName,
        startDate: startTs.toDate(),
        endDate: endTs.toDate(),
        partyCode: partyCode,
        partyId: partyId,
        locationName: locationParts.displayName,
        locationAddress: locationParts.displayAddress,
        locationUrl: locationParts.mapsUrl,
      ),
      djName: FirebaseAuth.instance.currentUser?.displayName,
      djLogoUrl: djLogoUrl,
      profileImageUrl: profileImageUrl,
      djEmail: djEmail,
      djPhone: djPhone,
      djAlternativeEmail: djAlternativeEmail,
    );
  }
}
