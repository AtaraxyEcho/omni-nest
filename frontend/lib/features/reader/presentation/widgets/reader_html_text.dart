/// 从 HTML 中提取纯文本，用于 TTS 等场景。
String stripHtml(String html) {
  if (html.trim().isEmpty) return '';
  final tagPattern = RegExp(r'<[^>]*>', caseSensitive: false);
  return _decodeHtmlEntities(
    html.replaceAll(tagPattern, ' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
  );
}

String _decodeHtmlEntities(String text) {
  const entities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&nbsp;': ' ',
    '&mdash;': '—',
    '&ndash;': '–',
    '&hellip;': '…',
    '&copy;': '©',
    '&reg;': '®',
    '&trade;': '™',
    '&laquo;': '«',
    '&raquo;': '»',
    '&lsquo;': '‘',
    '&rsquo;': '’',
    '&ldquo;': '“',
    '&rdquo;': '”',
    '&bull;': '•',
    '&deg;': '°',
    '&para;': '¶',
    '&sect;': '§',
    '&middot;': '·',
    '&times;': '×',
    '&divide;': '÷',
    '&plusmn;': '±',
    '&micro;': 'µ',
    '&frac14;': '¼',
    '&frac12;': '½',
    '&frac34;': '¾',
    '&iexcl;': '¡',
    '&iquest;': '¿',
    '&cent;': '¢',
    '&pound;': '£',
    '&yen;': '¥',
    '&euro;': '€',
    '&brvbar;': '¦',
    '&not;': '¬',
    '&macr;': '¯',
    '&acute;': '´',
    '&cedil;': '¸',
    '&ordm;': 'º',
    '&ordf;': 'ª',
    '&lceil;': '⌈',
    '&rceil;': '⌉',
    '&lfloor;': '⌊',
    '&rfloor;': '⌋',
    '&larr;': '←',
    '&rarr;': '→',
    '&uarr;': '↑',
    '&darr;': '↓',
    '&harr;': '↔',
    '&crarr;': '↵',
    '&Prime;': '″',
    '&prime;': '′',
    '&oline;': '‾',
    '&lang;': '⟨',
    '&rang;': '⟩',
    '&loz;': '◊',
    '&spades;': '♠',
    '&clubs;': '♣',
    '&hearts;': '♥',
    '&diams;': '♦',
  };
  var result = text;
  for (final entry in entities.entries) {
    result = result.replaceAll(entry.key, entry.value);
  }
  result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
    final codePoint = int.tryParse(match.group(1)!);
    return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
  });
  result = result.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
    final codePoint = int.tryParse(match.group(1)!, radix: 16);
    return codePoint == null ? match.group(0)! : String.fromCharCode(codePoint);
  });
  return result;
}
