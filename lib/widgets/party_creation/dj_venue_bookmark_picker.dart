import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/venue_bookmark_model.dart';
import '../../services/dj_venue_bookmark_service.dart';
import '../../utils/ui_constants.dart';

/// Persönliche Ort-Liste (öffentlich + privat) für Party-Wizard.
class DjVenueBookmarkPicker extends StatelessWidget {
  const DjVenueBookmarkPicker({
    super.key,
    required this.onBookmarkSelected,
  });

  final ValueChanged<VenueBookmarkModel> onBookmarkSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<VenueBookmarkModel>>(
      stream: DjVenueBookmarkService().watchBookmarks(uid),
      builder: (context, snapshot) {
        final bookmarks = snapshot.data ?? const [];
        if (bookmarks.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.venue_bookmarks_title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ...bookmarks.take(8).map((bookmark) {
              final subtitle = bookmark.address?.trim().isNotEmpty == true
                  ? bookmark.address!.trim()
                  : bookmark.timezoneId;
              return Card(
                color: Colors.black,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: UIConstants.appOrange, width: 1),
                ),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    bookmark.source == VenueBookmarkModel.sourcePublic
                        ? Icons.apartment
                        : Icons.bookmark,
                    color: UIConstants.appOrange,
                  ),
                  title: Text(
                    bookmark.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: TextButton(
                    onPressed: () => onBookmarkSelected(bookmark),
                    child: Text(l.venue_bookmarks_use),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
