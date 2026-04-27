import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/vibesbox_social_service.dart';
import '../services/party_session_service.dart';
import '../utils/social_platform_icons.dart';
import '../widgets/common/pwa_widget_cell.dart';
import '../config/app_config.dart';
import '../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart' show themeModeNotifier;
import '../l10n/app_localizations.dart';
import '../widgets/free_feature_locked.dart';
import '../utils/ui_constants.dart';
import '../utils/network_image_url.dart';
import '../helpers/security_helper.dart';
import '../utils/debug_log.dart';

// Verfügbare Social Media Portale
class SocialMediaPlatform {
  final String id;
  final IconData icon;
  final Color color;
  final String displayNameKey;

  const SocialMediaPlatform({
    required this.id,
    required this.icon,
    required this.color,
    required this.displayNameKey,
  });
}

class SocialMediaPage extends StatefulWidget {
  const SocialMediaPage({super.key});

  @override
  State<SocialMediaPage> createState() => _SocialMediaPageState();
}

class _SocialMediaPageState extends State<SocialMediaPage> {
  String? _pressedIcon;
  bool _isEditing = false;
  bool _isLoading = true;

  /// Gast: true erst nach Abschluss von _loadFromSessionKoffer – verhindert Vorgreifen.
  bool _guestDataReady = false;

  /// Gast: PartyId der zuletzt geladenen Session – für Neu-Laden bei Check-In.
  String? _lastLoadedPartyId;
  Map<String, String> _socialMediaLinks = {};
  List<String> _linkOrder = [];
  final Map<String, TextEditingController> _urlControllers = {};
  bool get _isDarkMode => themeModeNotifier.value == ThemeMode.dark;

  // Verfügbare Social Media Portale
  static const List<SocialMediaPlatform> _availablePlatforms = [
    SocialMediaPlatform(
      id: 'facebook',
      icon: FontAwesomeIcons.facebook,
      color: Color(0xFF1877F2),
      displayNameKey: 'facebook',
    ),
    SocialMediaPlatform(
      id: 'instagram',
      icon: FontAwesomeIcons.instagram,
      color: Color(0xFFE4405F),
      displayNameKey: 'instagram',
    ),
    SocialMediaPlatform(
      id: 'tiktok',
      icon: FontAwesomeIcons.tiktok,
      color: Colors.black,
      displayNameKey: 'tiktok',
    ),
    SocialMediaPlatform(
      id: 'spotify',
      icon: FontAwesomeIcons.spotify,
      color: Color(0xFF1DB954),
      displayNameKey: 'spotify',
    ),
    SocialMediaPlatform(
      id: 'soundcloud',
      icon: FontAwesomeIcons.soundcloud,
      color: Color(0xFFFF5500),
      displayNameKey: 'soundcloud',
    ),
    SocialMediaPlatform(
      id: 'youtube',
      icon: FontAwesomeIcons.youtube,
      color: Color(0xFFFF0000),
      displayNameKey: 'youtube',
    ),
    SocialMediaPlatform(
      id: 'whatsapp',
      icon: FontAwesomeIcons.whatsapp,
      color: Color(0xFF25D366),
      displayNameKey: 'whatsapp',
    ),
    SocialMediaPlatform(
      id: 'website',
      icon: FontAwesomeIcons.globe,
      color: Color(0xFF667eea),
      displayNameKey: 'website',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSocialMediaLinks();
  }

  @override
  void dispose() {
    for (var controller in _urlControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Lädt Daten: In Party → DJ-Links aus Session (egal ob angemeldet).
  /// Nicht in Party + angemeldet → eigene Links aus Firestore zum Bearbeiten.
  Future<void> _loadSocialMediaLinks() async {
    await PartySessionService.instance.loadFromPrefs();
    final hasSession = PartySessionService.instance.hasSession;
    final user = FirebaseAuth.instance.currentUser;
    if (hasSession) {
      await _loadFromSessionKoffer();
      return;
    }
    if (user != null) {
      await _loadFromFirestoreForDj(user.uid);
      return;
    }
    await _loadFromSessionKoffer();
  }

  /// Gast: Liest ausschließlich aus PartySessionService – kein Firestore.
  /// Daten wurden beim Check-In bzw. in main() geladen.
  Future<void> _loadFromSessionKoffer() async {
    await PartySessionService.instance.loadFromPrefs();
    final svc = PartySessionService.instance;
    if (!mounted) return;
    setState(() {
      _socialMediaLinks = Map.from(svc.socialMediaLinks);
      _linkOrder = List.from(svc.linkOrder);
      _lastLoadedPartyId = svc.partyId;
      _guestDataReady = true;
      _isLoading = false;
    });
  }

  /// DJ: Lädt eigene Links aus Firestore (nur wenn eingeloggt und bearbeitbar).
  Future<void> _loadFromFirestoreForDj(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('social_media_links')
          .doc(uid)
          .get();
      if (!mounted) return;
      setState(() {
        _socialMediaLinks = <String, String>{};
        _linkOrder = [];
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          for (final e in data.entries) {
            if (e.key != 'updated_at' &&
                e.key != 'order' &&
                e.value is String &&
                (e.value as String).trim().isNotEmpty) {
              _socialMediaLinks[e.key] = e.value as String;
            }
          }
          if (data['order'] is List) {
            _linkOrder = (data['order'] as List)
                .map((e) => e.toString())
                .toList();
            _linkOrder = _linkOrder
                .where(_socialMediaLinks.containsKey)
                .toList();
            for (final k in _socialMediaLinks.keys) {
              if (!_linkOrder.contains(k)) _linkOrder.add(k);
            }
          } else {
            _linkOrder = _socialMediaLinks.keys.toList();
          }
        }
        for (final e in _socialMediaLinks.entries) {
          _urlControllers[e.key] = TextEditingController(text: e.value);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSocialMediaLinks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Sammle alle Links aus den Controllern und normalisiere sie
      final linksToSave = <String, String>{};
      for (var entry in _urlControllers.entries) {
        final url = entry.value.text.trim();
        if (url.isNotEmpty) {
          // ✅ Normalisiere URL: https:// hinzufügen, http:// zu https:// konvertieren
          final normalizedUrl = _normalizeUrl(url, entry.key);
          linksToSave[entry.key] = normalizedUrl;
        }
      }

      // Erstelle das Dokument mit nur den nicht-leeren Links
      final documentData = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
        'order': _linkOrder.where((id) => linksToSave.containsKey(id)).toList(),
      };
      // Füge nur nicht-leere Links hinzu
      for (var entry in linksToSave.entries) {
        if (entry.value.trim().isNotEmpty) {
          documentData[entry.key] = entry.value.trim();
        }
      }

      // Entferne leere Felder aus der Datenbank
      final currentDoc = await FirebaseFirestore.instance
          .collection('social_media_links')
          .doc(user.uid)
          .get();

      if (currentDoc.exists) {
        final currentData = currentDoc.data() as Map<String, dynamic>?;
        if (currentData != null) {
          // Entferne alle Plattformen, die nicht mehr in linksToSave sind
          for (var key in currentData.keys) {
            if (key != 'updated_at' &&
                key != 'order' &&
                !linksToSave.containsKey(key)) {
              documentData[key] = FieldValue.delete();
            }
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('social_media_links')
          .doc(user.uid)
          .set(
            SecurityHelper.sanitizeMap(documentData),
            SetOptions(merge: true),
          );

      setState(() {
        _socialMediaLinks = linksToSave;
        // Aktualisiere Reihenfolge: entferne IDs, die nicht mehr vorhanden sind
        _linkOrder = _linkOrder
            .where((id) => linksToSave.containsKey(id))
            .toList();
        _isEditing = false;
      });

      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.social_media_saved,
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.error_saving_social_media} $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _cancelEditing() {
    _loadSocialMediaLinks(); // Lade Daten neu, um Änderungen zu verwerfen
    setState(() {
      _isEditing = false;
    });
  }

  void _addPlatform(String platformId) {
    if (!_urlControllers.containsKey(platformId)) {
      setState(() {
        _urlControllers[platformId] = TextEditingController();
      });
    }
  }

  void _removePlatform(String platformId) {
    setState(() {
      _urlControllers[platformId]?.dispose();
      _urlControllers.remove(platformId);
    });
  }

  String _getPlatformName(String key, AppLocalizations localizations) {
    switch (key.toLowerCase()) {
      case 'facebook':
        return localizations.facebook;
      case 'instagram':
        return localizations.instagram;
      case 'tiktok':
        return localizations.tiktok;
      case 'spotify':
        return localizations.spotify;
      case 'soundcloud':
        return localizations.soundcloud;
      case 'youtube':
        return localizations.youtube;
      case 'whatsapp':
        return localizations.whatsapp;
      case 'website':
        return localizations.website;
      default:
        return key;
    }
  }

  // ✅ URL-Normalisierung: Stellt sicher, dass alle URLs mit https:// beginnen
  String _normalizeUrl(String input, String platformId) {
    final trimmed = input.trim();

    // ✅ WhatsApp-Spezialfall: Wenn reine Telefonnummer, formatiere zu wa.me Link
    if (platformId == 'whatsapp') {
      // Prüfe, ob es bereits ein wa.me Link ist
      if (trimmed.startsWith('https://wa.me/') ||
          trimmed.startsWith('http://wa.me/')) {
        return trimmed.replaceFirst('http://', 'https://');
      }

      // Prüfe, ob es eine reine Telefonnummer ist (nur Ziffern, +, Leerzeichen, Bindestriche, Klammern)
      final phoneRegex = RegExp(r'^[\d\s\+\-\(\)]+$');
      if (phoneRegex.hasMatch(trimmed)) {
        // Extrahiere nur die Ziffern
        final numbersOnly = trimmed.replaceAll(RegExp(r'[^\d]'), '');
        if (numbersOnly.length >= 8) {
          return 'https://wa.me/$numbersOnly';
        }
      }
    }

    // ✅ Normale URL-Behandlung
    // Wenn bereits https://, behalte es
    if (trimmed.startsWith('https://')) {
      return trimmed;
    }

    // Wenn http://, ersetze durch https://
    if (trimmed.startsWith('http://')) {
      return trimmed.replaceFirst('http://', 'https://');
    }

    // Wenn kein Protokoll vorhanden, füge https:// hinzu
    // Keine automatischen Änderungen (kein www., etc.) - respektiere exakt die Eingabe des DJs
    return 'https://$trimmed';
  }

  Future<void> _openLink(String url, String iconName) async {
    setState(() {
      _pressedIcon = iconName;
    });

    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.error_opening_link,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.error_opening} $e',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    // Nach kurzer Zeit das visuelle Feedback entfernen
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _pressedIcon = null;
        });
      }
    });
  }

  Widget _buildReorderableGrid(AppLocalizations localizations) {
    // Sammle alle Links, die angezeigt werden sollen
    // Verwendet _linkOrder, wenn vorhanden, sonst alle Keys aus _socialMediaLinks
    final linksToShow = _linkOrder.isNotEmpty
        ? _linkOrder
              .where(
                (id) =>
                    _socialMediaLinks.containsKey(id) &&
                    _socialMediaLinks[id]!.trim().isNotEmpty,
              )
              .toList()
        : _socialMediaLinks.keys
              .where((id) => _socialMediaLinks[id]!.trim().isNotEmpty)
              .toList();

    // Füge Links hinzu, die in _socialMediaLinks sind, aber nicht in _linkOrder
    for (var key in _socialMediaLinks.keys) {
      if (_socialMediaLinks[key]!.trim().isNotEmpty &&
          !linksToShow.contains(key)) {
        linksToShow.add(key);
      }
    }

    // Erstelle ein Grid-Layout mit 2 Spalten basierend auf der tatsächlichen
    // verfügbaren Breite im aktuellen Container (nicht Screen-Breite).
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children: linksToShow.asMap().entries.map((entry) {
            final index = entry.key;
            final id = entry.value;
            // Finde die Plattform, die dieser ID entspricht
            final platform = _availablePlatforms.firstWhere(
              (p) => p.id.toLowerCase() == id.toLowerCase(),
              orElse: () {
                return _availablePlatforms.isNotEmpty
                    ? _availablePlatforms.first
                    : SocialMediaPlatform(
                        id: id,
                        icon: Icons.link,
                        color: Colors.blue,
                        displayNameKey: id,
                      );
              },
            );
            return SizedBox(
              width: itemWidth,
              child: _buildDraggableSocialIcon(
                key: ValueKey(id),
                icon: platform.icon,
                url: _socialMediaLinks[id]!,
                name: id,
                color: platform.color,
                displayName: _getPlatformName(
                  platform.displayNameKey,
                  localizations,
                ),
                index: index,
                itemWidth: itemWidth,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _linkOrder.removeAt(oldIndex);
                    _linkOrder.insert(newIndex, item);
                    // Speichere die neue Reihenfolge
                    _saveOrder();
                  });
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDraggableSocialIcon({
    required Key key,
    required IconData icon,
    required String url,
    required String name,
    required Color color,
    required String displayName,
    required int index,
    required double itemWidth,
    required Function(int, int) onReorder,
  }) {
    final isPressed = _pressedIcon == name;
    final backgroundColor = _isDarkMode
        ? (isPressed ? color.withValues(alpha: 0.3) : Colors.white)
        : (isPressed ? color.withValues(alpha: 0.3) : Colors.transparent);
    final borderColor = _isDarkMode
        ? (isPressed ? color : Colors.grey.shade400)
        : (isPressed ? color : Colors.grey.shade300);
    final textColor = _isDarkMode ? Colors.grey[800] : Colors.grey[700];

    return LongPressDraggable<int>(
      key: key,
      data: index,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: itemWidth,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.drag_handle, color: Colors.grey[400], size: 20),
              const SizedBox(height: 4),
              FaIcon(icon, size: 48, color: color),
              const SizedBox(height: 4),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.drag_handle, color: Colors.grey[400], size: 20),
              const SizedBox(height: 4),
              FaIcon(icon, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 4),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
      onDragEnd: (details) {
        // Wird durch DragTarget behandelt
      },
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != index,
        onAcceptWithDetails: (details) {
          onReorder(details.data, index);
        },
        builder: (context, candidateData, rejectedData) {
          return GestureDetector(
            onTap: () => _openLink(url, name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: candidateData.isNotEmpty
                    ? color.withValues(alpha: 0.2)
                    : backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: candidateData.isNotEmpty ? color : borderColor,
                  width: candidateData.isNotEmpty ? 2 : (isPressed ? 2 : 1),
                ),
                boxShadow: isPressed || candidateData.isNotEmpty
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Drag Handle oben
                  Icon(Icons.drag_handle, color: Colors.grey[400], size: 20),
                  const SizedBox(height: 4),
                  FaIcon(icon, size: 48, color: color),
                  const SizedBox(height: 4),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('social_media_links')
          .doc(user.uid)
          .update(
            SecurityHelper.sanitizeMap({
              'order': _linkOrder,
              'updated_at': FieldValue.serverTimestamp(),
            }),
          );
    } catch (e) {
      debugLog('Fehler beim Speichern der Reihenfolge: $e');
    }
  }

  /// Branding: DJ-Name immer oben; darunter Logo nur bei Pro + gültiger http(s)-URL.
  /// Einleitungstext "Vernetze Dich mit [DJ-Name]" direkt darunter.
  Widget _buildSocialBranding(
    BuildContext context,
    AppLocalizations l,
    bool isRtl,
    bool isPro,
    String? djLogoUrl,
    String? djName,
  ) {
    final name = (djName ?? '').trim().isNotEmpty ? djName! : 'DJ';
    final trimmedLogo = djLogoUrl?.trim() ?? '';
    final showLogo =
        isPro && isHttpImageUrl(trimmedLogo);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDjNameFallback(context, name, isRtl),
        if (showLogo) ...[
          const SizedBox(height: 12),
          _DjLogoImage(url: trimmedLogo),
        ],
        const SizedBox(height: 16),
        Text(
          l.socialConnectWith(name),
          textAlign: isRtl ? TextAlign.right : TextAlign.center,
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
        ),
      ],
    );
  }

  Widget _buildDjNameFallback(BuildContext context, String name, bool isRtl) {
    return Text(
      name,
      textAlign: TextAlign.center,
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: UIConstants.appOrange,
      ),
    );
  }

  /// Gemeinsamer Header für Social-Media-Seite (Gast + DJ).
  Widget _buildSocialHeader(
    BuildContext context,
    AppLocalizations l,
    bool isRtl,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: UIConstants.appBarBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        children: [
          const Icon(Icons.share, size: 32, color: UIConstants.appBarIconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.social_media_title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: UIConstants.appBarForegroundColor,
              ),
              textAlign: isRtl ? TextAlign.right : TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  /// Aktive Party anhand der persistierten `party_id` (wie Gast-Check-in / Session-Koffer).
  /// `manual` = Platzhalter ohne echte Party — gilt wie „keine Party“ für VibesBox-Defaults.
  bool _hasActivePartyId(PartySessionService svc) {
    final p = svc.partyId?.trim() ?? '';
    return p.isNotEmpty && p != 'manual';
  }

  /// Öffentliche VibesBox-Kanäle (@vibesbox.app, Facebook, Web): nur ohne Party-Kontext.
  bool _showVibesboxDefaultSocial(PartySessionService svc) =>
      !_hasActivePartyId(svc);

  /// True, wenn die geladene Gast-Session mindestens einen aufrufbaren DJ-Link enthält.
  bool _guestHasDjSocialLinks() {
    final urls = _socialMediaLinks;
    if (urls.isEmpty) return false;
    final ordered = _linkOrder.isNotEmpty
        ? _linkOrder.where((id) {
            final u = urls[id];
            return u != null && u.trim().isNotEmpty;
          }).toList()
        : urls.entries
            .where((e) => e.value.trim().isNotEmpty)
            .map((e) => e.key)
            .toList();
    return ordered.isNotEmpty;
  }

  /// In aktiver Party: DJ (Free oder Pro ohne Links) hat keine Social-Links für Gäste.
  Widget _buildGuestPartyNoDjSocialMessage(AppLocalizations l, bool isRtl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        l.social_no_links,
        textAlign: TextAlign.center,
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: UIConstants.appBarForegroundColor,
            ),
      ),
    );
  }

  /// VibesBox-Kanäle – nur wenn `party_id` leer/fehlt (kein Party-Kontext).
  Widget _buildGuestVibesboxSection(AppLocalizations l, bool isRtl) {
    final intro = l.vibesbox_follow_updates_intro;
    final channels = <(String id, String url, String label)>[
      (
        'instagram',
        kVibesboxInstagramUrl,
        l.vibesbox_social_instagram_label,
      ),
      (
        'facebook',
        kVibesboxFacebookUrl,
        l.vibesbox_social_facebook_label,
      ),
      (
        'website',
        kVibesboxWebsiteUrl,
        l.vibesbox_social_website_label,
      ),
    ];

    return PwaWidgetCell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            intro,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
            textAlign: isRtl ? TextAlign.right : TextAlign.center,
            textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisCount = 2;
              final itemWidth =
                  (constraints.maxWidth - 16) / crossAxisCount - 8;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: channels.map((ch) {
                  final info = SocialPlatformIcons.get(ch.$1);
                  final icon = info?.icon ?? Icons.link;
                  final color = info?.color ?? UIConstants.appOrange;
                  return SizedBox(
                    width: itemWidth,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openLink(ch.$2, ch.$1),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: UIConstants.appBarBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: UIConstants.appOrange,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FaIcon(icon, size: 40, color: color),
                              const SizedBox(height: 8),
                              Text(
                                ch.$3,
                                textAlign: TextAlign.center,
                                textDirection: isRtl
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          UIConstants.appBarForegroundColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Szenario C: Pro-DJ mit Links – 2-Spalten-Grid, orangefarbener Rahmen, Plattformname unter Icon.
  /// TikTok-Icon: weiß (SocialPlatformIcons) für schwarzen Hintergrund.
  Widget _buildScenarioC(AppLocalizations l, bool isRtl) {
    final linksToShow = _linkOrder.isNotEmpty
        ? _linkOrder
              .where(
                (id) =>
                    _socialMediaLinks.containsKey(id) &&
                    _socialMediaLinks[id]!.trim().isNotEmpty,
              )
              .toList()
        : _socialMediaLinks.keys
              .where((id) => _socialMediaLinks[id]!.trim().isNotEmpty)
              .toList();
    final crossAxisCount = 2;
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 16) / crossAxisCount - 8;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: linksToShow.map((id) {
            final info = SocialPlatformIcons.get(id);
            final icon = info?.icon ?? Icons.link;
            final color = info?.color ?? UIConstants.appOrange;
            final displayName = _getPlatformName(id, l);
            final url = _socialMediaLinks[id] ?? '';
            return SizedBox(
              width: itemWidth,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openLink(url, id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: UIConstants.appBarBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: UIConstants.appOrange,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(icon, size: 40, color: color),
                        const SizedBox(height: 8),
                        Text(
                          displayName,
                          textAlign: TextAlign.center,
                          textDirection: isRtl
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: UIConstants.appBarForegroundColor,
                                fontWeight: FontWeight.w500,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildEditView() {
    final localizations = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = AppConfig.isAdminRole(UserService().currentUser.value);
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');

    // Nur Admin/DJ können bearbeiten
    if (!isAdmin && user == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: Column(
            crossAxisAlignment: isRtl
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                localizations.edit_social_media,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: isRtl ? TextAlign.right : null,
              ),
              const SizedBox(height: 16),
              // Zeige alle Plattformen, die bereits Links haben oder im Bearbeitungsmodus sind
              ..._availablePlatforms
                  .where((platform) {
                    // Im Bearbeitungsmodus: zeige alle Plattformen, die einen Controller haben
                    if (_isEditing) {
                      return _urlControllers.containsKey(platform.id);
                    }
                    // Im Anzeigemodus: zeige nur Plattformen mit Links
                    return _socialMediaLinks.containsKey(platform.id) &&
                        _socialMediaLinks[platform.id]!.isNotEmpty;
                  })
                  .map((platform) {
                    final controller =
                        _urlControllers[platform.id] ?? TextEditingController();
                    final hasLink = controller.text.isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          FaIcon(
                            platform.icon,
                            color: platform.color,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: controller,
                              maxLength: 300,
                              decoration: InputDecoration(
                                labelText: _getPlatformName(
                                  platform.displayNameKey,
                                  localizations,
                                ),
                                hintText:
                                    localizations.enter_url,
                                border: const OutlineInputBorder(),
                                suffixIcon: _isEditing && hasLink
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            _removePlatform(platform.id),
                                        tooltip:
                                            localizations.remove_link,
                                      )
                                    : null,
                              ),
                              enabled: _isEditing,
                              textAlign: isRtl
                                  ? TextAlign.right
                                  : TextAlign.left,
                              keyboardType: TextInputType.url,
                              validator: (value) {
                                // ✅ Flexiblere Validierung: Erlaubt auch URLs ohne Protokoll
                                // Die Normalisierung fügt automatisch https:// hinzu
                                if (_isEditing &&
                                    value != null &&
                                    value.trim().isNotEmpty) {
                                  final trimmed = value.trim();
                                  // WhatsApp-Spezialfall: Erlaube auch Telefonnummern
                                  if (platform.id == 'whatsapp') {
                                    // WhatsApp: Erlaube URLs, wa.me Links oder Telefonnummern
                                    final isUrl =
                                        trimmed.startsWith('http://') ||
                                        trimmed.startsWith('https://') ||
                                        trimmed.startsWith('wa.me/');
                                    final isPhoneNumber = RegExp(
                                      r'^[\d\s\+\-\(\)]+$',
                                    ).hasMatch(trimmed);
                                    if (!isUrl && !isPhoneNumber) {
                                      return localizations.invalid_url;
                                    }
                                  }
                                  // Andere Plattformen: Erlaube URLs mit oder ohne Protokoll
                                  // Die Normalisierung wird https:// hinzufügen
                                  // Keine strenge Validierung mehr - alles wird akzeptiert und normalisiert
                                }
                                return null;
                              },
                              onChanged: (value) {
                                final sanitized = SecurityHelper.sanitize(
                                  value,
                                  maxLength: 300,
                                );
                                if (sanitized != value) {
                                  controller.value = controller.value.copyWith(
                                    text: sanitized,
                                    selection: TextSelection.collapsed(
                                      offset: sanitized.length,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                // Dropdown zum Hinzufügen neuer Plattformen
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText:
                        localizations.add_social_media_link,
                    border: const OutlineInputBorder(),
                  ),
                  items: _availablePlatforms
                      .where(
                        (platform) =>
                            !_urlControllers.containsKey(platform.id) ||
                            _urlControllers[platform.id]?.text.isEmpty == true,
                      )
                      .map((platform) {
                        return DropdownMenuItem<String>(
                          value: platform.id,
                          child: Row(
                            children: [
                              FaIcon(
                                platform.icon,
                                color: platform.color,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getPlatformName(
                                  platform.displayNameKey,
                                  localizations,
                                ),
                                textDirection:
                                    (isRtl ||
                                        arabicRegex.hasMatch(
                                          _getPlatformName(
                                            platform.displayNameKey,
                                            localizations,
                                          ),
                                        ))
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                              ),
                            ],
                          ),
                        );
                      })
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _addPlatform(value);
                    }
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: isRtl
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _cancelEditing,
                      child: Text(localizations.cancel),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveSocialMediaLinks,
                      child: Text(localizations.save),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = PartySessionService.instance;
    final localizations = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final isAdmin = AppConfig.isAdminRole(UserService().currentUser.value);
    final canEdit = isAdmin || user != null;
    final isFree = UserService().currentUser.value?.isFree ?? true;
    final isRtl = [
      'ar',
      'he',
      'fa',
      'ur',
    ].contains(Localizations.localeOf(context).languageCode);

    if (_isLoading) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    // Gast in Party ODER unangemeldet: DJ-Links / VibesBox (einheitlich für beide).
    final bool hasSession = svc.hasSession;
    final bool showGuestView = hasSession || user == null;
    if (showGuestView) {
      if (svc.partyId != _lastLoadedPartyId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadFromSessionKoffer();
        });
      }
      if (!_guestDataReady) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        );
      }
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSocialHeader(context, localizations, isRtl),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Builder(
                    builder: (context) {
                      final inParty = _hasActivePartyId(svc);
                      final isPro = inParty ? svc.isPro : false;
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasSession)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: _buildSocialBranding(
                                  context,
                                  localizations,
                                  isRtl,
                                  isPro,
                                  svc.djLogoUrl,
                                  svc.djName,
                                ),
                              ),
                            if (_showVibesboxDefaultSocial(svc))
                              _buildGuestVibesboxSection(
                                localizations,
                                isRtl,
                              )
                            else if (isPro && _guestHasDjSocialLinks())
                              _buildScenarioC(localizations, isRtl)
                            else
                              _buildGuestPartyNoDjSocialMessage(
                                localizations,
                                isRtl,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Titel (Schwarz/Weiß, gleiche Position wie History)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: UIConstants.appBarBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.share,
                    size: 32,
                    color: UIConstants.appBarIconColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      localizations.social_media_title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: UIConstants.appBarForegroundColor,
                      ),
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    ),
                  ),
                  if (canEdit && !_isEditing)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (user != null && isFree)
                          const Icon(
                            Icons.lock,
                            size: 18,
                            color: UIConstants.freeLimitBorderRed,
                          ),
                        if (user != null && isFree) const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: UIConstants.appBarIconColor,
                          ),
                          onPressed: () {
                            if (user != null && isFree) {
                              FreeFeatureLockedDialog.show(context);
                              return;
                            }
                            setState(() {
                              _isEditing = true;
                              for (var entry in _socialMediaLinks.entries) {
                                if (!_urlControllers.containsKey(entry.key)) {
                                  _urlControllers[entry.key] =
                                      TextEditingController(text: entry.value);
                                }
                              }
                            });
                          },
                          tooltip: localizations.edit,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: isRtl
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    // Bearbeiten-Ansicht (Hinweis erscheint nur einmal oben unter der Überschrift)
                    if (_isEditing) _buildEditView(),
                    if (!_isEditing) ...[
                      if (_socialMediaLinks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 32,
                          ),
                          child: Text(
                            localizations.add_social_media_link,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: UIConstants.appBarForegroundColor
                                      .withValues(alpha: 0.9),
                                ),
                            textAlign: isRtl
                                ? TextAlign.right
                                : TextAlign.center,
                            textDirection: isRtl
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                          ),
                        )
                      else
                        _buildReorderableGrid(localizations),
                      // Hinweistext für Drag & Drop
                      if (_socialMediaLinks.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            localizations.drag_to_reorder_hint,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                            textAlign: isRtl
                                ? TextAlign.right
                                : TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                    // Footer-Abstand
                    const SizedBox(height: UIConstants.kFooterPadding * 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DJ-Logo mit dynamischen Maßen je nach Seitenverhältnis.
/// Szenario 1 (Breitbild): w > h → 85% Breite, zentriert.
/// Szenario 2 (Hochformat): h > w → max 240 px Höhe, zentriert.
/// Szenario 3 (Quadrat): w == h → 120×120 px.
class _DjLogoImage extends StatefulWidget {
  final String url;

  const _DjLogoImage({required this.url});

  @override
  State<_DjLogoImage> createState() => _DjLogoImageState();
}

class _DjLogoImageState extends State<_DjLogoImage> {
  int? _imageWidth;
  int? _imageHeight;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (isHttpImageUrl(widget.url)) {
      _resolveImageDimensions();
    } else {
      _hasError = true;
    }
  }

  @override
  void didUpdateWidget(covariant _DjLogoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _imageWidth = null;
      _imageHeight = null;
      _hasError = !isHttpImageUrl(widget.url);
      if (!_hasError) {
        _resolveImageDimensions();
      }
    }
  }

  void _resolveImageDimensions() {
    if (!isHttpImageUrl(widget.url)) return;
    final imageProvider = NetworkImage(widget.url);
    final stream = imageProvider.resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener(
        (ImageInfo info, bool _) {
          if (!mounted) return;
          setState(() {
            _imageWidth = info.image.width;
            _imageHeight = info.image.height;
          });
        },
        onError: (_, __) {
          if (mounted) setState(() => _hasError = true);
        },
      ),
    );
  }

  void _markFailed() {
    if (_hasError) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _hasError = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isHttpImageUrl(widget.url) || _hasError) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        final double maxH = constraints.maxHeight;

        // Noch keine Dimensionen → Platzhalter beim Laden
        if (_imageWidth == null || _imageHeight == null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 120,
              height: 120,
              child: Image.network(
                widget.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  _markFailed();
                  return const SizedBox.shrink();
                },
                loadingBuilder: (_, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
          );
        }

        final w = _imageWidth!;
        final h = _imageHeight!;

        // Szenario 1: Breitbild (w > h) → 85% Breite, zentriert
        // Szenario 2: Hochformat (h > w) → max 240 px Höhe, zentriert
        // Szenario 3: Quadrat (w == h) → 120×120 px
        final bool isWide = w > h;
        final bool isTall = h > w;
        final bool isSquare = w == h;

        double targetWidth;
        double targetHeight;

        if (isSquare) {
          targetWidth = 120.0;
          targetHeight = 120.0;
        } else if (isWide) {
          // Szenario 1: Breitbild – mind. 85 % Breite, zentriert
          targetWidth = (maxW * 0.85).clamp(120.0, double.infinity);
          targetHeight = (targetWidth * (h / w)).clamp(40.0, maxH);
        } else {
          // Szenario 2: Hochformat – max 240 px Höhe, zentriert
          targetHeight = 240.0.clamp(80.0, maxH);
          targetWidth = targetHeight * (w / h);
        }

        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: targetWidth,
              height: targetHeight,
              child: Image.network(
                widget.url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) {
                  _markFailed();
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
