import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_scaffold_messenger.dart';
import '../l10n/app_localizations.dart';
import '../models/dj_song_blacklist_entry.dart';
import '../models/dj_song_blacklist_prefs.dart';
import '../services/active_party_service.dart';
import '../services/dj_song_blacklist_service.dart';
import '../services/open_wishes_visibility_service.dart';
import '../services/party_song_blacklist_service.dart';
import '../utils/ui_constants.dart';
import '../widgets/custom_page_header.dart';
import '../widgets/settings_help_dialog.dart';
import '../widgets/party/dj_song_blacklist_add_dialog.dart';
import '../widgets/party/dj_song_blacklist_chip.dart';

/// Hamburg-Menü: Song-Blacklist (Titel / Interpret / beides).
class DjSongBlacklistPage extends StatelessWidget {
  const DjSongBlacklistPage({super.key, this.isActive = true});

  final bool isActive;

  static String? _runningPartyId() {
    return OpenWishesVisibilityService.resolveDjWishPartyId() ??
        ActivePartyService.getStoredSession()?.partyId;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final l = AppLocalizations.of(context)!;
    return ColoredBox(
      color: UIConstants.djShellPageBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomPageHeader(
              icon: Icons.playlist_remove,
              title: l.translate('song_blacklist_title'),
              onInfoPressed: () => showPageInfoHelp(
                context,
                titleKey: 'song_blacklist_title',
                prefix: 'info_page_song_blacklist',
              ),
              trailing: uid.isEmpty || !isActive
                  ? null
                  : ValueListenableBuilder<DjSongBlacklistPrefs>(
                      valueListenable:
                          DjSongBlacklistService.instance.prefsNotifier,
                      builder: (context, prefs, _) {
                        if (!prefs.enabled) return const SizedBox.shrink();
                        return IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.white,
                          ),
                          tooltip: l.translate('song_blacklist_add_tooltip'),
                          onPressed: () => _addPermanent(context, uid),
                        );
                      },
                    ),
            ),
            Expanded(
              child: !isActive
                  ? const SizedBox.shrink()
                  : uid.isEmpty
                  ? Center(
                      child: Text(
                        l.not_logged_in,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    )
                  : ValueListenableBuilder<ActivePartyInfo?>(
                      valueListenable: ActivePartyService.storedSessionNotifier,
                      builder: (context, session, _) {
                        final runningPartyId = _runningPartyId();
                        // Kein zweiter Firestore-Listener: Guard/Service halten
                        // prefsNotifier bereits heiß — Seite liest nur den Notifier.
                        return ValueListenableBuilder<DjSongBlacklistPrefs>(
                          valueListenable:
                              DjSongBlacklistService.instance.prefsNotifier,
                          builder: (context, prefs, _) {
                            if (!prefs.enabled) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    l.translate(
                                      'song_blacklist_settings_enable_hint',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              );
                            }
                            if (runningPartyId == null ||
                                runningPartyId.isEmpty) {
                              return _PermanentList(
                                uid: uid,
                                entries: prefs.entries,
                                emptyMessage:
                                    l.translate('song_blacklist_empty'),
                              );
                            }
                            // Guard hält denselben Party-Stream → kein zweiter Listener.
                            return ValueListenableBuilder<
                                List<DjSongBlacklistEntry>>(
                              valueListenable: DjSongBlacklistService
                                  .instance.activePartyEntriesNotifier,
                              builder: (context, temp, _) {
                                final permanent = prefs.entries;
                                if (permanent.isEmpty && temp.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        l.translate('song_blacklist_empty'),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    24,
                                  ),
                                  children: [
                                    _sectionTitle(
                                      l.translate(
                                        'song_blacklist_permanent_section',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (permanent.isEmpty)
                                      Text(
                                        l.translate('song_blacklist_empty'),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      )
                                    else
                                      _chipWrap(
                                        entries: permanent,
                                        onRemove: (id) =>
                                            DjSongBlacklistService.instance
                                                .removeEntry(
                                          djId: uid,
                                          entryId: id,
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _sectionTitle(
                                            l.translate(
                                              'song_blacklist_temporary_section',
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          tooltip: l.translate(
                                            'song_blacklist_temporary_add_tooltip',
                                          ),
                                          onPressed: () => _addTemporary(
                                            context,
                                            runningPartyId,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (temp.isEmpty)
                                      Text(
                                        l.translate(
                                          'song_blacklist_temporary_empty',
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      )
                                    else
                                      _chipWrap(
                                        entries: temp,
                                        onRemove: (id) =>
                                            PartySongBlacklistService.instance
                                                .removeEntry(
                                          partyId: runningPartyId,
                                          entryId: id,
                                        ),
                                      ),
                                  ],
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  static Widget _chipWrap({
    required List<DjSongBlacklistEntry> entries,
    required void Function(String id) onRemove,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in DjSongBlacklistEntry.sortedCopy(entries))
          DjSongBlacklistChip(
            entry: item,
            onRemove: () => onRemove(item.id),
          ),
      ],
    );
  }

  static Future<void> _addPermanent(BuildContext context, String uid) async {
    final result = await DjSongBlacklistAddDialog.show(context: context);
    if (result == null) return;
    try {
      await DjSongBlacklistService.instance.addEntry(
        djId: uid,
        title: result.$1,
        artist: result.$2,
      );
    } catch (e) {
      if (!context.mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(
            l.tp('song_blacklist_save_failed', {'error': '$e'}),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  static Future<void> _addTemporary(
    BuildContext context,
    String partyId,
  ) async {
    final result = await DjSongBlacklistAddDialog.show(
      context: context,
      dialogTitleKey: 'song_blacklist_dialog_title_party',
    );
    if (result == null) return;
    try {
      await PartySongBlacklistService.instance.addEntry(
        partyId: partyId,
        title: result.$1,
        artist: result.$2,
      );
    } catch (e) {
      if (!context.mounted) return;
      final l = AppLocalizations.of(context)!;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(
            l.tp('song_blacklist_save_failed', {'error': '$e'}),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }
}

class _PermanentList extends StatelessWidget {
  const _PermanentList({
    required this.uid,
    required this.entries,
    required this.emptyMessage,
  });

  final String uid;
  final List<DjSongBlacklistEntry> entries;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in DjSongBlacklistEntry.sortedCopy(entries))
              DjSongBlacklistChip(
                entry: item,
                onRemove: () => DjSongBlacklistService.instance.removeEntry(
                  djId: uid,
                  entryId: item.id,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
