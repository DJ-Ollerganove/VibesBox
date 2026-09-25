import 'package:flutter/material.dart';

import '../app_scaffold_messenger.dart';
import '../l10n/app_localizations.dart';
import '../models/dj_setlist_library_item.dart';
import '../services/dj_setlist_library_service.dart';
import '../services/dj_setlist_store_service.dart';
import '../services/dj_setlist_track_actions_service.dart';
import '../services/dj_pro_session_service.dart';
import '../services/pro_feature_guard.dart';
import '../utils/ui_constants.dart';
import '../widgets/custom_page_header.dart';
import '../widgets/free_feature_locked.dart';
import '../widgets/pro_promotion_banner.dart';
import '../widgets/settings_help_dialog.dart';
import '../widgets/party/setlist_export_menu.dart';
import '../widgets/party/setlist_generator_view.dart';
import '../widgets/party/setlist_paginated_track_list.dart';
import '../widgets/party/setlist_track_action_icons.dart';

/// Hamburg-Menü: gespeicherte DJ-Setlisten inkl. Party-Zuordnungen.
class DjSetlistsLibraryPage extends StatefulWidget {
  const DjSetlistsLibraryPage({super.key, this.isActive = true});

  final bool isActive;

  static final ValueNotifier<int> createSignal = ValueNotifier<int>(0);

  static void requestCreate() {
    createSignal.value++;
  }

  @override
  State<DjSetlistsLibraryPage> createState() => _DjSetlistsLibraryPageState();
}

class _DjSetlistsLibraryPageState extends State<DjSetlistsLibraryPage> {
  List<DjSetlistLibraryItem> _fromParties = const [];
  bool _loadedParties = false;
  DjSetlistLibraryItem? _open;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    DjSetlistsLibraryPage.createSignal.addListener(_onCreateSignal);
    if (widget.isActive) {
      _reloadPartyLists();
    }
  }

  @override
  void dispose() {
    DjSetlistsLibraryPage.createSignal.removeListener(_onCreateSignal);
    super.dispose();
  }

  void _onCreateSignal() {
    if (!mounted || !widget.isActive) return;
    if (!ProFeatureGuard.canUseProExclusiveNow()) return;
    setState(() {
      _open = null;
      _creating = true;
    });
  }

  void _closeCreate() {
    _reloadPartyLists();
    setState(() => _creating = false);
  }

  @override
  void didUpdateWidget(covariant DjSetlistsLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _reloadPartyLists();
    } else if (!widget.isActive && oldWidget.isActive) {
      // IndexedStack-Seite unsichtbar: schwere Party-Listen aus dem RAM.
      setState(() {
        _fromParties = const [];
        _loadedParties = false;
        _open = null;
        _creating = false;
      });
    }
  }

  Future<void> _reloadPartyLists() async {
    final items =
        await DjSetlistLibraryService.instance.loadAssignedFromParties();
    if (!mounted) return;
    setState(() {
      _fromParties = items;
      _loadedParties = true;
    });
  }

  List<DjSetlistLibraryItem> _merge(List<DjSetlistLibraryItem> library) {
    final coveredParties = <String>{};
    final out = <DjSetlistLibraryItem>[];
    for (final item in library) {
      out.add(item);
      coveredParties.addAll(item.partyIds);
    }
    for (final item in _fromParties) {
      final pid = item.partyId;
      if (pid == null || pid.isEmpty || coveredParties.contains(pid)) continue;
      out.add(item);
      coveredParties.add(pid);
    }
    return out;
  }

  Future<bool> _confirmDelete(DjSetlistLibraryItem item) async {
    final l = AppLocalizations.of(context)!;
    final partyLabel = item.partiesLabel();
    final assigned = item.isAssignedToParty && partyLabel.isNotEmpty;
    final body = assigned
        ? l.tp('dj_setlist_delete_confirm_party', {
            'title': item.title,
            'party': partyLabel,
          })
        : l.tp('dj_setlist_delete_confirm', {'title': item.title});
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: UIConstants.djShellPageBackground,
        title: Text(
          l.translate('dj_setlist_delete_title'),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          body,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: UIConstants.colorRed, width: 2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel, style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.delete,
              style: TextStyle(
                color: UIConstants.colorRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteItem(DjSetlistLibraryItem item) async {
    if (!await _confirmDelete(item)) return;
    try {
      for (final pid in item.partyIds) {
        final id = pid.trim();
        if (id.isEmpty) continue;
        await DjSetlistStoreService.instance.delete(id);
      }
      await DjSetlistLibraryService.instance.delete(item.id);
      if (!mounted) return;
      if (_open?.id == item.id) {
        setState(() => _open = null);
      }
      await _reloadPartyLists();
      if (!mounted) return;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate('dj_setlist_deleted')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showVibesSnackBar(
        context,
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.tp(
              'dj_setlist_delete_failed',
              {'error': '$e'},
            ),
          ),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionProStatus?>(
      valueListenable: DjProSessionService.instance.sessionProStatus,
      builder: (context, _, __) {
        if (!ProFeatureGuard.canUseProExclusiveNow()) {
          return _buildLocked(context);
        }
        return _buildUnlocked(context);
      },
    );
  }

  Widget _buildLocked(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ColoredBox(
      color: UIConstants.djShellPageBackground,
      child: SafeArea(
        child: Column(
          children: [
            CustomPageHeader(
              icon: Icons.queue_music,
              title: l.translate('dj_setlists_menu'),
              onInfoPressed: () => FreeFeatureLockedDialog.show(
                context,
                title: l.free_feature_dj_setlist_title,
                description: l.free_feature_dj_setlist_description,
              ),
            ),
            const ProPromotionBanner(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.queue_music,
                        size: 56,
                        color: UIConstants.colorDjSetlist.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l.free_feature_dj_setlist_title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.free_feature_dj_setlist_description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => FreeFeatureLockedDialog.show(
                          context,
                          title: l.free_feature_dj_setlist_title,
                          description: l.free_feature_dj_setlist_description,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UIConstants.appGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(l.getVibesboxPro),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlocked(BuildContext context) {
    final open = _open;
    final creating = _creating;
    final l = AppLocalizations.of(context)!;
    return ColoredBox(
      color: UIConstants.djShellPageBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomPageHeader(
              icon: Icons.queue_music,
              title: creating
                  ? l.translate('dj_setlist_create_title')
                  : (open?.title ?? l.translate('dj_setlists_menu')),
              onInfoPressed: () => showPageInfoHelp(
                context,
                titleKey: 'dj_setlists_menu',
                prefix: 'info_page_dj_setlists',
                extraBullets: const [
                  (
                    'info_page_dj_setlists_offen',
                    'info_page_dj_setlists_offen_body',
                  ),
                  (
                    'info_page_dj_setlists_export',
                    'info_page_dj_setlists_export_body',
                  ),
                ],
              ),
              trailing: creating
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _closeCreate,
                    )
                  : open != null
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => setState(() => _open = null),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.add_circle_outline,
                            color: Colors.white,
                          ),
                          tooltip: l.translate('dj_setlist_add_tooltip'),
                          onPressed: () => setState(() => _creating = true),
                        ),
            ),
            Expanded(
              child: creating
                  ? SetlistGeneratorView(
                      hidePageChrome: true,
                      onClose: _closeCreate,
                    )
                  : (open == null ? _listBody() : _detailBody(open)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listBody() {
    final l = AppLocalizations.of(context)!;
    // Kein Firestore-Stream, solange die Seite im IndexedStack nicht sichtbar ist.
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<List<DjSetlistLibraryItem>>(
      key: const ValueKey('dj_setlists_library_watch_mine'),
      stream: DjSetlistLibraryService.instance.watchMine(),
      builder: (context, snapshot) {
        final items = _merge(
          snapshot.data ?? const <DjSetlistLibraryItem>[],
        );
        if (!_loadedParties &&
            snapshot.connectionState == ConnectionState.waiting &&
            items.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: UIConstants.appOrange),
          );
        }
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l.translate('dj_setlist_empty_library'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 15,
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: Text(
                item.title,
                style: const TextStyle(
                  color: UIConstants.colorDjSetlist,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                item.isAssignedToParty
                    ? l.tp('dj_setlist_subtitle_party', {
                        'count': '${item.tracks.length}',
                        'party': item.partiesLabel(),
                      })
                    : l.tp('dj_setlist_subtitle_unassigned', {
                        'count': '${item.tracks.length}',
                      }),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: UIConstants.colorRed),
                tooltip: l.translate('dj_setlist_delete_title'),
                onPressed: () => _deleteItem(item),
              ),
              onTap: () => setState(() => _open = item),
            );
          },
        );
      },
    );
  }

  Widget _detailBody(DjSetlistLibraryItem item) {
    final l = AppLocalizations.of(context)!;
    final libId = item.isPartyStoreOnly ? null : item.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => SetlistExportMenu.show(
                context: context,
                tracks: item.tracks,
                listTitle: item.title,
                showSaveToLibrary: false,
                libraryListId: libId,
              ),
              icon: const Icon(Icons.ios_share, color: Colors.white70),
              label: Text(
                l.pre_wish_export,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
        Expanded(
          child: SetlistPaginatedTrackList(
            tracks: item.tracks,
            onReasonsLocalized: (tracks) async {
              if (_open?.id != item.id) return;
              await DjSetlistTrackActionsService.instance.persistLibraryItem(
                item: item,
                tracks: tracks,
              );
              if (!mounted || _open?.id != item.id) return;
              setState(() => _open = item.copyWith(tracks: tracks));
            },
            onReorder: (next) async {
              try {
                await DjSetlistTrackActionsService.instance.persistLibraryItem(
                  item: item,
                  tracks: next,
                );
                if (!mounted) return;
                setState(() => _open = item.copyWith(tracks: next));
                await _reloadPartyLists();
              } catch (e) {
                if (!mounted) return;
                showVibesSnackBar(
                  context,
                  SnackBar(
                    content: Text(
                      l.tp('dj_setlist_action_failed', {'error': '$e'}),
                    ),
                    backgroundColor: Colors.red.shade800,
                  ),
                );
              }
            },
            onEdit: (index, track) async {
              final edited = await SetlistTrackActionIcons.editTrack(
                context,
                title: track.title,
                artist: track.artist,
              );
              if (edited == null || !mounted) return;
              final next = [...item.tracks];
              if (index < 0 || index >= next.length) return;
              next[index] = track.copyWith(
                title: edited.title,
                artist: edited.artist,
              );
              try {
                await DjSetlistTrackActionsService.instance.persistLibraryItem(
                  item: item,
                  tracks: next,
                );
                if (!mounted) return;
                setState(() => _open = item.copyWith(tracks: next));
                await _reloadPartyLists();
              } catch (e) {
                if (!mounted) return;
                showVibesSnackBar(
                  context,
                  SnackBar(
                    content: Text(
                      l.tp('dj_setlist_action_failed', {'error': '$e'}),
                    ),
                    backgroundColor: Colors.red.shade800,
                  ),
                );
              }
            },
            onDelete: (index, track) async {
              final ok = await SetlistTrackActionIcons.confirmDelete(
                context,
                title: track.title,
                artist: track.artist,
                removeFromSaved: true,
              );
              if (!ok || !mounted) return;
              final next = [...item.tracks]..removeAt(index);
              try {
                await DjSetlistTrackActionsService.instance.persistLibraryItem(
                  item: item,
                  tracks: next,
                );
                if (!mounted) return;
                setState(() => _open = item.copyWith(tracks: next));
                await _reloadPartyLists();
              } catch (e) {
                if (!mounted) return;
                showVibesSnackBar(
                  context,
                  SnackBar(
                    content: Text(
                      l.tp('dj_setlist_delete_failed', {'error': '$e'}),
                    ),
                    backgroundColor: Colors.red.shade800,
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
