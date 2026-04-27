import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/spotify_service.dart';
import '../utils/ui_constants.dart';
import '../utils/network_image_url.dart';
import '../helpers/security_helper.dart';

/// Gewählter Künstler (Name + ID für abhängige Suche).
class _SelectedArtist {
  final String id;
  final String name;
  const _SelectedArtist({required this.id, required this.name});
}

/// Widget für das Formular zum Absenden von Musikwünschen.
/// Layout wie PWA: Header (Schicke Deinen Musikwunsch an), DJ-Name als Überschrift,
/// optional DJ-Logo darunter, Disclaimer, Felder Interpret/Titel/Name/Gruß mit Icons links.
class WishesFormWidget extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController titleController;
  final TextEditingController artistController;
  final TextEditingController greetingController;
  final Future<void> Function() onSubmit;
  final void Function(String? spotifyId, int? durationMs)?
  onSpotifyTrackSelected;
  final String? guestName;

  /// true wenn User angemeldet ist UND ein Name in der users-Collection hinterlegt ist.
  final bool hasProfileName;
  final int wishLimit;
  final int wishCount;
  final int wishRemaining;
  final DateTime? nextFullHour;

  /// DJ-Name aus Party-Dokument (für Header-Branding)
  final String? djName;

  /// DJ-Logo-URL aus Party dj_logo (optional unter dem Namen)
  final String? djLogoUrl;

  const WishesFormWidget({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.titleController,
    required this.artistController,
    required this.greetingController,
    required this.onSubmit,
    this.onSpotifyTrackSelected,
    this.guestName,
    this.hasProfileName = false,
    required this.wishLimit,
    required this.wishCount,
    required this.wishRemaining,
    this.nextFullHour,
    this.djName,
    this.djLogoUrl,
  });

  @override
  State<WishesFormWidget> createState() => _WishesFormWidgetState();
}

class _WishesFormWidgetState extends State<WishesFormWidget> {
  _SelectedArtist? _selectedArtist;
  SpotifyTrack? _selectedTrack;

  List<SpotifyArtist> _artistSuggestions = [];
  List<SpotifyTrack> _titleSuggestions = [];
  bool _artistLoading = false;
  bool _titleLoading = false;
  bool _titleCatalogMode = false; // Top-Songs von [Künstler]

  Timer? _artistDebounce;
  Timer? _titleDebounce;
  int _artistSearchId = 0;
  int _titleSearchId = 0;

  @override
  void initState() {
    super.initState();
    widget.artistController.addListener(_onArtistTextChanged);
  }

  @override
  void dispose() {
    widget.artistController.removeListener(_onArtistTextChanged);
    _artistDebounce?.cancel();
    _titleDebounce?.cancel();
    super.dispose();
  }

  void _onArtistTextChanged() {
    final text = widget.artistController.text.trim();
    if (_selectedArtist != null && text != _selectedArtist!.name) {
      setState(() {
        _selectedArtist = null;
        _selectedTrack = null;
        widget.onSpotifyTrackSelected?.call(null, null);
      });
    }
    if (text.isEmpty) {
      setState(() {
        _selectedArtist = null;
        _selectedTrack = null;
        _artistSuggestions = [];
        widget.onSpotifyTrackSelected?.call(null, null);
      });
    }
  }

  Future<void> _searchArtists(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _artistSuggestions = []);
      return;
    }
    setState(() => _artistLoading = true);
    final id = ++_artistSearchId;
    try {
      final result = await SpotifyService.instance.search(
        q: query.trim().replaceAll('"', ''),
        type: 'artist',
      );
      if (!mounted || id != _artistSearchId) return;
      setState(() {
        _artistSuggestions = result.artists;
        _artistLoading = false;
      });
    } catch (e) {
      if (!mounted || id != _artistSearchId) return;
      setState(() {
        _artistSuggestions = [];
        _artistLoading = false;
      });
    }
  }

  Future<void> _searchTracks(String query, {bool catalogMode = false}) async {
    setState(() => _titleLoading = true);
    final id = ++_titleSearchId;
    String searchQ;
    if (catalogMode && _selectedArtist != null) {
      final clean = _selectedArtist!.name.replaceAll('"', '');
      searchQ = 'artist:"$clean"';
    } else if (_selectedArtist != null && query.trim().isNotEmpty) {
      final cleanArtist = _selectedArtist!.name.replaceAll('"', '');
      final cleanTrack = query.trim().replaceAll('"', '');
      searchQ = 'artist:"$cleanArtist" track:"$cleanTrack"';
    } else {
      searchQ = query.trim().replaceAll('"', '');
    }
    if (searchQ.isEmpty && !catalogMode) {
      setState(() {
        _titleSuggestions = [];
        _titleLoading = false;
      });
      return;
    }
    try {
      final result = await SpotifyService.instance.search(
        q: searchQ,
        type: 'track',
      );
      if (!mounted || id != _titleSearchId) return;
      setState(() {
        _titleSuggestions = result.tracks;
        _titleCatalogMode = catalogMode;
        _titleLoading = false;
      });
    } catch (e) {
      if (!mounted || id != _titleSearchId) return;
      setState(() {
        _titleSuggestions = [];
        _titleLoading = false;
      });
    }
  }

  void _onArtistSelected(SpotifyArtist artist) {
    setState(() {
      _selectedArtist = _SelectedArtist(id: artist.id, name: artist.name);
      _selectedTrack = null;
      widget.onSpotifyTrackSelected?.call(null, null);
      widget.artistController.text = artist.name;
      widget.titleController.clear();
      _artistSuggestions = [];
    });
  }

  void _onTrackSelected(SpotifyTrack track) {
    setState(() {
      _selectedTrack = track;
      _selectedArtist = _SelectedArtist(
        id: track.artistIds.isNotEmpty ? track.artistIds.first : '',
        name: track.artistName,
      );
      widget.titleController.text = track.name;
      widget.artistController.text = track.artistName;
      widget.onSpotifyTrackSelected?.call(track.id, track.durationMs);
      _titleSuggestions = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Form(
        key: widget.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PWA-Header: DJ-Name oben, dann Einleitung, optional Logo nur bei gültiger URL
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  if (widget.djName != null &&
                      widget.djName!.trim().isNotEmpty) ...[
                    Text(
                      widget.djName!.trim(),
                      style: const TextStyle(
                        color: Color(0xFFFFA500),
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    localizations.pwaRequestHeaderText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isHttpImageUrl(widget.djLogoUrl)) ...[
                    const SizedBox(height: 10),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            widget.djLogoUrl!.trim(),
                            height: 72,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Disclaimer (PWA: rötlich-orange #e57373)
            Text(
              localizations.wishSentDisclaimer,
              style: const TextStyle(
                color: Color(0xFFE57373),
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // 1. Interpret * (Mikrofon-Icon links)
            _buildInputContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      TextFormField(
                        controller: widget.artistController,
                        maxLength: 100,
                        maxLines: 1,
                        decoration: _inputDecoration(
                          label: '${localizations.wish_artist_label} *',
                          icon: Icons.mic,
                        ),
                        style: const TextStyle(color: UIConstants.colorWhite),
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) {
                          final safe = SecurityHelper.sanitize(
                            value,
                            maxLength: 100,
                            trimInput: false,
                          );
                          if (safe != value) {
                            widget.artistController.value = widget
                                .artistController
                                .value
                                .copyWith(
                                  text: safe,
                                  selection: TextSelection.collapsed(
                                    offset: safe.length,
                                  ),
                                );
                            value = safe;
                          }
                          _artistDebounce?.cancel();
                          if (value.trim().isEmpty) {
                            setState(() => _artistSuggestions = []);
                            return;
                          }
                          _artistDebounce = Timer(
                            const Duration(milliseconds: 500),
                            () {
                              _searchArtists(value);
                            },
                          );
                        },
                        onTap: () {
                          if (widget.artistController.text.trim().isNotEmpty &&
                              _artistSuggestions.isEmpty) {
                            _searchArtists(widget.artistController.text);
                          }
                        },
                        validator: (value) => null,
                        onFieldSubmitted: (_) => widget.onSubmit(),
                      ),
                      if (_artistLoading)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                  if (_artistSuggestions.isNotEmpty) _buildArtistSuggestions(),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              localizations.suggestionsAutoAppear,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // 2. Titel * (Noten-Icon links)
            _buildInputContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      TextFormField(
                        controller: widget.titleController,
                        maxLength: 100,
                        maxLines: 1,
                        decoration: _inputDecoration(
                          label: '${localizations.wish_title_label} *',
                          icon: Icons.music_note_outlined,
                        ),
                        style: const TextStyle(color: UIConstants.colorWhite),
                        textCapitalization: TextCapitalization.words,
                        onChanged: (value) {
                          final safe = SecurityHelper.sanitize(
                            value,
                            maxLength: 100,
                            trimInput: false,
                          );
                          if (safe != value) {
                            widget.titleController.value = widget
                                .titleController
                                .value
                                .copyWith(
                                  text: safe,
                                  selection: TextSelection.collapsed(
                                    offset: safe.length,
                                  ),
                                );
                            value = safe;
                          }
                          _titleDebounce?.cancel();
                          if (value.trim().isEmpty) {
                            setState(() => _titleSuggestions = []);
                            return;
                          }
                          _titleDebounce = Timer(
                            const Duration(milliseconds: 500),
                            () {
                              _searchTracks(value);
                            },
                          );
                        },
                        onTap: () {
                          final isEmpty = widget.titleController.text
                              .trim()
                              .isEmpty;
                          if (isEmpty && _selectedArtist != null) {
                            _searchTracks('', catalogMode: true);
                          } else if (widget.titleController.text
                                  .trim()
                                  .isNotEmpty &&
                              _titleSuggestions.isEmpty) {
                            _searchTracks(widget.titleController.text);
                          }
                        },
                        validator: (value) => null,
                        onFieldSubmitted: (_) => widget.onSubmit(),
                      ),
                      if (_titleLoading)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                  if (_titleSuggestions.isNotEmpty)
                    _buildTitleSuggestions(localizations),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 3. Dein Name * (Person-Icon links)
            Builder(
              builder: (context) {
                final isReadOnly = widget.hasProfileName;
                return _buildInputContainer(
                  child: TextFormField(
                    controller: widget.nameController,
                    maxLength: 50,
                    readOnly: isReadOnly,
                    maxLines: 1,
                    decoration: _inputDecoration(
                      label: '${localizations.contact_name_label} *',
                      icon: Icons.person_outline,
                    ),
                    style: TextStyle(
                      color: isReadOnly
                          ? UIConstants.colorWhite.withValues(alpha: 0.75)
                          : UIConstants.colorWhite,
                    ),
                    textCapitalization: TextCapitalization.words,
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    textDirection: isRtl
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    onChanged: isReadOnly
                        ? null
                        : (value) {
                            final safe = SecurityHelper.sanitize(
                              value,
                              maxLength: 50,
                              trimInput: false,
                            );
                            if (safe != value) {
                              widget.nameController.value = widget
                                  .nameController
                                  .value
                                  .copyWith(
                                    text: safe,
                                    selection: TextSelection.collapsed(
                                      offset: safe.length,
                                    ),
                                  );
                            }
                          },
                    validator: (value) {
                      return (value == null || value.trim().isEmpty)
                          ? localizations.contact_validation_enter_name
                          : null;
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // 4. Gruß (optional)
            _buildInputContainer(
              child: TextFormField(
                controller: widget.greetingController,
                decoration: InputDecoration(
                  labelText: localizations.wish_greeting_label,
                  prefixIcon: const Icon(
                    Icons.chat_bubble_outline,
                    color: UIConstants.colorWhite,
                  ),
                  helperText: localizations.wish_greeting_max_chars,
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  labelStyle: const TextStyle(color: UIConstants.colorGrey),
                  helperStyle: const TextStyle(color: UIConstants.colorGrey),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                style: const TextStyle(color: UIConstants.colorWhite),
                maxLength: 160,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                textAlign: isRtl ? TextAlign.right : TextAlign.left,
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                onChanged: (value) {
                  final safe = SecurityHelper.sanitize(
                    value,
                    maxLength: 160,
                    trimInput: false,
                  );
                  if (safe != value) {
                    widget.greetingController.value = widget
                        .greetingController
                        .value
                        .copyWith(
                          text: safe,
                          selection: TextSelection.collapsed(
                            offset: safe.length,
                          ),
                        );
                  }
                },
                validator: (value) {
                  if (value != null && value.length > 160) {
                    return localizations.wish_greeting_max_chars_error;
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.wishRemaining > 0
                  ? localizations.wish_limit_remaining(
                      widget.wishRemaining,
                      widget.wishLimit,
                    )
                  : localizations.wish_limit_reset_next_hour,
              style: const TextStyle(color: Colors.white, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onSubmit,
                icon: const Icon(Icons.send),
                label: Text(
                  localizations.submitWish,
                  style: const TextStyle(
                    color: UIConstants.colorWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UIConstants.appGreenSuccess,
                  foregroundColor: UIConstants.colorWhite,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PWA-Stil: Tiefschwarz, oranger Rahmen (#FFA500)
  static final _wishInputDecoration = BoxDecoration(
    color: Colors.black,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: const Color(0xFFFFA500), width: 2),
  );

  Widget _buildInputContainer({required Widget child}) {
    return Container(decoration: _wishInputDecoration, child: child);
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: UIConstants.colorWhite),
      filled: true,
      fillColor: Colors.transparent,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      labelStyle: const TextStyle(color: UIConstants.colorGrey),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildArtistSuggestions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00F2FF), width: 0.5),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _artistSuggestions.length,
        itemBuilder: (context, i) {
          final a = _artistSuggestions[i];
          return InkWell(
            onTap: () => _onArtistSelected(a),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Row(
                children: [
                  const Text('🎤', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      a.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitleSuggestions(AppLocalizations localizations) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 8),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00F2FF), width: 0.5),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        children: [
          if (_titleCatalogMode && _selectedArtist != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF00F2FF).withValues(alpha: 0.06),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF00F2FF).withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Text(
                localizations.catalogTopSongs(_selectedArtist!.name),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ...List.generate(_titleSuggestions.length, (i) {
            final t = _titleSuggestions[i];
            return InkWell(
              onTap: () => _onTrackSelected(t),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎵', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            t.artistName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
