import 'package:life_pilot/event/model_event_item.dart';

class EventImportValidator {
  const EventImportValidator._();

  static String? rejectionReason({
    required EventItem event,
    required DateTime checkedAt,
  }) {
    final startDate = event.startDate;
    if (startDate == null) {
      return 'missing_start_date';
    }

    final endDate = event.endDate;
    if (endDate != null && endDate.isBefore(startDate)) {
      return 'end_before_start';
    }

    final latestSupportedStart = DateTime(
      checkedAt.year + 2,
      checkedAt.month,
      checkedAt.day,
    );
    if (startDate.isAfter(latestSupportedStart)) {
      return 'start_date_out_of_range';
    }

    return null;
  }
}
