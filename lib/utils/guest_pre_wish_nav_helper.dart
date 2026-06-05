import '../services/party_session_service.dart';

/// Gast-Navigation im Vorab-Modus — liest nur aus [PartySessionService] (Session-Koffer).
class GuestPreWishNavHelper {
  GuestPreWishNavHelper._();

  static bool get isPreWishNavMode =>
      PartySessionService.instance.isPreWishSession;

  static bool get isProDj => PartySessionService.instance.isPro;
}
