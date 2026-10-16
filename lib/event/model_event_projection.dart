import 'package:life_pilot/event/model_event_item.dart';

/// Keeps one derived page list, so loading-only notifications do not repeat
/// owner filtering and invalidate the downstream region-count cache.
class ModelEventProjection {
  List<EventItem>? _source;
  List<EventItem>? _result;
  Object? _key;

  /// [cacheKey] must describe every predicate input. Without a key, predicates
  /// are always evaluated. Replace [events] when its content changes.
  List<EventItem> select({
    required List<EventItem> events,
    bool Function(EventItem)? predicate,
    Object? cacheKey,
  }) {
    if (predicate == null) {
      _clear();
      return events;
    }
    if (cacheKey != null && identical(_source, events) && _key == cacheKey) {
      return _result!;
    }
    final result = events.where(predicate).toList(growable: false);
    if (cacheKey == null) {
      _clear();
    } else {
      _source = events;
      _key = cacheKey;
      _result = result;
    }
    return result;
  }

  void _clear() {
    _source = null;
    _result = null;
    _key = null;
  }
}
