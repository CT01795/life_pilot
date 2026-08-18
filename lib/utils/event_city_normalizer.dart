class EventCityNormalizer {
  const EventCityNormalizer._();

  static String normalize(String city) {
    final cleaned =
        city.replaceAll('\u200B', '').trim().replaceAll('\u81FA', '\u53F0');

    switch (cleaned.toLowerCase()) {
      case 'hsinchu city':
      case 'hs':
        return '\u65B0\u7AF9';
      case 'new taipei city':
      case 'ne':
        return '\u65B0\u5317';
      case 'taipei city':
      case 'ta':
        return '\u53F0\u5317';
      case '\u4E2D\u58E2\u5340':
        return '\u6843\u5712';
      case '\u9F13\u5C71\u5340':
        return '\u9AD8\u96C4';
      default:
        return cleaned.runes.length > 2
            ? String.fromCharCodes(cleaned.runes.take(2))
            : cleaned;
    }
  }
}
