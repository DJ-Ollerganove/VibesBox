import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Zentrale Zuordnung: Plattform-ID (z. B. aus admin_config/vibesbox_social)
/// → Icon und Farbe aus der bestehenden Icon-Bibliothek.
class SocialPlatformIcons {
  SocialPlatformIcons._();

  static const Map<String, ({IconData icon, Color color})> _map = {
    'facebook': (icon: FontAwesomeIcons.facebook, color: Color(0xFF1877F2)),
    'instagram': (icon: FontAwesomeIcons.instagram, color: Color(0xFFE4405F)),
    'tiktok': (icon: FontAwesomeIcons.tiktok, color: Colors.white),
    'spotify': (icon: FontAwesomeIcons.spotify, color: Color(0xFF1DB954)),
    'soundcloud': (icon: FontAwesomeIcons.soundcloud, color: Color(0xFFFF5500)),
    'youtube': (icon: FontAwesomeIcons.youtube, color: Color(0xFFFF0000)),
    'whatsapp': (icon: FontAwesomeIcons.whatsapp, color: Color(0xFF25D366)),
    'website': (icon: FontAwesomeIcons.globe, color: Color(0xFF667eea)),
  };

  /// Liefert Icon und Farbe für die gegebene Plattform-ID, sonst null.
  static ({IconData icon, Color color})? get(String id) {
    if (id == null || id.isEmpty) return null;
    return _map[id.toLowerCase().trim()];
  }

  /// Prüft, ob für die ID ein Eintrag existiert.
  static bool has(String id) => get(id) != null;
}
