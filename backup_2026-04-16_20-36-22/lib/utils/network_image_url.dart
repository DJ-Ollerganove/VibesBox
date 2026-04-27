/// Prüft, ob [url] für [NetworkImage] / [Image.network] geeignet ist
/// (nicht leer, http oder https). Verhindert Assertions und leere NetworkImages.
bool isHttpImageUrl(String? url) {
  final t = url?.trim() ?? '';
  if (t.isEmpty) return false;
  final l = t.toLowerCase();
  return l.startsWith('http://') || l.startsWith('https://');
}
