import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/models/event/model_search_filter.dart';

List<EventItem> utilsFilterEvents({
  required List<EventItem> events,
  required SearchFilter filter,
  required Set<String> removedEventIds,
}) {
  // 🧠 預先處理關鍵字（全部轉小寫）
  final List<String> keywords = filter.keywords
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  if (keywords.isEmpty && filter.startDate == null && removedEventIds.isEmpty) {
    // ✅ 若沒有過濾條件，直接回傳原列表（避免無謂運算）
    return List<EventItem>.from(events);
  }

  return events.where((e) {
    if (removedEventIds.contains(e.id)) return false;
    bool matchesKeywords = keywords.every((word) {
      return e.city.toLowerCase().contains(word) ||
          e.location.toLowerCase().contains(word) ||
          e.name.toLowerCase().contains(word) ||
          e.type.toLowerCase().contains(word) ||
          e.description.toLowerCase().contains(word) ||
          e.fee.toLowerCase().contains(word) ||
          e.unit.toLowerCase().contains(word) ||
          e.subEvents.any(
            (se) =>
                se.city.toLowerCase().contains(word) ||
                se.location.toLowerCase().contains(word) ||
                se.name.toLowerCase().contains(word) ||
                se.type.toLowerCase().contains(word) ||
                se.description.toLowerCase().contains(word) ||
                se.fee.toLowerCase().contains(word) ||
                se.unit.toLowerCase().contains(word),
          );
    });

    final endDate = e.endDate ?? e.startDate;
    bool matchesDate = true;
    if (filter.startDate != null &&
        endDate != null &&
        endDate.isBefore(filter.startDate!)) {
      matchesDate = false;
    }
    if (filter.startDate != null &&
        e.startDate != null &&
        e.startDate!.isAfter(filter.startDate!)) {
      matchesDate = false;
    }

    return matchesKeywords && matchesDate;
  }).toList();
}
