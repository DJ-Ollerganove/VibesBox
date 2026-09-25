import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/event_setlist_track.dart';
import '../../models/pre_wish_export_models.dart';
import '../../services/dj_setlist_library_service.dart';
import '../../services/dj_setlist_store_service.dart';
import '../../services/pre_wish_export_service.dart';
import '../../utils/ui_constants.dart';
import '../../app_scaffold_messenger.dart';
import 'setlist_party_picker.dart';

class SetlistExportMenu {
  SetlistExportMenu._();

  /// Gibt die Library-Listen-ID zurück (neu gespeichert oder [libraryListId]).
  static Future<String?> show({
    required BuildContext context,
    required List<EventSetlistTrack> tracks,
    String listTitle = '',
    bool showSaveToLibrary = true,
    /// Wenn gesetzt: Party-Zuordnung aktualisiert diese Library-Liste (1→viele Partys).
    String? libraryListId,
  }) async {
    if (tracks.isEmpty || !context.mounted) return libraryListId;
    final l = AppLocalizations.of(context)!;
    final resolvedTitle = listTitle.trim().isEmpty
        ? l.translate('dj_setlist_ai_title')
        : listTitle;
    final pageContext = context;
    var activeLibId = libraryListId?.trim() ?? '';
    if (activeLibId.isEmpty) activeLibId = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        final loc = AppLocalizations.of(ctx)!;
        return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      loc.pre_wish_export,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _tile(
                    icon: Icons.event_available,
                    label: loc.translate('dj_setlist_export_to_party'),
                    color: UIConstants.appOrange,
                    onTap: () async {
                      final id = await _importToParty(
                        ctx,
                        pageContext,
                        tracks,
                        resolvedTitle,
                        libraryListId: activeLibId.isEmpty ? null : activeLibId,
                      );
                      if (id != null && id.isNotEmpty) activeLibId = id;
                    },
                  ),
                  if (showSaveToLibrary)
                    _tile(
                      icon: Icons.save,
                      label: loc.translate('dj_setlist_save_to_library'),
                      color: UIConstants.colorDjSetlist,
                      onTap: () async {
                        final id = await _saveToLibrary(
                          ctx,
                          pageContext,
                          tracks,
                          resolvedTitle,
                          existingId: activeLibId.isEmpty ? null : activeLibId,
                        );
                        if (id != null && id.isNotEmpty) activeLibId = id;
                      },
                    ),
                  const Divider(color: Colors.white24, height: 12),
                  _tile(
                    icon: Icons.picture_as_pdf,
                    label: loc.translate('dj_setlist_export_pdf'),
                    color: UIConstants.colorRed,
                    onTap: () => _export(
                      ctx,
                      pageContext,
                      tracks,
                      resolvedTitle,
                      PreWishExportFormat.pdf,
                    ),
                  ),
                  _tile(
                    icon: Icons.description,
                    label: loc.pre_wish_export_format_txt,
                    onTap: () => _export(
                      ctx,
                      pageContext,
                      tracks,
                      resolvedTitle,
                      PreWishExportFormat.txt,
                    ),
                  ),
                  _tile(
                    icon: Icons.table_chart,
                    label: loc.pre_wish_export_format_csv,
                    onTap: () => _export(
                      ctx,
                      pageContext,
                      tracks,
                      resolvedTitle,
                      PreWishExportFormat.csv,
                    ),
                  ),
                  _tile(
                    icon: Icons.queue_music,
                    label: loc.pre_wish_export_format_m3u,
                    onTap: () => _export(
                      ctx,
                      pageContext,
                      tracks,
                      resolvedTitle,
                      PreWishExportFormat.m3u,
                    ),
                  ),
                  _tile(
                    icon: Icons.library_music,
                    label: loc.pre_wish_export_format_pls,
                    onTap: () => _export(
                      ctx,
                      pageContext,
                      tracks,
                      resolvedTitle,
                      PreWishExportFormat.pls,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      },
    );
    return activeLibId.isEmpty ? null : activeLibId;
  }

  static Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.white,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      minLeadingWidth: 28,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: color == Colors.white ? FontWeight.w600 : FontWeight.w700,
        ),
      ),
      onTap: onTap,
    );
  }

  static List<PreWishExportSong> _toExportSongs(List<EventSetlistTrack> tracks) {
    final now = DateTime.now();
    return [
      for (var i = 0; i < tracks.length; i++)
        PreWishExportSong(
          artist: tracks[i].artist,
          title: tracks[i].title,
          wishers: const [],
          sortKey: now.add(Duration(seconds: i)),
          metaLine: tracks[i].mixMetaLine,
        ),
    ];
  }

  static Future<void> _export(
    BuildContext sheetContext,
    BuildContext pageContext,
    List<EventSetlistTrack> tracks,
    String listTitle,
    PreWishExportFormat format,
  ) async {
    Navigator.pop(sheetContext);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!pageContext.mounted) return;
    await PreWishExportService.shareExport(
      context: pageContext,
      format: format,
      partyName: listTitle,
      partyStartDate: DateTime.now(),
      songs: _toExportSongs(tracks),
    );
  }

  static Future<String?> _saveToLibrary(
    BuildContext sheetContext,
    BuildContext pageContext,
    List<EventSetlistTrack> tracks,
    String listTitle, {
    String? existingId,
  }) async {
    Navigator.pop(sheetContext);
    try {
      final id = await DjSetlistLibraryService.instance.save(
        title: listTitle,
        tracks: tracks,
        existingId: existingId,
      );
      if (!pageContext.mounted) return id;
      showVibesSnackBar(
        pageContext,
        SnackBar(
          content: Text(
            AppLocalizations.of(pageContext)!.tp(
              'dj_setlist_saved_library',
              {'count': '${tracks.length}'},
            ),
          ),
          backgroundColor: Colors.green.shade800,
        ),
      );
      return id;
    } catch (e) {
      if (!pageContext.mounted) return null;
      showVibesSnackBar(
        pageContext,
        SnackBar(
          content: Text(
            AppLocalizations.of(pageContext)!.tp(
              'song_blacklist_save_failed',
              {'error': '$e'},
            ),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return null;
    }
  }

  static Future<String?> _importToParty(
    BuildContext sheetContext,
    BuildContext pageContext,
    List<EventSetlistTrack> tracks,
    String listTitle, {
    String? libraryListId,
  }) async {
    Navigator.pop(sheetContext);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!pageContext.mounted) return libraryListId;
    final choice = await SetlistPartyPicker.show(pageContext);
    if (choice == null || !pageContext.mounted) return libraryListId;
    try {
      if (await DjSetlistStoreService.instance.exists(choice.partyId)) {
        if (!pageContext.mounted) return libraryListId;
        showVibesSnackBar(
          pageContext,
          SnackBar(
            content: Text(
              AppLocalizations.of(pageContext)!
                  .translate('dj_setlist_party_has_list'),
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return libraryListId;
      }
      await DjSetlistStoreService.instance.save(
        partyId: choice.partyId,
        tracks: tracks,
        partyName: choice.partyName,
      );
      final libId = libraryListId?.trim() ?? '';
      String resolvedId;
      if (libId.isNotEmpty && !libId.startsWith('party_')) {
        await DjSetlistLibraryService.instance.assignParty(
          listId: libId,
          partyId: choice.partyId,
          partyName: choice.partyName,
          tracks: tracks,
        );
        resolvedId = libId;
      } else {
        resolvedId = await DjSetlistLibraryService.instance.save(
          title: listTitle.trim().isEmpty ? choice.partyName : listTitle,
          tracks: tracks,
          partyId: choice.partyId,
          partyName: choice.partyName,
          partyIds: <String>[choice.partyId],
          partyNames: <String, String>{choice.partyId: choice.partyName},
        );
      }
      if (!pageContext.mounted) return resolvedId;
      showVibesSnackBar(
        pageContext,
        SnackBar(
          content: Text(
            AppLocalizations.of(pageContext)!.tp(
              'dj_setlist_created_in_party',
              {
                'count': '${tracks.length}',
                'party': choice.partyName,
              },
            ),
          ),
          backgroundColor: Colors.green.shade800,
        ),
      );
      return resolvedId;
    } catch (e) {
      if (!pageContext.mounted) return libraryListId;
      showVibesSnackBar(
        pageContext,
        SnackBar(
          content: Text(
            AppLocalizations.of(pageContext)!.tp(
              'dj_setlist_create_failed',
              {'error': '$e'},
            ),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
      return libraryListId;
    }
  }
}
