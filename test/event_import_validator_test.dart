import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/event/event_import_validator.dart';
import 'package:life_pilot/event/model_event_item.dart';

void main() {
  final checkedAt = DateTime(2026, 8, 18);

  EventItem buildEvent({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return EventItem(
      name: 'event',
      startDate: startDate,
      endDate: endDate,
    );
  }

  group('EventImportValidator', () {
    test('rejects an event without a start date', () {
      expect(
        EventImportValidator.rejectionReason(
          event: buildEvent(endDate: DateTime(2026, 9, 26)),
          checkedAt: checkedAt,
        ),
        'missing_start_date',
      );
    });

    test('rejects an end date before its start date', () {
      expect(
        EventImportValidator.rejectionReason(
          event: buildEvent(
            startDate: DateTime(2029, 9, 26),
            endDate: DateTime(2026, 9, 26),
          ),
          checkedAt: checkedAt,
        ),
        'end_before_start',
      );
    });

    test('rejects a start date beyond the supported two-year window', () {
      expect(
        EventImportValidator.rejectionReason(
          event: buildEvent(startDate: DateTime(2028, 8, 19)),
          checkedAt: checkedAt,
        ),
        'start_date_out_of_range',
      );
    });

    test('accepts the boundary date and an absent end date', () {
      expect(
        EventImportValidator.rejectionReason(
          event: buildEvent(startDate: DateTime(2028, 8, 18)),
          checkedAt: checkedAt,
        ),
        isNull,
      );
    });

    test('accepts a valid date range', () {
      expect(
        EventImportValidator.rejectionReason(
          event: buildEvent(
            startDate: DateTime(2026, 9, 20),
            endDate: DateTime(2026, 9, 26),
          ),
          checkedAt: checkedAt,
        ),
        isNull,
      );
    });
  });
}
