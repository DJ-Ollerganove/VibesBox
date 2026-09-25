import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/vibesbox_sync_service.dart';
import '../utils/ui_constants.dart';
import '../widgets/vibesbox_sync_settings_section.dart';

class AdminToolPage extends StatelessWidget {
  const AdminToolPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: UIConstants.djShellPageBackground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Text(
            l.vibesbox_sync_title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.vibesbox_sync_hint,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: UIConstants.appOrange, width: 1.5),
              borderRadius: BorderRadius.circular(12),
              color: UIConstants.bgGradientStart,
            ),
            child: const VibesBoxSyncSettingsSection(),
          ),
          const SizedBox(height: 20),
          ListenableBuilder(
            listenable: VibesBoxSyncService.instance,
            builder: (context, _) {
              final sync = VibesBoxSyncService.instance;
              return _LiveCard(
                l: l,
                connected: sync.connected,
                now: sync.nowPlaying,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({
    required this.l,
    required this.connected,
    required this.now,
  });

  final AppLocalizations l;
  final bool connected;
  final Map<String, dynamic>? now;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: connected ? const Color(0xFF7CFFB2) : Colors.white24,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
        color: UIConstants.bgGradientStart,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.link : Icons.link_off,
                color: connected ? const Color(0xFF7CFFB2) : Colors.white38,
              ),
              const SizedBox(width: 8),
              Text(
                connected ? l.vibesbox_sync_connected : l.vibesbox_sync_waiting,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            l.admin_tool_now_playing,
            style: const TextStyle(
              color: Color(0xFFFFC857),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (now != null &&
              ((now!['title'] as String?) ?? '').trim().isNotEmpty)
            Text(
              '${now!['artist'] ?? '—'} – ${now!['title'] ?? '—'}'
              '${now!['bpm'] != null ? ' · ${now!['bpm']} BPM' : ''}'
              '${(now!['camelot'] as String?)?.isNotEmpty == true ? ' · ${now!['camelot']}' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Text(
              l.vibesbox_sync_no_song,
              style: const TextStyle(color: Colors.white54),
            ),
        ],
      ),
    );
  }
}
