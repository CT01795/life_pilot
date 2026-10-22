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
  final _baseText = Map<EventItem, String>.identity();
  EventSearchLabels? _labels;

  /// [word] is a normalized query token with no whitespace.
  bool contains(
    EventItem event,
    String word, {
    required EventSearchLabels labels,
  }) {
    if (_labels != labels) {
      clear();
      _labels = labels;
    }
    final entry = _entries.putIfAbsent(
      event,
      () => _SearchTextEntry(_textFor(event, labels)),
    );
    if (entry.parent.contains(word)) return true;

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
      if (text.contains(word)) return true;
    }
    final children = entry.childEvents!;
    while (entry.childTexts.length < children.length) {
      final text = _textFor(children[entry.childTexts.length], labels);
      entry.childTexts.add(text);
      if (text.contains(word)) return true;
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
  }

  /// Only for progressive snapshots whose existing objects are unchanged.
  /// Edits must still use invalidate; do not inspect/decode child records here.
  void retainEvents(Iterable<EventItem> events) {
    if (_entries.isEmpty) return;
    final active = Set<EventItem>.identity()..addAll(events);
    _entries.removeWhere((event, _) => !active.contains(event));
    _baseText.removeWhere((event, _) => !active.contains(event));
  }

  String _textFor(EventItem event, EventSearchLabels labels) =>
      _baseText.putIfAbsent(event, () => _text(event, labels));

  static String _text(EventItem event, EventSearchLabels labels) => <String>[
    event.city,
    event.location,
    event.name,
    event.type,
    event.description,
    event.unit,
    if (event.isFree != null) event.isFree! ? labels.free : labels.pay,
    if (event.isOutdoor != null)
      event.isOutdoor! ? labels.outdoor : labels.indoor,
  ].join('\n').toLowerCase();
}

class _SearchTextEntry {
  final String parent;
  final childTexts = <String>[];
  List<EventItem>? childEvents;

  _SearchTextEntry(this.parent);
}
