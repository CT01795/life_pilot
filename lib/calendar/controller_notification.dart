import 'dart:async';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/service/platforms/notification_util.dart';
import 'package:life_pilot/utils/service/service_notification/service_notification_platform.dart';

class ControllerNotification {
  final ServiceNotificationPlatform _service;
  ServiceNotificationPlatform get service => _service;
  
  ControllerNotification({required ServiceNotificationPlatform service})
      : _service = service;

  Future<void> initialize() async {
    await _service.initialize();
  }

  Future<void> scheduleEventReminders({required EventItem event}) async {
    await scheduleMultipleReminders(events: [event]);
  }

  // 批量事件排程提醒（效能優化）
  Future<void> scheduleMultipleReminders({
    required List<EventItem> events,
  }) async {
    final futures =
        events.map((e) => _service.scheduleEventReminders(event: e)).toList();
    await Future.wait(futures);
  }

  // 取消事件提醒
  Future<void> cancelEventReminders(
      {required String eventId,
      required List<CalendarReminderOption> reminderOptions}) async {
    await _service.cancelEventReminders(
        eventId: eventId, reminderOptions: reminderOptions);
  }

  // 顯示今日事件通知，先在 Controller 過濾，提高效能
  Future<List<EventNotification>> showTodayEvents({
    required List<EventItem> events,
    required String closeText,
  }) async {
    final newEvents = getTodayEventNotificationsList(events: events);
    return newEvents.isNotEmpty
        ? await _service.getTodayEventNotifications(
            events: newEvents, close: closeText)
        : [];
  }
}
