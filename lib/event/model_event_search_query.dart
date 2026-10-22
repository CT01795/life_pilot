import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/value_parser.dart';

/// Parsed once per search, independently of widgets, storage and locale.
/// Text remains a fallback even for numeric terms: descriptions may contain
/// literal ages or prices outside the structured metadata range.
class ModelEventSearchQuery {
  // ignore: deprecated_member_use
  static final ageSingle = RegExp(r'^(\d+)y$');
  // ignore: deprecated_member_use
  static final ageRange = RegExp(r'^(\d+)y~(\d+)y$');
  // ignore: deprecated_member_use
  static final price = RegExp(r'^\$?(\d+)(?:~\$?(\d+))?$');
  // ignore: deprecated_member_use
  static final _separator = RegExp(r'[,，\s]+');

  final List<_SearchTerm> _terms;

  /// Display tokens retain the input's case; matching terms are normalized.
  final List<String> tokens;

  ModelEventSearchQuery(String keywords)
    : this._(
        keywords
            .split(_separator)
            .map((word) => word.trim())
            .where((word) => word.isNotEmpty)
            .toList(growable: false),
      );

  ModelEventSearchQuery._(List<String> words)
    : tokens = List.unmodifiable(words),
      _terms = words
          .map((word) => word.toLowerCase())
          // AND-ing the same normalized condition again cannot change a match.
          // Keep first-occurrence order; display tokens above remain untouched.
          .toSet()
          .map(_SearchTerm.new)
          .toList(growable: false);

  bool get isEmpty => _terms.isEmpty;

  bool matches(EventItem event, {required String Function() searchableText}) {
    return matchesWithText(
      event,
      containsText: (word) => searchableText().contains(word),
    );
  }

  bool matchesWithText(
    EventItem event, {
    required bool Function(String word) containsText,
  }) {
    for (final term in _terms) {
      // A successful metadata check needs neither text indexing nor children.
      if (term.matchesMetadata(event)) continue;
      if (containsText(term.text)) continue;
      if (!term.hasMetadata || !event.subEvents.any(term.matchesMetadata)) {
        return false;
      }
    }
    return true;
  }
}

class _SearchTerm {
  final String text;
  final ({num min, num max})? age;
  final ({num min, num max})? price;

  _SearchTerm(this.text) : age = _age(text), price = _price(text);

  bool get hasMetadata => age != null || price != null;

  static ({num min, num max})? _age(String text) {
    final range = ModelEventSearchQuery.ageRange.firstMatch(text);
    if (range != null) {
      return (
        min: parseNumValue(range.group(1)),
        max: parseNumValue(range.group(2)),
      );
    }
    final single = ModelEventSearchQuery.ageSingle.firstMatch(text);
    if (single == null) return null;
    final value = parseNumValue(single.group(1));
    return (min: value, max: value);
  }

  static ({num min, num max})? _price(String text) {
    final match = ModelEventSearchQuery.price.firstMatch(text);
    if (match == null) return null;
    final min = parseNumValue(match.group(1));
    return (
      min: min,
      max: match.group(2) == null ? min : parseNumValue(match.group(2)),
    );
  }

  bool matchesMetadata(EventItem event) {
    final ageRange = age;
    if (ageRange != null &&
        !(ageRange.max < (event.ageMin ?? 0) ||
            ageRange.min > (event.ageMax ?? 999))) {
      return true;
    }
    final priceRange = price;
    return priceRange != null &&
        !(priceRange.max < (event.priceMin ?? 0) ||
            priceRange.min > (event.priceMax ?? 999999));
  }
}
