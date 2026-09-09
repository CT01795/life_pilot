import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/service/service_notification/service_notification_platform.dart';

void main() {
  test('completed event cancels every reminder instead of scheduling',
      () async {
    final service = _FakeNotificationService();
    final controller = ControllerNotification(service: service);
    final event = EventItem(
      id: 'completed-event',
      isCompleted: true,
      reminderOptions: const [CalendarReminderOption.dayBefore8am],
    );

    await controller.scheduleEventReminders(event: event);

    expect(service.scheduledEvents, isEmpty);
    expect(service.cancelledEventIds, ['completed-event']);
    expect(
      service.cancelledOptions.single,
      CalendarReminderOption.values,
    );
  });

  test('active event is still scheduled normally', () async {
    final service = _FakeNotificationService();
    final controller = ControllerNotification(service: service);
    final event = EventItem(id: 'active-event');

    await controller.scheduleEventReminders(event: event);

    expect(service.scheduledEvents, [event]);
    expect(service.cancelledEventIds, isEmpty);
  });
}

class _FakeNotificationService implements ServiceNotificationPlatform {
  final List<EventItem> scheduledEvents = [];
  final List<String> cancelledEventIds = [];
  final List<List<CalendarReminderOption>> cancelledOptions = [];

  @override
  FlutterLocalNotificationsPlugin? get plugin => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationResult> scheduleEventReminders({
    required EventItem event,
  }) async {
    scheduledEvents.add(event);
    return NotificationResult(success: true);
  }

  @override
  Future<void> cancelEventReminders({
    required String eventId,
    required List<CalendarReminderOption> reminderOptions,
  }) async {
    cancelledEventIds.add(eventId);
    cancelledOptions.add(List.of(reminderOptions));
  }

  @override
  Future<List<EventNotification>> getTodayEventNotifications({
    required List<EventItem> events,
    required String close,
  }) async =>
      [];
}
