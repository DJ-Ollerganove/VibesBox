import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/ui_constants.dart';

class HomeGuestInfo extends StatelessWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;
  final VoidCallback? onLoginRequested;
  final VoidCallback? onRegisterRequested;

  const HomeGuestInfo({
    super.key,
    required this.cardBuilder,
    this.onLoginRequested,
    this.onRegisterRequested,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);

    Widget checkItem(String text) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: 8,
          left: isRtl ? 0 : 28,
          right: isRtl ? 28 : 0,
        ),
        child: Row(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: isRtl ? TextAlign.right : null,
              ),
            ),
          ],
        ),
      );
    }

    Widget guestItem(IconData icon, String text) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: 8,
          left: isRtl ? 0 : 28,
          right: isRtl ? 28 : 0,
        ),
        child: Row(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: UIConstants.appOrange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: isRtl ? TextAlign.right : null,
              ),
            ),
          ],
        ),
      );
    }

    return cardBuilder(
      context,
      isRtl
          ? Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.logged_in_user_more_features,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  checkItem(l.view_your_wishes_anytime),
                  checkItem(l.manage_edit_profile),
                  checkItem(l.view_wish_statistics),
                  checkItem(l.edit_greetings),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l.additional_features_note,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.start,
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    textDirection: TextDirection.rtl,
                    children: [
                      SizedBox(
                        width: 112,
                        height: 34,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: UIConstants.appOrange,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed:
                              onRegisterRequested ??
                              () => Navigator.pushNamed(context, '/register'),
                          child: Text(
                            l.register_now,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 112,
                        height: 34,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: UIConstants.appOrange,
                            side: const BorderSide(color: UIConstants.appOrange, width: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: onLoginRequested ?? () => Navigator.pushNamed(context, '/login'),
                          child: Text(
                            l.or_login,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 24, color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l.available_as_guest,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.start,
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  const SizedBox(height: 8),
                  guestItem(Icons.music_note, l.send_music_wishes),
                  guestItem(Icons.contact_mail, l.use_contact_form),
                  guestItem(Icons.share, l.open_social_media_links),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.logged_in_user_more_features,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                checkItem(l.view_your_wishes_anytime),
                checkItem(l.manage_edit_profile),
                checkItem(l.view_wish_statistics),
                checkItem(l.edit_greetings),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l.additional_features_note,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.start,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  textDirection: TextDirection.ltr,
                  children: [
                    SizedBox(
                      width: 112,
                      height: 34,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: UIConstants.appOrange,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed:
                            onRegisterRequested ??
                            () => Navigator.pushNamed(context, '/register'),
                        child: Text(
                          l.register_now,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 112,
                      height: 34,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: UIConstants.appOrange,
                          side: const BorderSide(color: UIConstants.appOrange, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: onLoginRequested ?? () => Navigator.pushNamed(context, '/login'),
                        child: Text(
                          l.or_login,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(height: 24, color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l.available_as_guest,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.start,
                  ),
                ),
                const SizedBox(height: 8),
                guestItem(Icons.music_note, l.send_music_wishes),
                guestItem(Icons.contact_mail, l.use_contact_form),
                guestItem(Icons.share, l.open_social_media_links),
              ],
            ),
    );
  }
}

class HomeNavigationHint extends StatelessWidget {
  final Widget Function(BuildContext context, Widget child) cardBuilder;

  const HomeNavigationHint({
    super.key,
    required this.cardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = ['ar', 'he', 'fa', 'ur'].contains(Localizations.localeOf(context).languageCode);
    return cardBuilder(
      context,
      isRtl
          ? Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.navigation_menu_can_do,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(right: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '• ${l.see_vibesbox}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• ${l.view_edit_profile}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• ${l.see_your_submitted_wishes}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• ${l.use_contact_form}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• ${l.open_social_media_links}',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.navigation_menu_can_do,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ${l.see_vibesbox}', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text('• ${l.view_edit_profile}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text('• ${l.see_your_submitted_wishes}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text('• ${l.use_contact_form}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text('• ${l.open_social_media_links}',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}


