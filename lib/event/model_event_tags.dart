/// Presentation data only. Locale labels are supplied by the caller; no widget,
/// account, event mutation or retained per-user cache belongs here.
class ModelEventTags {
  static final _separator = RegExp(r'[\s,，]');

  /// Keep the existing three-tag limit without splitting the unused suffix of
  /// a long type/label into hundreds of temporary strings.
  static List<String> firstThree(Iterable<String> parts) {
    final tags = <String>[];
    for (final part in parts) {
      var start = 0;
      for (final separator in _separator.allMatches(part)) {
        final tag = part.substring(start, separator.start).trim();
        start = separator.end;
        if (tag.isNotEmpty) tags.add(tag);
        if (tags.length == 3) return tags;
      }
      final tag = part.substring(start).trim();
      if (tag.isNotEmpty) tags.add(tag);
      if (tags.length == 3) return tags;
    }
    return tags;
  }
}
