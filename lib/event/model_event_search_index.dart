import 'package:life_pilot/event/model_event_item.dart';

typedef EventSearchLabels = ({
  String free,
  String pay,
  String outdoor,
  String indoor,
});

/// A model-owned text index. Widgets and localization objects are not retained.
/// Event edits must invalidate this index because EventItem is mutable.
class ModelEventSearchIndex {
  final _entries = Map<EventItem, _SearchTextEntry>.identity();
  final _baseText = Map<EventItem, _SearchText>.identity();
  EventSearchLabels? _labels;
  EventSearchLabels? _normalizedLabels;

  /// [word] is a normalized query token with no whitespace.
  bool contains(
    EventItem event,
    String word, {
    required EventSearchLabels labels,
  }) {
    if (_labels != labels) {
      _labels = labels;
      _normalizedLabels = (
        free: labels.free.toLowerCase(),
        pay: labels.pay.toLowerCase(),
        outdoor: labels.outdoor.toLowerCase(),
        indoor: labels.indoor.toLowerCase(),
      );
    }
    final normalizedLabels = _normalizedLabels!;
    final entry = _entries.putIfAbsent(
      event,
      () => _SearchTextEntry(_textFor(event)),
    );
    if (entry.parent.contains(word, normalizedLabels)) return true;

    // Query tokens contain no whitespace, so no token can span the newline
    // separating parent and child fields. Indexing them separately is safe.
    if (entry.childEvents == null) {
      // Keep the already-decoded membership so changing a child can also
      // invalidate a cached parent, without decoding untouched parents.
      final children = event.subEvents.toList(growable: false);
      entry.childEvents = children;
    }
    // Retain references to each child's text instead of a second concatenated
    // copy per parent. A match need not prepare later child descriptions.
    for (final text in entry.childTexts) {
      if (text.contains(word, normalizedLabels)) return true;
    }
    final children = entry.childEvents!;
    while (entry.childTexts.length < children.length) {
      final text = _textFor(children[entry.childTexts.length]);
      entry.childTexts.add(text);
      if (text.contains(word, normalizedLabels)) return true;
    }
    return false;
  }

  /// Preserves unaffected entries, including their deferred child text.
  /// Identity is intentional: different events may share the same ID.
  void invalidate(Iterable<EventItem> events) {
    final changed = Set<EventItem>.identity()..addAll(events);
    if (changed.isEmpty) return;
    // A parent edit may include mutable child edits. Drop shared base text,
    // while preserving unaffected complete entries and their deferred state.
    _baseText.clear();
    _entries.removeWhere(
      (event, entry) =>
          changed.contains(event) ||
          (entry.childEvents?.any(changed.contains) ?? false),
    );
  }

  void clear() {
    _entries.clear();
    _baseText.clear();
    _labels = null;
    _normalizedLabels = null;
  }

  /// Only for progressive snapshots whose existing objects are unchanged.
  /// Edits must still use invalidate; do not inspect/decode child records here.
  void retainEvents(Iterable<EventItem> events) {
    // A child may remain as base text after its parent entry was removed.
    // It still needs pruning even when no complete entries remain.
    if (_entries.isEmpty && _baseText.isEmpty) return;
    // Retention needs membership only for objects already indexed. Do not build
    // a temporary set of thousands of untouched appended records.
    final active = Set<EventItem>.identity();
    for (final event in events) {
      if (_entries.containsKey(event) || _baseText.containsKey(event)) {
        active.add(event);
      }
    }
    _entries.removeWhere((event, _) => !active.contains(event));
    _baseText.removeWhere((event, _) => !active.contains(event));
  }

  _SearchText _textFor(EventItem event) =>
      _baseText.putIfAbsent(event, () => _SearchText(event));
}

class _SearchTextEntry {
  final _SearchText parent;
  final childTexts = <_SearchText>[];
  List<EventItem>? childEvents;

  _SearchTextEntry(this.parent);
}

/// Locale-independent text and metadata captured together. Normalized query
/// tokens cannot cross newline field boundaries, so translated labels can be
/// checked separately without copying descriptions on each language change.
class _SearchText {
  _SearchText(EventItem event)
    : value = <String>[
        event.city,
        event.location,
        event.name,
        event.type,
        event.description,
        event.unit,
      ].join('\n').toLowerCase(),
      isFree = event.isFree,
      isOutdoor = event.isOutdoor;

  final String value;
  final bool? isFree, isOutdoor;

  bool contains(String word, EventSearchLabels labels) {
    if (value.contains(word)) return true;
    final free = isFree, outdoor = isOutdoor;
    if (free != null && (free ? labels.free : labels.pay).contains(word)) {
      return true;
    }
    return outdoor != null &&
        (outdoor ? labels.outdoor : labels.indoor).contains(word);
  }
}
