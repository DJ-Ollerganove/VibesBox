import 'package:cloud_firestore/cloud_firestore.dart';

/// Eintrag aus admin_config/vibesbox_social (platforms-Array).
class VibesboxSocialEntry {
  const VibesboxSocialEntry({required this.id, required this.url});
  final String id;
  final String url;

  static VibesboxSocialEntry? fromMap(dynamic map) {
    if (map is! Map) return null;
    final id = map['id'] as String?;
    final url = map['url'] as String?;
    if (id == null || id.isEmpty || url == null || url.isEmpty) return null;
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return null;
    return VibesboxSocialEntry(id: id.trim(), url: trimmed);
  }
}

/// Öffentliche VibesBox-Kanäle (wenn kein DJ-eigenes `dj_logo`/Social-Set oder als Firestore-Fallback).
const String kVibesboxInstagramUrl = 'https://www.instagram.com/vibesbox.app/';
const String kVibesboxFacebookUrl = 'https://www.facebook.com/vibesbox.app';
const String kVibesboxWebsiteUrl = 'https://www.vibesbox.app/';

/// Fallback-Liste, wenn Firestore nicht erreichbar ist.
const List<VibesboxSocialEntry> kVibesboxSocialFallback = [
  VibesboxSocialEntry(id: 'instagram', url: kVibesboxInstagramUrl),
  VibesboxSocialEntry(id: 'facebook', url: kVibesboxFacebookUrl),
  VibesboxSocialEntry(id: 'website', url: kVibesboxWebsiteUrl),
];

/// Lädt die zentrale Social-Media-Liste aus admin_config/vibesbox_social.
/// Bei Fehler oder fehlenden Daten wird die Fallback-Liste (Facebook + Instagram) zurückgegeben.
Future<List<VibesboxSocialEntry>> getVibesboxSocialPlatforms() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('admin_config')
        .doc('vibesbox_social')
        .get();

    if (!doc.exists) return kVibesboxSocialFallback;

    final data = doc.data();
    final platforms = data?['platforms'];
    if (platforms is! List || platforms.isEmpty) return kVibesboxSocialFallback;

    final list = <VibesboxSocialEntry>[];
    for (final item in platforms) {
      final entry = VibesboxSocialEntry.fromMap(item);
      if (entry != null) list.add(entry);
    }
    return list.isEmpty ? kVibesboxSocialFallback : list;
  } catch (_) {
    return kVibesboxSocialFallback;
  }
}
