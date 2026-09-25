import '../l10n/app_localizations.dart';
import '../models/guest_floor_option.dart';
import '../utils/floor_key_utils.dart';
import '../utils/venue_party_fields.dart';

/// Anzeige-Labels für Gast-Floor-Auswahl (l10n).
class GuestFloorDisplay {
  GuestFloorDisplay._();

  static String floorLabel(AppLocalizations l, String? rawLabel, String? floorKey) {
    final trimmed = rawLabel?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (FloorKeyUtils.isDefaultFloorKey(floorKey)) {
      return l.guest_floor_main_area;
    }
    final key = floorKey?.trim();
    if (key != null && key.isNotEmpty) return key;
    return l.guest_floor_main_area;
  }

  static String optionTitle(AppLocalizations l, GuestFloorOption option) {
    final label = floorLabel(l, option.floorLabel, option.floorKey);
    return l.guest_floor_option_label(label, option.djName);
  }

  static String labelFromPartyData(
    AppLocalizations l,
    Map<String, dynamic> partyData,
  ) {
    return floorLabel(
      l,
      partyData['floor_label'] as String?,
      VenuePartyFields.readFloorKey(partyData),
    );
  }

  /// Floor-Zeile für öffentliche Partys mit explizit gewähltem Floor (nicht Default).
  static String? publicPartyFloorLineIfAny(
    AppLocalizations l,
    Map<String, dynamic> partyData,
  ) {
    if (partyData['party_type'] != 'public') return null;
    if (VenuePartyFields.isDefaultFloorParty(partyData)) return null;
    return labelFromPartyData(l, partyData);
  }
}
