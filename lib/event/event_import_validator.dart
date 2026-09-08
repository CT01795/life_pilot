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

    return null;
  }
}
