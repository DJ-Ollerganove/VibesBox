import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../helpers/security_helper.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/ui_constants.dart';

/// Dialog: Titel/Interpret per Haken oder Freitext in die Blacklist.
class DjSongBlacklistAddDialog extends StatefulWidget {
  const DjSongBlacklistAddDialog({
    super.key,
    this.initialTitle = '',
    this.initialArtist = '',
    this.useCheckboxes = false,
    this.dialogTitleKey = 'song_blacklist_dialog_title',
  });

  final String initialTitle;
  final String initialArtist;
  final bool useCheckboxes;
  final String dialogTitleKey;

  static Future<(String title, String artist)?> show({
    required BuildContext context,
    String title = '',
    String artist = '',
    bool useCheckboxes = false,
    String dialogTitleKey = 'song_blacklist_dialog_title',
  }) {
    return showDialog<(String, String)>(
      context: context,
      builder: (ctx) => DjSongBlacklistAddDialog(
        initialTitle: title,
        initialArtist: artist,
        useCheckboxes: useCheckboxes,
        dialogTitleKey: dialogTitleKey,
      ),
    );
  }

  @override
  State<DjSongBlacklistAddDialog> createState() =>
      _DjSongBlacklistAddDialogState();
}

class _DjSongBlacklistAddDialogState extends State<DjSongBlacklistAddDialog> {
  late final TextEditingController _title;
  late final TextEditingController _artist;
  late bool _useTitle;
  late bool _useArtist;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initialTitle);
    _artist = TextEditingController(text: widget.initialArtist);
    _useTitle = widget.initialTitle.trim().isNotEmpty;
    _useArtist = widget.initialArtist.trim().isNotEmpty;
    if (!_useTitle && !_useArtist) {
      _useTitle = true;
      _useArtist = true;
    }
    _title.addListener(_onChanged);
    _artist.addListener(_onChanged);
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSave {
    if (widget.useCheckboxes) {
      final t = _useTitle && _title.text.trim().isNotEmpty;
      final a = _useArtist && _artist.text.trim().isNotEmpty;
      return t || a;
    }
    return _title.text.trim().isNotEmpty || _artist.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: UIConstants.djShellPageBackground,
      title: Text(
        l.translate(widget.dialogTitleKey),
        style: const TextStyle(color: Colors.white),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: UIConstants.colorSongBlacklist, width: 2),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.useCheckboxes) ...[
            CheckboxListTile(
              value: _useTitle,
              onChanged: _title.text.trim().isEmpty
                  ? null
                  : (v) => setState(() => _useTitle = v == true),
              activeColor: UIConstants.colorSongBlacklist,
              title: Text(
                _title.text.trim().isEmpty
                    ? l.wish_title_label
                    : _title.text.trim(),
                style: const TextStyle(color: Colors.white),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              value: _useArtist,
              onChanged: _artist.text.trim().isEmpty
                  ? null
                  : (v) => setState(() => _useArtist = v == true),
              activeColor: UIConstants.colorSongBlacklist,
              title: Text(
                _artist.text.trim().isEmpty
                    ? l.wish_artist_label
                    : _artist.text.trim(),
                style: const TextStyle(color: Colors.white),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ] else ...[
            TextField(
              controller: _title,
              style: const TextStyle(color: Colors.white),
              maxLength: 100,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              decoration: InputDecoration(
                labelText: l.wish_title_label,
                labelStyle: const TextStyle(color: Colors.white70),
                counterText: '',
              ),
            ),
            TextField(
              controller: _artist,
              style: const TextStyle(color: Colors.white),
              maxLength: 100,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              decoration: InputDecoration(
                labelText: l.wish_artist_label,
                labelStyle: const TextStyle(color: Colors.white70),
                counterText: '',
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel, style: const TextStyle(color: Colors.white70)),
        ),
        TextButton(
          onPressed: _canSave
              ? () {
                  final t = SecurityHelper.sanitize(
                    widget.useCheckboxes
                        ? (_useTitle ? _title.text : '')
                        : _title.text,
                    maxLength: 100,
                  );
                  final a = SecurityHelper.sanitize(
                    widget.useCheckboxes
                        ? (_useArtist ? _artist.text : '')
                        : _artist.text,
                    maxLength: 100,
                  );
                  Navigator.pop(context, (t, a));
                }
              : null,
          child: Text(
            l.save,
            style: TextStyle(
              color: UIConstants.colorSongBlacklist,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
