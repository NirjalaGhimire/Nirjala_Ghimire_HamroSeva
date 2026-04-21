/// Canonical service name handling (keep in sync with backend `service_name_utils.py`).
library;

/// Trim, collapse whitespace, lowercase — duplicate detection key.
String normalizeServiceKey(String? name) {
  final s = (name ?? '').trim();
  if (s.isEmpty) return '';
  return s.split(RegExp(r'\s+')).join(' ').toLowerCase();
}

/// Professional title case for chips and labels; preserves '&'.
String formatServiceTitleDisplay(String name) {
  final collapsed = name.trim().split(RegExp(r'\s+')).join(' ');
  if (collapsed.isEmpty) return '';
  return collapsed.split(' ').map((w) {
    if (w == '&') return '&';
    if (w.contains('-')) {
      return w.split('-').map((p) => p.isEmpty ? p : _capWord(p)).join('-');
    }
    return _capWord(w);
  }).join(' ');
}

String _capWord(String w) {
  if (w.isEmpty) return w;
  return w[0].toUpperCase() + w.substring(1).toLowerCase();
}

/// Deduplicate catalog rows by [normalizeServiceKey] on title; keep first occurrence order.
List<Map<String, dynamic>> dedupeCatalogRows(List<dynamic> list) {
  final seen = <String>{};
  final out = <Map<String, dynamic>>[];
  for (final s in list) {
    if (s is! Map) continue;
    final raw = (s['title'] ?? '').toString();
    final key = normalizeServiceKey(raw);
    if (key.isEmpty || seen.contains(key)) continue;
    seen.add(key);
    out.add({
      'title': formatServiceTitleDisplay(raw),
      'id': s['id'],
    });
  }
  return out;
}
