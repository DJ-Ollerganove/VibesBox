import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';

/// Eintrag aus [admin_config/vibesbox_social] oder [admin_config/global_settings].
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
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }
    return VibesboxSocialEntry(id: id.trim(), url: trimmed);
  }
}

/// Offline-/Notnagel nur wenn Firestore keine Plattformen liefert (eine zentrale Stelle).
List<VibesboxSocialEntry> _offlineProductFallback() {
  final web = AppConfig.pwaUrl.trim();
  final webUrl = web.startsWith('http') ? web : 'https://vibesbox.app';
  return [
    const VibesboxSocialEntry(
      id: 'instagram',
      url: 'https://www.instagram.com/vibesbox.app/',
    ),
    const VibesboxSocialEntry(
      id: 'facebook',
      url: 'https://www.facebook.com/vibesbox.app',
    ),
    VibesboxSocialEntry(id: 'website', url: webUrl),
  ];
}

List<VibesboxSocialEntry> _dedupeById(List<VibesboxSocialEntry> list) {
  final seen = <String>{};
  final out = <VibesboxSocialEntry>[];
  for (final e in list) {
    if (seen.add(e.id)) out.add(e);
  }
  return out;
}

List<VibesboxSocialEntry>? _parsePlatformsList(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null;
  final out = <VibesboxSocialEntry>[];
  for (final item in raw) {
    final e = VibesboxSocialEntry.fromMap(item);
    if (e != null) out.add(e);
  }
  return out.isEmpty ? null : out;
}

/// Optionale Felder in [admin_config/global_settings] (Merge mit vibesbox_social).
List<VibesboxSocialEntry>? _parseVibesboxFromGlobalSettings(
  Map<String, dynamic>? data,
) {
  if (data == null || data.isEmpty) return null;

  final fromList = _parsePlatformsList(
    data['vibesbox_social_platforms'] ?? data['platforms'],
  );
  if (fromList != null) return fromList;

  final entries = <VibesboxSocialEntry>[];
  void addUrl(String field, String id) {
    final v = data[field];
    if (v is! String) return;
    final u = v.trim();
    if (u.isEmpty) return;
    if (!u.startsWith('http://') && !u.startsWith('https://')) return;
    entries.add(VibesboxSocialEntry(id: id, url: u));
  }

  addUrl('social_instagram_url', 'instagram');
  addUrl('social_facebook_url', 'facebook');
  addUrl('social_website_url', 'website');
  addUrl('social_web_url', 'website');
  addUrl('vibesbox_instagram_url', 'instagram');
  addUrl('vibesbox_facebook_url', 'facebook');
  addUrl('vibesbox_website_url', 'website');
  addUrl('vibesbox_web_url', 'website');

  return entries.isEmpty ? null : entries;
}

/// Lädt VibesBox-Kanäle: zuerst [admin_config/vibesbox_social], sonst relevante Felder in
/// [admin_config/global_settings], sonst [AppConfig]-basierter Offline-Fallback.
Future<List<VibesboxSocialEntry>> getVibesboxSocialPlatforms() async {
  try {
    final results = await Future.wait([
      FirebaseFirestore.instance.collection('admin_config').doc('vibesbox_social').get(),
      FirebaseFirestore.instance.collection('admin_config').doc('global_settings').get(),
    ]);

    final vibesDoc = results[0];
    final globalDoc = results[1];

    final fromVibes = vibesDoc.exists
        ? _parsePlatformsList(vibesDoc.data()?['platforms'])
        : null;
    if (fromVibes != null && fromVibes.isNotEmpty) {
      return _dedupeById(fromVibes);
    }

    final fromGlobal = _parseVibesboxFromGlobalSettings(globalDoc.data());
    if (fromGlobal != null && fromGlobal.isNotEmpty) {
      return _dedupeById(fromGlobal);
    }

    return _offlineProductFallback();
  } catch (_) {
    return _offlineProductFallback();
  }
}
