import 'package:life_pilot/event/model_event_item.dart';

/// Interprets a page fetched with one lookahead row, before UI deduplication.
/// No widget, storage or request state belongs in this model.
class ModelEventPage {
  final List<EventItem> events;
  final bool hasMore;
  final int nextOffset;

  const ModelEventPage._(this.events, this.hasMore, this.nextOffset);

  factory ModelEventPage.fromRows(
    List<EventItem> rows, {
    required int pageSize,
    int offset = 0,
  }) {
    if (pageSize <= 0) throw ArgumentError.value(pageSize, 'pageSize');
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    final hasMore = rows.length > pageSize;
    // Preserve the existing list when it fits. A trimmed page needs its own
    // list, so sorting cannot move the lookahead row into the visible page.
    final events = hasMore ? rows.sublist(0, pageSize) : rows;
    // Do not use unique IDs or count the lookahead row: the server offset is
    // based on consumed rows, even when the displayed list deduplicates them.
    return ModelEventPage._(events, hasMore, offset + events.length);
  }
}
