import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/active_party_service.dart';
import '../services/wish_management_service.dart';
import '../utils/ui_constants.dart';

/// Lokalisierte Datums-/Uhrzeit-Formatierung für abgelehnte Wünsche (nur Anzeige).
class RejectedWishLocaleFormats {
  RejectedWishLocaleFormats._();

  static String localeTag(BuildContext context) =>
      Localizations.localeOf(context).toString();

  static String formatDate(DateTime dateTime, String locale) =>
      DateFormat.yMMMd(locale).format(dateTime);

  static String formatTime(DateTime dateTime, String locale) =>
      DateFormat.jm(locale).format(dateTime);
}

/// Bestätigungsdialog „Wunsch wieder öffnen?“ mit Gradient-Panel und orangem Rahmen.
///
/// Nach „Ja“ schließt dieser Dialog sofort. Aufrufer führen das Firestore-Update aus,
/// schließen bei Erfolg den Detail-Dialog ([Navigator.pop] mit Detail-[BuildContext])
/// und wechseln z. B. per [RejectedWishesPage.onWishRestoredToOpen] zum Tab „Offen“.
class RejectedWishReopenConfirmDialog extends StatelessWidget {
  const RejectedWishReopenConfirmDialog({super.key, required this.l});

  final AppLocalizations l;

  static Future<bool?> show(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    if (loc == null) return null;
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => RejectedWishReopenConfirmDialog(l: loc),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Gleiche Button-Styles wie z. B. showConfirmDeleteGroupedDialog /
    // showConfirmUpdateGroupedStatusDialog in [WishManagementService].
    final isRtl = ['ar', 'he', 'fa', 'ur']
        .contains(Localizations.localeOf(context).languageCode);

    final confirmButton = ElevatedButton(
      onPressed: () => Navigator.of(context).pop(true),
      style: ElevatedButton.styleFrom(
        backgroundColor: UIConstants.frameGespielt,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(l.confirm_reopen_yes),
    );

    final cancelButton = ElevatedButton(
      onPressed: () => Navigator.of(context).pop(false),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade800,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(l.confirm_reopen_no),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Directionality(
        textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF121212),
                Color(0xFF1E1E1E),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF8C42),
              width: 3,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.confirm_reopen_title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l.confirm_reopen_message,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  confirmButton,
                  const SizedBox(width: 12),
                  cancelButton,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail-Dialog für gruppierte abgelehnte Wünsche (optional nutzbar).
/// Zeigt [sent_at]/Ablehnung mit [DateFormat.yMMMd] und [DateFormat.jm].
class RejectedWishGroupedDetailDialog {
  RejectedWishGroupedDetailDialog._();

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> data,
    required List<String> docIds,
    required Future<void> Function() onRestoreConfirmed,
  }) async {
    final isRtl = ['ar', 'he', 'fa', 'ur']
        .contains(Localizations.localeOf(context).languageCode);
    final l = AppLocalizations.of(context);
    if (l == null) return;

    final title = (data['title'] ?? data['song'] ?? '') as String;
    final artist = (data['artist'] ?? '') as String;
    final displayText = title.isNotEmpty && artist.isNotEmpty
        ? '$title - $artist'
        : (title.isNotEmpty ? title : artist);

    final locale = RejectedWishLocaleFormats.localeTag(context);
    final createdTs = data['createdAt'];
    final rejectedTs = data['rejected_at'] ?? data['rejectedAt'];

    DateTime? createdDt;
    if (createdTs is Timestamp) {
      createdDt = createdTs.toDate();
    }
    DateTime? rejectedDt;
    if (rejectedTs is Timestamp) {
      rejectedDt = rejectedTs.toDate();
    }

    String? submittedLine;
    if (createdDt != null) {
      final d = RejectedWishLocaleFormats.formatDate(createdDt, locale);
      final t = RejectedWishLocaleFormats.formatTime(createdDt, locale);
      submittedLine = l.wish_timeline_submitted(d, t);
    }
    String? rejectedLine;
    if (rejectedDt != null) {
      final d = RejectedWishLocaleFormats.formatDate(rejectedDt, locale);
      final t = RejectedWishLocaleFormats.formatTime(rejectedDt, locale);
      rejectedLine = l.wish_timeline_rejected(d, t);
    }

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(
              color: UIConstants.frameAbgelehnt,
              width: 2.0,
            ),
          ),
          title: Text(
            displayText,
            style: const TextStyle(color: Colors.white),
            textAlign: isRtl ? TextAlign.right : TextAlign.left,
          ),
          content: Directionality(
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isRtl
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    l.wish_group_count(docIds.length),
                    style: const TextStyle(color: Colors.white),
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  ),
                  if (submittedLine != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      submittedLine,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    ),
                  ],
                  if (rejectedLine != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      rejectedLine,
                      style: const TextStyle(color: Colors.white70),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    ),
                  ],
                  if (ActivePartyService.currentPartyId != null &&
                      ActivePartyService.currentPartyId!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        final ok = await RejectedWishReopenConfirmDialog.show(
                          context,
                        );
                        if (ok == true && context.mounted) {
                          await onRestoreConfirmed();
                        }
                      },
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      label: Text(
                        l.back_to_open,
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UIConstants.frameOffen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        openDeleteFlow(context, docIds, displayText);
                      },
                      icon: const Icon(Icons.delete, color: Colors.white),
                      label: Text(
                        l.delete,
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UIConstants.frameNoParty,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                l.close,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lösch-Dialog nach Schließen des Gruppen-Details (gleiche Logik wie zuvor in [AbgelehntPage]).
  static void openDeleteFlow(
    BuildContext context,
    List<String> docIds,
    String displayText,
  ) {
    final partyId = ActivePartyService.currentPartyId;
    if (partyId != null && partyId.isNotEmpty) {
      WishManagementService.showConfirmDeleteGroupedDialog(
        context,
        docIds,
        displayText,
        partyId,
      );
    }
  }
}
