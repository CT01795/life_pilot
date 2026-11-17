import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/value_parser.dart';

class ModelMemoryInitialWindow {
  const ModelMemoryInitialWindow({
    required this.events,
    required this.hasPageMore,
    required this.hasMore,
    required this.windowStart,
    required this.windowEnd,
    this.nextDate,
  });

  final List<EventItem> events;
  final bool hasPageMore;
  final bool hasMore;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime? nextDate;

  factory ModelMemoryInitialWindow.fromJson(
    Map<String, dynamic> json,
    EventItem Function(Map<String, dynamic>) decode,
  ) {
    final windowStart = tryParseDateTimeValue(json['window_start']);
    final windowEnd = tryParseDateTimeValue(json['window_end']);
    if (windowStart == null || windowEnd == null) {
      throw const FormatException('Invalid memory initial window');
    }
    return ModelMemoryInitialWindow(
      events: List.unmodifiable(
        (json['events'] as List? ?? const []).map(
          (row) => decode(Map<String, dynamic>.from(row as Map)),
        ),
      ),
      hasPageMore: json['has_page_more'] == true,
      hasMore: json['has_more'] == true,
      windowStart: windowStart,
      windowEnd: windowEnd,
      nextDate: tryParseDateTimeValue(json['next_date']),
    );
  }
}
