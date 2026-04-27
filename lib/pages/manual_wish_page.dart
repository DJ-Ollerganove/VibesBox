import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../helpers/security_helper.dart';
import '../l10n/app_localizations.dart';
import '../services/duplicate_check_service.dart';
import '../services/spotify_service.dart';
import '../utils/ui_constants.dart';

/// Gewählter Künstler (Name + ID für abhängige Suche) — identisch zur Gäste-[WishesFormWidget]-Logik.
class _SelectedArtist {
  final String id;
  final String name;
  const _SelectedArtist({required this.id, required this.name});
}

/// DJ: manueller Wunsch — Interpret/Titel mit derselben Spotify-Suche & Autocomplete-UI wie in der Gäste-Wunschbox.
class ManualWishPage extends StatefulWidget {
  final String partyId;

  const ManualWishPage({super.key, required this.partyId});

  @override
  State<ManualWishPage> createState() => _ManualWishPageState();
}

class _ManualWishPageState extends State<ManualWishPage> {
  final _formKey = GlobalKey<FormState>();
  final _artistController = TextEditingController();
  final _titleController = TextEditingController();
  final _greetingController = TextEditingController();

  _SelectedArtist? _selectedArtist;

  List<SpotifyArtist> _artistSuggestions = [];
  List<SpotifyTrack> _titleSuggestions = [];
  bool _artistLoading = false;
  bool _titleLoading = false;
  bool _titleCatalogMode = false;

  Timer? _artistDebounce;
  Timer? _titleDebounce;
  int _artistSearchId = 0;
  int _titleSearchId = 0;

  bool _saving = false;

  /// PWA / Gäste-Wunschbox: gleiche Rahmen-Optik
  static const _wishInputDecoration = BoxDecoration(
    color: Colors.black,
    borderRadius: BorderRadius.all(Radius.circular(8)),
    border: Border.fromBorderSide(
      BorderSide(color: Color(0xFFFFA500), width: 2),
    ),
  );

  @override
  void initState() {
    super.initState();
    DuplicateCheckService.ensurePartySettingsLoaded();
    _artistController.addListener(_onArtistTextChanged);
  }

  @override
  void dispose() {
    _artistController.removeListener(_onArtistTextChanged);
    _artistController.dispose();
    _titleController.dispose();
    _greetingController.dispose();
    _artistDebounce?.cancel();
    _titleDebounce?.cancel();
    super.dispose();
  }

  void _onArtistTextChanged() {
    final text = _artistController.text.trim();
    if (_selectedArtist != null && text != _selectedArtist!.name) {
      setState(() {
        _selectedArtist = null;
      });
    }
    if (text.isEmpty) {
      setState(() {
        _selectedArtist = null;
        _artistSuggestions = [];
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
      _artistController.text = artist.name;
      _titleController.clear();
      _artistSuggestions = [];
    });
  }

  void _onTrackSelected(SpotifyTrack track) {
    setState(() {
      _selectedArtist = _SelectedArtist(
        id: track.artistIds.isNotEmpty ? track.artistIds.first : '',
        name: track.artistName,
      );
      _titleController.text = track.name;
      _artistController.text = track.artistName;
      _titleSuggestions = [];
    });
  }

  InputDecoration _inputDecoration(
    AppLocalizations l, {
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

  Widget _buildInputContainer({required Widget child}) {
    return Container(decoration: _wishInputDecoration, child: child);
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

  Widget _buildTitleSuggestions(AppLocalizations l) {
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
                l.catalogTopSongs(_selectedArtist!.name),
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

  Future<bool?> _showDuplicateInfoDialog(
    bool inHistory,
    bool inOpenWishes,
  ) async {
    final l = AppLocalizations.of(context)!;
    final String msg;
    if (inHistory && inOpenWishes) {
      msg =
          l.manualWishDuplicateHistoryAndOpen;
    } else if (inHistory) {
      msg =
          l.manualWishDuplicateHistoryOnly;
    } else {
      msg =
          l.manualWishDuplicateOpenOnly;
    }
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          l.duplicates,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: UIConstants.appOrange, width: 2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l.cancel,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l.submitWish,
              style: const TextStyle(
                color: UIConstants.appOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWish() async {
    final title = SecurityHelper.sanitize(_titleController.text.trim());
    final artist = SecurityHelper.sanitize(_artistController.text.trim());
    final l = AppLocalizations.of(context)!;

    if (title.isEmpty || artist.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.wish_title_or_artist_required,
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final inHistory = await DuplicateCheckService.checkIfSongWasPlayed(
      title.isEmpty ? '' : title,
      artist.isEmpty ? '' : artist,
      widget.partyId,
    );
    final inOpenWishes = await DuplicateCheckService.checkIfSongInOpenWishes(
      title.isEmpty ? '' : title,
      artist.isEmpty ? '' : artist,
      widget.partyId,
    );

    if (inHistory || inOpenWishes) {
      final force = await _showDuplicateInfoDialog(inHistory, inOpenWishes);
      if (force != true || !mounted) return;
    }

    setState(() => _saving = true);

    try {
      final partySnap = await FirebaseFirestore.instance
          .collection('parties')
          .doc(widget.partyId)
          .get();
      final djId = (partySnap.data()?['created_by'] as String?)?.trim();
      if (djId == null || djId.isEmpty) {
        throw Exception('DJ-ID der Party konnte nicht ermittelt werden');
      }

      final manualByDj = l.manualByDj;
      final greeting = SecurityHelper.sanitize(_greetingController.text.trim());

      final wishData = <String, dynamic>{
        'name': '',
        'title': title,
        'artist': artist,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'duplicate_count': 0,
        'requested_by': [manualByDj],
        'greetings': greeting.isNotEmpty
            ? [
                {'name': manualByDj, 'greeting': greeting},
              ]
            : [],
        'is_duplicate': false,
        'is_registered_user': true,
        'is_registered_users': {},
        'client_id': FirebaseAuth.instance.currentUser?.uid ?? 'dj',
        'party_id': widget.partyId,
        'dj_id': djId,
        'djId': djId,
        'isSeen': false,
        'is_dj_wish': true,
      };

      await FirebaseFirestore.instance
          .collection('wishes')
          .add(SecurityHelper.sanitizeMap(wishData));

      if (!mounted) return;
      final line = artist.isNotEmpty ? '$artist – $title' : title;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.manualWishSavedSnack(line),
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l.error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          l.addManualWish,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: UIConstants.appOrange,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: UIConstants.appOrange.withValues(
                              alpha: 0.15,
                            ),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Directionality(
                        textDirection: isRtl
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Interpret * — wie Gäste-Wunschbox
                              _buildInputContainer(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Stack(
                                      alignment: Alignment.centerRight,
                                      children: [
                                        TextFormField(
                                          controller: _artistController,
                                          maxLines: 1,
                                          maxLength: 120,
                                          decoration: _inputDecoration(
                                            l,
                                            label:
                                                '${l.wish_artist_label} *',
                                            icon: Icons.mic,
                                          ),
                                          style: const TextStyle(
                                            color: UIConstants.colorWhite,
                                          ),
                                          textCapitalization:
                                              TextCapitalization.words,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.deny(
                                              RegExp(r'[<>]'),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            _artistDebounce?.cancel();
                                            if (value.trim().isEmpty) {
                                              setState(
                                                () => _artistSuggestions = [],
                                              );
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
                                            if (_artistController.text
                                                    .trim()
                                                    .isNotEmpty &&
                                                _artistSuggestions.isEmpty) {
                                              _searchArtists(
                                                _artistController.text,
                                              );
                                            }
                                          },
                                          validator: (_) => null,
                                        ),
                                        if (_artistLoading)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 12),
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (_artistSuggestions.isNotEmpty)
                                      _buildArtistSuggestions(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l.suggestionsAutoAppear,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              // Titel * — wie Gäste-Wunschbox
                              _buildInputContainer(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Stack(
                                      alignment: Alignment.centerRight,
                                      children: [
                                        TextFormField(
                                          controller: _titleController,
                                          maxLines: 1,
                                          maxLength: 120,
                                          decoration: _inputDecoration(
                                            l,
                                            label:
                                                '${l.wish_title_label} *',
                                            icon: Icons.music_note_outlined,
                                          ),
                                          style: const TextStyle(
                                            color: UIConstants.colorWhite,
                                          ),
                                          textCapitalization:
                                              TextCapitalization.words,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.deny(
                                              RegExp(r'[<>]'),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            _titleDebounce?.cancel();
                                            if (value.trim().isEmpty) {
                                              setState(
                                                () => _titleSuggestions = [],
                                              );
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
                                            final isEmpty = _titleController
                                                .text
                                                .trim()
                                                .isEmpty;
                                            if (isEmpty &&
                                                _selectedArtist != null) {
                                              _searchTracks(
                                                '',
                                                catalogMode: true,
                                              );
                                            } else if (_titleController.text
                                                    .trim()
                                                    .isNotEmpty &&
                                                _titleSuggestions.isEmpty) {
                                              _searchTracks(
                                                _titleController.text,
                                              );
                                            }
                                          },
                                          validator: (_) => null,
                                        ),
                                        if (_titleLoading)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 12),
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (_titleSuggestions.isNotEmpty)
                                      _buildTitleSuggestions(l),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildInputContainer(
                                child: TextFormField(
                                  controller: _greetingController,
                                  decoration: InputDecoration(
                                    labelText:
                                        l.wish_greeting_label,
                                    prefixIcon: const Icon(
                                      Icons.chat_bubble_outline,
                                      color: UIConstants.colorWhite,
                                    ),
                                    helperText:
                                        l.wish_greeting_max_chars,
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    labelStyle: const TextStyle(
                                      color: UIConstants.colorGrey,
                                    ),
                                    helperStyle: const TextStyle(
                                      color: UIConstants.colorGrey,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: UIConstants.colorWhite,
                                  ),
                                  maxLength: 160,
                                  maxLines: 3,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.deny(
                                      RegExp(r'[<>]'),
                                    ),
                                  ],
                                  textAlign: isRtl
                                      ? TextAlign.right
                                      : TextAlign.left,
                                  textDirection: isRtl
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  validator: (value) {
                                    if (value != null && value.length > 160) {
                                      return l.wish_greeting_max_chars_error;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _saveWish,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: UIConstants.appOrange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          l.submitWish,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
