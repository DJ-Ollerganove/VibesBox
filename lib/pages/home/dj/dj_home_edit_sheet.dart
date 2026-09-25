import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/dj_home_layout_service.dart';
import '../../../services/dj_pro_session_service.dart';
import '../../../services/user_service.dart';
import '../../../utils/ui_constants.dart';
import '../../../widgets/settings_help_dialog.dart';
import '../../../widgets/settings_info_icon_button.dart';

/// Bottom-Sheet: Widgets ein/aus und Reihenfolge per Drag & Drop.
Future<void> showDjHomeEditSheet(BuildContext context) async {
  var draft = DjHomeLayoutService.instance.configNotifier.value;
  final l = AppLocalizations.of(context)!;
  final isFreeDj = DjProSessionService.instance.isFreeDj;
  final trialUsed = UserService().currentUser.value?.trialUsed ?? true;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final mq = MediaQuery.of(context);
          final bottomSafe = mq.viewPadding.bottom;
          // Abstand zum Bildschirmrand, damit der weiße Rahmen unten sichtbar bleibt.
          const outerBottomGap = 14.0;
          final maxSheetHeight =
              mq.size.height * 0.88 - bottomSafe - outerBottomGap;
          const headerBlockHeight = 118.0;
          const footerBlockHeight = 80.0;

          final editableIds = draft.editableOrderForSession(
            isFreeDj: isFreeDj,
            trialUsed: trialUsed,
          );

          void reorder(int oldIndex, int newIndex) {
            setSheetState(() {
              draft = draft.withEditableReorder(
                isFreeDj: isFreeDj,
                trialUsed: trialUsed,
                oldIndex: oldIndex,
                newIndex: newIndex,
              );
            });
          }

          final listContentHeight = editableIds.length * 64.0 + 8;
          final sheetHeight = (headerBlockHeight +
                  listContentHeight +
                  footerBlockHeight)
              .clamp(280.0, maxSheetHeight);

          return Padding(
            padding: EdgeInsets.only(
              left: 6,
              right: 6,
              bottom: bottomSafe + outerBottomGap,
            ),
            child: SizedBox(
              height: sheetHeight,
              child: Container(
                decoration: UIConstants.djHomeEditSheetDecoration,
                clipBehavior: Clip.antiAlias,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.dj_home_edit_title,
                            style: const TextStyle(
                              color: UIConstants.colorWhite,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      l.dj_home_edit_hint,
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  ),
                  Flexible(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: editableIds.length,
                      onReorder: reorder,
                      itemBuilder: (context, index) {
                        final id = editableIds[index];
                        final enabled = draft.enabled[id] ?? false;
                        final toggleLocked = DjHomeWidgetId.isToggleLocked(id);

                        return Card(
                          key: ValueKey(id),
                          color: Colors.black.withValues(alpha: 0.25),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.drag_handle,
                                  color: Colors.white54,
                                  size: 22,
                                ),
                              ),
                            ),
                            title: Text(
                              DjHomeWidgetId.label(l, id),
                              style: const TextStyle(
                                color: UIConstants.colorWhite,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: () {
                              final sub = DjHomeWidgetId.editSubtitle(l, id);
                              if (sub == null || sub.isEmpty) {
                                return null;
                              }
                              return Text(
                                sub,
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              );
                            }(),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SettingsInfoIconButton(
                                  tooltip: l.settings_help_tooltip,
                                  onPressed: () => showSettingsHelpDialog(
                                    context,
                                    title: DjHomeWidgetId.label(l, id),
                                    intro: l.translate(
                                      'info_dj_home_${id}_intro',
                                    ),
                                    bullets: [
                                      SettingsHelpBullet(
                                        title: l.translate(
                                          'info_dj_home_${id}_what',
                                        ),
                                        body: l.translate(
                                          'info_dj_home_${id}_what_body',
                                        ),
                                      ),
                                      SettingsHelpBullet(
                                        title: l.translate(
                                          'info_dj_home_${id}_when',
                                        ),
                                        body: l.translate(
                                          'info_dj_home_${id}_when_body',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 52,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: toggleLocked
                                        ? Icon(
                                            Icons.check_circle_outline,
                                            color: UIConstants.appOrange
                                                .withValues(alpha: 0.85),
                                            size: 22,
                                          )
                                        : Switch(
                                            value: enabled,
                                            activeThumbColor:
                                                UIConstants.appOrange,
                                            onChanged: (v) {
                                              setSheetState(() {
                                                draft = draft.copyWith(
                                                  enabled: {
                                                    ...draft.enabled,
                                                    id: v,
                                                  },
                                                );
                                              });
                                            },
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      16 + mq.viewInsets.bottom,
                    ),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: UIConstants.appOrange,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        await DjHomeLayoutService.instance.save(
                          draft,
                          isFreeDj: isFreeDj,
                          trialUsed: trialUsed,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(l.save),
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
        },
      );
    },
  );
}
