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
      () => _SearchTextEntry(_text(event, labels)),
    );
    if (entry.parent.contains(word)) return true;

    // Query tokens contain no whitespace, so no token can span the newline
    // separating parent and child fields. Indexing them separately is safe.
    if (entry.children == null) {
      // Keep the already-decoded membership so changing a child can also
      // invalidate a cached parent, without decoding untouched parents.
      final children = event.subEvents.toList(growable: false);
      entry.childEvents = children;
      entry.children = children.map((child) => _text(child, labels)).join('\n');
    }
    return entry.children!.contains(word);
  }

  /// Preserves unaffected entries, including their deferred child text.
  /// Identity is intentional: different events may share the same ID.
  void invalidate(Iterable<EventItem> events) {
    final changed = Set<EventItem>.identity()..addAll(events);
    if (changed.isEmpty) return;
    _entries.removeWhere(
      (event, entry) =>
          changed.contains(event) ||
          (entry.childEvents?.any(changed.contains) ?? false),
    );
  }

  void clear() {
    _entries.clear();
    _labels = null;
  }

  /// Only for progressive snapshots whose existing objects are unchanged.
  /// Edits must still use invalidate; do not inspect/decode child records here.
  void retainEvents(Iterable<EventItem> events) {
    if (_entries.isEmpty) return;
    final active = Set<EventItem>.identity()..addAll(events);
    _entries.removeWhere((event, _) => !active.contains(event));
  }

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
  String? children;
  List<EventItem>? childEvents;

  _SearchTextEntry(this.parent);
}
