import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/user_service.dart';
import '../../../utils/network_image_url.dart';
import '../../../utils/role_helper.dart';
import '../../../utils/ui_constants.dart';
import '../../../services/vibesbox_social_service.dart';
import '../../../widgets/free_feature_locked.dart';
import '../../../utils/debug_log.dart';

/// Sektion für Profilbild und/oder DJ-Logo: Pickern, Komprimieren, Hochladen, Löschen.
/// URLs und Loading-State werden per Callback an die Elternseite gemeldet.
/// Mit [showAvatar] und [showBranding] kann nur der Avatar oder nur das Branding angezeigt werden (z. B. für getrennte Positionen auf der Seite).
class ProfileImageSection extends StatefulWidget {
  const ProfileImageSection({
    super.key,
    required this.uid,
    this.profileImageUrl,
    this.djLogoUrl,
    required this.onProfileImageUpdated,
    required this.onDjLogoUpdated,
    this.showAvatar = true,
    this.showBranding = true,
    /// Optional: Für Initialen im Avatar (z. B. Firestore-[displayName]), wenn Auth-[displayName] leer ist.
    this.avatarInitialName,
  });

  final String uid;
  final String? profileImageUrl;
  final String? djLogoUrl;
  final ValueChanged<String?> onProfileImageUpdated;
  final ValueChanged<String?> onDjLogoUpdated;
  final String? avatarInitialName;
  /// Wenn true, wird das Profilbild (Avatar) mit Upload/Löschen angezeigt.
  final bool showAvatar;
  /// Wenn true, wird die DJ-Branding-Karte (Logo-Vorschau, Upload, Löschen) angezeigt (nur bei Rolle DJ/Admin/Location).
  final bool showBranding;

  @override
  State<ProfileImageSection> createState() => _ProfileImageSectionState();
}

class _ProfileImageSectionState extends State<ProfileImageSection> {
  bool _isLoadingImage = false;
  bool _isLoadingDjLogo = false;
  bool _avatarImageLoadFailed = false;

  @override
  void didUpdateWidget(covariant ProfileImageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileImageUrl != widget.profileImageUrl) {
      _avatarImageLoadFailed = false;
    }
  }

  Future<Uint8List?> _compressImage(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      const maxSize = 500;
      img.Image resizedImage = image;
      if (image.width > maxSize || image.height > maxSize) {
        final ratio = image.width / image.height;
        int newWidth, newHeight;
        if (image.width > image.height) {
          newWidth = maxSize;
          newHeight = (maxSize / ratio).round();
        } else {
          newHeight = maxSize;
          newWidth = (maxSize * ratio).round();
        }
        resizedImage = img.copyResize(image, width: newWidth, height: newHeight);
      }
      final compressedBytes = img.encodeJpg(resizedImage, quality: 80);
      if (compressedBytes.length > 2 * 1024 * 1024) {
        int quality = 70;
        while (compressedBytes.length > 2 * 1024 * 1024 && quality > 30) {
          final testBytes = img.encodeJpg(resizedImage, quality: quality);
          if (testBytes.length <= 2 * 1024 * 1024) return Uint8List.fromList(testBytes);
          quality -= 10;
        }
      }
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      debugLog('Fehler beim Komprimieren: $e');
      return null;
    }
  }

  Future<({Uint8List bytes, String format})?> _compressDjLogo(File imageFile, String fileName) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      const maxWidth = 1200;
      const maxHeight = 500;
      img.Image resizedImage = image;
      if (image.width > maxWidth || image.height > maxHeight) {
        final widthRatio = maxWidth / image.width;
        final heightRatio = maxHeight / image.height;
        final ratio = widthRatio < heightRatio ? widthRatio : heightRatio;
        final newWidth = (image.width * ratio).round();
        final newHeight = (image.height * ratio).round();
        resizedImage = img.copyResize(image, width: newWidth, height: newHeight);
      }
      final isPng = fileName.toLowerCase().endsWith('.png');
      if (isPng) {
        final compressedBytes = Uint8List.fromList(img.encodePng(resizedImage, level: 0));
        return (bytes: compressedBytes, format: 'png');
      }
      final compressedBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 100));
      return (bytes: compressedBytes, format: 'jpg');
    } catch (e) {
      debugLog('Fehler beim Komprimieren des DJ-Logos: $e');
      return null;
    }
  }

  Future<void> _updateActivePartyLogo(String? logoUrl) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final partiesQuery = await FirebaseFirestore.instance
          .collection('parties')
          .where('created_by', isEqualTo: user.uid)
          .where('lifecycle_status', isEqualTo: 'active')
          .orderBy('created_at', descending: true)
          .limit(1)
          .get();
      if (partiesQuery.docs.isNotEmpty) {
        final activePartyDoc = partiesQuery.docs.first;
        final updateData = <String, dynamic>{};
        if (logoUrl != null && logoUrl.isNotEmpty) {
          updateData['dj_logo'] = logoUrl;
        } else {
          updateData['dj_logo'] = FieldValue.delete();
        }
        await activePartyDoc.reference.update(updateData);
      }
    } catch (e) {
      debugLog('⚠️ Fehler beim Aktualisieren der aktiven Party: $e');
    }
  }

  Future<void> _pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 100,
      );
      if (image == null) return;
      if (!mounted) return;
      setState(() => _isLoadingImage = true);

      final compressedBytes = await _compressImage(File(image.path));
      if (!mounted) return;
      if (compressedBytes == null) {
        _showSnack(context, AppLocalizations.of(context)!.error_processing_image, isError: true);
        setState(() => _isLoadingImage = false);
        return;
      }
      if (compressedBytes.length > 2 * 1024 * 1024) {
        _showSnack(context, AppLocalizations.of(context)!.image_too_large, isError: true);
        setState(() => _isLoadingImage = false);
        return;
      }

      final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('${user.uid}.jpg');
      await storageRef.putData(compressedBytes, SettableMetadata(contentType: 'image/jpeg', cacheControl: 'public, max-age=31536000'));
      final downloadUrl = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'photoURL': downloadUrl}, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _isLoadingImage = false);
      widget.onProfileImageUpdated(downloadUrl);
      _showSnack(context, AppLocalizations.of(context)!.profile_picture_uploaded);
    } catch (e) {
      debugLog('Fehler beim Hochladen: $e');
      if (mounted) {
        setState(() => _isLoadingImage = false);
        _showSnack(context, '${AppLocalizations.of(context)!.error_uploading} $e', isError: true);
      }
    }
  }

  Future<void> _deleteProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.delete_profile_picture),
        content: Text(localizations.confirm_delete_profile_picture),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(localizations.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(localizations.delete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    try {
      setState(() => _isLoadingImage = true);
      try {
        await FirebaseStorage.instance.ref().child('profile_images').child('${user.uid}.jpg').delete();
      } catch (_) {}
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoURL': FieldValue.delete()});
      if (!mounted) return;
      setState(() => _isLoadingImage = false);
      widget.onProfileImageUpdated(null);
      _showSnack(context, localizations.profile_picture_deleted);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingImage = false);
        _showSnack(context, '${localizations.error_deleting_picture} $e', isError: true);
      }
    }
  }

  Future<void> _pickAndUploadDjLogo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final localizations = AppLocalizations.of(context)!;
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 500,
        imageQuality: 100,
      );
      if (!mounted) return;
      if (image == null) return;
      final fileName = image.name.toLowerCase();
      if (!fileName.endsWith('.jpg') && !fileName.endsWith('.jpeg') && !fileName.endsWith('.png')) {
        _showSnack(context, localizations.wrong_file_format_message, isError: true);
        return;
      }
      final file = File(image.path);
      final fileSize = await file.length();
      if (fileSize > 2 * 1024 * 1024) {
        _showSnack(context, localizations.file_too_large_message, isError: true);
        return;
      }
      setState(() => _isLoadingDjLogo = true);
      final compressionResult = await _compressDjLogo(file, fileName);
      if (!mounted) return;
      if (compressionResult == null) {
        _showSnack(context, localizations.error_processing_logo, isError: true);
        setState(() => _isLoadingDjLogo = false);
        return;
      }
      final format = compressionResult.format;
      final fileExtension = format == 'png' ? 'png' : 'jpg';
      final contentType = format == 'png' ? 'image/png' : 'image/jpeg';
      final storageRef = FirebaseStorage.instance.ref().child('dj_logos').child('${user.uid}.$fileExtension');
      await storageRef.putData(compressionResult.bytes, SettableMetadata(contentType: contentType, cacheControl: 'public, max-age=31536000'));
      final downloadUrl = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'dj_logo_url': downloadUrl, 'djLogoUrl': downloadUrl}, SetOptions(merge: true));
      await UserService().preloadDjLogo(downloadUrl);
      await _updateActivePartyLogo(downloadUrl);
      if (!mounted) return;
      setState(() => _isLoadingDjLogo = false);
      widget.onDjLogoUpdated(downloadUrl);
      _showSnack(context, localizations.logo_uploaded);
    } catch (e) {
      debugLog('Fehler beim Hochladen des DJ-Logos: $e');
      if (mounted) {
        setState(() => _isLoadingDjLogo = false);
        _showSnack(context, '${AppLocalizations.of(context)!.error_uploading_logo} $e', isError: true);
      }
    }
  }

  Future<void> _deleteDjLogo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      setState(() => _isLoadingDjLogo = true);
      try {
        try { await FirebaseStorage.instance.ref().child('dj_logos').child('${user.uid}.jpg').delete(); } catch (_) {}
        try { await FirebaseStorage.instance.ref().child('dj_logos').child('${user.uid}.png').delete(); } catch (_) {}
      } catch (_) {}
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'dj_logo_url': FieldValue.delete(),
        'djLogoUrl': FieldValue.delete(),
      });
      UserService().clearCache();
      await _updateActivePartyLogo(null);
      if (!mounted) return;
      setState(() => _isLoadingDjLogo = false);
      widget.onDjLogoUpdated(null);
      _showSnack(context, AppLocalizations.of(context)!.logo_deleted);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDjLogo = false);
        _showSnack(context, '${AppLocalizations.of(context)!.error_deleting_logo} $e', isError: true);
      }
    }
  }

  Future<void> _showDeleteLogoConfirmDialog() async {
    if (!mounted) return;
    final localizations = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.grey.shade900, Colors.black]),
            border: Border.all(color: UIConstants.appOrange, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Logo wirklich löschen?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(localizations.cancel)),
                    const SizedBox(width: 8),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: UIConstants.appOrange), child: Text(localizations.yes)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && confirmed == true) await _deleteDjLogo();
  }

  void _showSnack(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  /// Ersatz im CircleAvatar wenn kein gültiges Profilbild geladen werden kann.
  Widget _buildProfileAvatarFallback({required double radius}) {
    final u = FirebaseAuth.instance.currentUser;
    String raw = '';
    final initial = widget.avatarInitialName?.trim();
    if (initial != null && initial.isNotEmpty) {
      raw = initial;
    } else {
      raw = (u?.displayName != null && u!.displayName!.trim().isNotEmpty)
          ? u.displayName!.trim()
          : (u?.email != null ? u!.email!.trim() : '');
    }
    if (raw.isEmpty) {
      return Icon(
        Icons.music_note,
        size: radius * 0.65,
        color: UIConstants.appOrange,
      );
    }
    return Text(
      raw.substring(0, 1).toUpperCase(),
      style: TextStyle(
        fontSize: radius * 0.85,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade800,
      ),
    );
  }

  Widget _buildLogoPreview(BuildContext context) {
    final isFree = UserService().sessionProStatus.value?.isActive != true;
    final url = widget.djLogoUrl?.trim() ?? '';
    if (!isHttpImageUrl(url)) return const SizedBox.shrink();
    final safeUrl = url;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        safeUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      ),
    );
    if (isFree) {
      return Opacity(
        opacity: 0.5,
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
          child: image,
        ),
      );
    }
    return image;
  }

  Future<void> _openVibesboxProfileLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _vibesboxProfileLink(BuildContext context, String label, String url) {
    return InkWell(
      onTap: () => _openVibesboxProfileLink(url),
      child: Text(
        label,
        style: const TextStyle(
          color: UIConstants.appOrange,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          fontSize: 13,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final isPro = UserService().sessionProStatus.value?.isActive == true;
    const avatarRadius = 60.0;
    final rawProfileUrl = widget.profileImageUrl?.trim() ?? '';
    final useProfileNetwork =
        isHttpImageUrl(rawProfileUrl) && !_avatarImageLoadFailed;
    // onBackgroundImageError nur mit gesetztem backgroundImage (Flutter-Assert).
    final Widget profileCircleAvatar = useProfileNetwork
        ? CircleAvatar(
            radius: avatarRadius,
            backgroundColor: Colors.grey[300],
            backgroundImage: NetworkImage(rawProfileUrl),
            onBackgroundImageError: (_, __) {
              if (!mounted) return;
              setState(() => _avatarImageLoadFailed = true);
            },
          )
        : CircleAvatar(
            radius: avatarRadius,
            backgroundColor: Colors.grey[300],
            child: _buildProfileAvatarFallback(radius: avatarRadius),
          );

    final children = <Widget>[];
    if (widget.showAvatar) {
      children.add(
        Center(
          child: Stack(
            children: [
              profileCircleAvatar,
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: _isLoadingImage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : PopupMenuButton<String>(
                          icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (value) {
                            if (value == 'upload') _pickAndUploadImage();
                            else if (value == 'delete') _deleteProfileImage();
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'upload',
                              child: Row(
                                children: [
                                  const Icon(Icons.camera_alt, size: 20),
                                  const SizedBox(width: 8),
                                  Text(localizations.change_image),
                                ],
                              ),
                            ),
                            if (isHttpImageUrl(widget.profileImageUrl))
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(Icons.delete, size: 20, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Text(localizations.delete_image, style: const TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (widget.showBranding) {
      children.add(
        FutureBuilder<bool>(
          future: user != null ? hasAnyRole(user, const ['DJ', 'Admin', 'Location']) : Future.value(false),
          builder: (context, snapshot) {
            if (snapshot.data != true) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(top: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1F2937), Color(0xFF121417)],
                ),
                border: Border.all(color: UIConstants.appOrange, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.branding_watermark, size: 20, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text(
                          localizations.dj_branding,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (!isPro) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.lock, size: 18, color: UIConstants.freeLimitBorderRed),
                        ],
                      ],
                    ),
                    if (!isPro) ...[
                      const SizedBox(height: 8),
                      Text(
                        localizations.vibesbox_follow_updates_intro,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        children: [
                          _vibesboxProfileLink(
                            context,
                            localizations.instagram,
                            kVibesboxInstagramUrl,
                          ),
                          _vibesboxProfileLink(
                            context,
                            localizations.facebook,
                            kVibesboxFacebookUrl,
                          ),
                          _vibesboxProfileLink(
                            context,
                            localizations.vibesbox_social_website_label,
                            kVibesboxWebsiteUrl,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      localizations.logo_preview,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: UIConstants.appOrange.withValues(alpha: 0.3)),
                      ),
                      child: isHttpImageUrl(widget.djLogoUrl)
                        ? _buildLogoPreview(context)
                        : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: _isLoadingDjLogo
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                : const Icon(Icons.cloud_upload),
                            color: UIConstants.appOrange,
                            iconSize: 22,
                            onPressed: _isLoadingDjLogo
                                ? null
                                : (isPro ? _pickAndUploadDjLogo : () => FreeFeatureLockedDialog.show(context)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red.shade400,
                            iconSize: 22,
                            onPressed: _isLoadingDjLogo
                                ? null
                                : (isPro ? _showDeleteLogoConfirmDialog : () => FreeFeatureLockedDialog.show(context)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// Nur das Profilbild (Avatar) für die Kopfzeile – ganz oben auf der Profilseite.
class ProfileAvatarHeader extends StatelessWidget {
  const ProfileAvatarHeader({
    super.key,
    required this.uid,
    this.profileImageUrl,
    required this.onProfileImageUpdated,
    this.avatarInitialName,
  });

  final String uid;
  final String? profileImageUrl;
  final ValueChanged<String?> onProfileImageUpdated;
  final String? avatarInitialName;

  @override
  Widget build(BuildContext context) {
    return ProfileImageSection(
      uid: uid,
      profileImageUrl: profileImageUrl,
      djLogoUrl: null,
      onProfileImageUpdated: onProfileImageUpdated,
      onDjLogoUpdated: (_) {},
      showAvatar: true,
      showBranding: false,
      avatarInitialName: avatarInitialName,
    );
  }
}

/// DJ-Logo und Branding – wird nach den persönlichen Daten (Name, E-Mail) angezeigt.
class DjSocialBrandingSection extends StatelessWidget {
  const DjSocialBrandingSection({
    super.key,
    required this.uid,
    this.djLogoUrl,
    required this.onDjLogoUpdated,
  });

  final String uid;
  final String? djLogoUrl;
  final ValueChanged<String?> onDjLogoUpdated;

  @override
  Widget build(BuildContext context) {
    return ProfileImageSection(
      uid: uid,
      profileImageUrl: null,
      djLogoUrl: djLogoUrl,
      onProfileImageUpdated: (_) {},
      onDjLogoUpdated: onDjLogoUpdated,
      showAvatar: false,
      showBranding: true,
    );
  }
}
