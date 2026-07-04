import '../../models/models.dart';

String stripNewsHtml(String raw) {
  var text = raw;
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n\n');
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&ldquo;': '"',
    '&rdquo;': '"',
    '&lsquo;': '\u2018',
    '&rsquo;': '\u2019',
  };
  for (final e in entities.entries) {
    text = text.replaceAll(e.key, e.value);
  }
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

String newsPreviewText(NewsItem item) {
  final summary = stripNewsHtml(item.summary);
  if (summary.isNotEmpty) return summary;
  return stripNewsHtml(item.headline);
}
