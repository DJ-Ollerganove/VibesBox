import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'models/user_model.dart';
import 'services/user_service.dart';
import 'widgets/custom_page_header.dart';
import 'widgets/spotify_search_filter_settings_section.dart';

/// Admin: Verwaltung der Spotify-Such-Blacklist / Filter ([admin_config/spotify_settings]).
/// (Titelsuche für DJs läuft in Offen/Manual-Wunsch, nicht über diese Seite.)
class SpotifyPage extends StatelessWidget {
  const SpotifyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ValueListenableBuilder<UserModel?>(
          valueListenable: UserService().currentUser,
          builder: (context, userModel, _) {
            final canEdit = AppConfig.canManageSpotifySearchSettings(userModel);

            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CustomPageHeader(
                    icon: Icons.music_note,
                    title: 'Spotify-Suche',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canEdit
                        ? 'Begriffe und maximale Titel-Länge steuern, was in der Musiksuche (App & PWA) angezeigt wird. '
                            'Die Liste wird lokal gecacht (24 h), nicht bei jeder Suche aus der Cloud gelesen.'
                        : 'Die Verwaltung der Such-Blacklist ist nur für Administratoren verfügbar.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (canEdit)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange, width: 1.5),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: const SpotifySearchFilterSettingsSection(),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey, width: 1),
                      ),
                      child: const Text(
                        'Mit deinem Konto kannst du diese Einstellungen nicht bearbeiten.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
